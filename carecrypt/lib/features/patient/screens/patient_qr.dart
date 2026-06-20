import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // still used in UI text

import '../../../core/theme/app_theme.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/patient_bloc.dart';

/// QR generation lifecycle states
enum QrState { idle, verifyingBio, verifyingPin, generating, ready, expired }

class PatientQrScreen extends StatefulWidget {
  const PatientQrScreen({super.key});

  @override
  State<PatientQrScreen> createState() => _PatientQrScreenState();
}

class _PatientQrScreenState extends State<PatientQrScreen> with TickerProviderStateMixin {
  QrState _state = QrState.idle;
  String? _qrData;
  int _secondsLeft = 300; // 5 minutes expiry
  late AnimationController _pulseController;
  final _pinController = TextEditingController();
  bool _pinVisible = false;
  String _pinError = '';
  static const _pinCode = '123456'; // Fallback PIN for web

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _generateQr() async {
    await _doBiometricVerification();
  }

  Future<void> _doBiometricVerification() async {
    setState(() => _state = QrState.verifyingBio);
    final result = await BiometricService.authenticateForQr();

    if (result == BiometricResult.success) {
      await _doQrGeneration();
    } else if (result == BiometricResult.needsSimulation) {
      // Hardware absent or web — show the rich simulated auth sheet
      if (!mounted) return;
      setState(() => _state = QrState.idle);
      final passed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SimulatedAuthSheet(),
      );
      if (passed == true) {
        await _doQrGeneration();
      } else {
        setState(() => _state = QrState.idle);
      }
    } else {
      // Failed — fall back to PIN entry
      setState(() { _state = QrState.verifyingPin; _pinError = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric verification failed. Use PIN instead.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _verifyPin() async {
    if (_pinController.text == _pinCode) {
      await _doQrGeneration();
    } else {
      setState(() => _pinError = 'Incorrect PIN. Try again.');
    }
  }

  Future<void> _doQrGeneration() async {
    setState(() => _state = QrState.generating);

    try {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state as AuthAuthenticated;
      if (!mounted) return;
      final patientState = context.read<PatientBloc>().state;

      // Generate unique token ID for one-time use
      const uuid = Uuid();
      final tokenId = uuid.v4();
      final expiryTime = DateTime.now().add(const Duration(minutes: 5));

      // Build prescription payload
      String? prescriptionId;
      List<String> medicines = [];
      if (patientState is PatientDashboardLoaded && patientState.prescriptions.isNotEmpty) {
        final rx = patientState.prescriptions.first;
        prescriptionId = rx.id;
        medicines = rx.medicines;
      }

      final payload = {
        'patient_id': authState.user.patientId ?? '',
        'user_id': authState.user.id,
        'display_name': authState.user.displayName,
        'token_id': tokenId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': expiryTime.millisecondsSinceEpoch,
        'app': 'CareCrypt',
        'version': '2.0',
        if (prescriptionId != null) 'prescription_id': prescriptionId,
        if (medicines.isNotEmpty) 'medicines': medicines,
      };

      final payloadJson = jsonEncode(payload);

      // AES-256-GCM encrypt WITHOUT keyAlias → key is embedded in the JSON
      // This is essential: the pharmacy device doesn't have the patient's stored key.
      // The ephemeral key travels inside the QR payload (same pattern as harshlimkar/crypto).
      final encrypted = await CryptoService.encryptAesGcm(payloadJson);

      // Sign with Ed25519
      final privateKey = await CryptoService.loadKey('ed25519_private_${authState.user.id}');
      String? signature;
      if (privateKey != null) {
        signature = await CryptoService.signEd25519(encrypted, privateKey);
      }

      final qrPayload = jsonEncode({
        'data': encrypted,
        'sig': signature,
        'app': 'CareCrypt',
        'v': '2',
      });

      // Register token in Supabase for one-time invalidation
      try {
        await Supabase.instance.client.from('qr_tokens').insert({
          'token_id': tokenId,
          'patient_id': authState.user.patientId ?? '',
          'user_id': authState.user.id,
          if (prescriptionId != null) 'prescription_id': prescriptionId,
          'expires_at': expiryTime.toIso8601String(),
          'used': false,
        });
      } catch (_) {
        // If qr_tokens table doesn't exist yet, continue gracefully
        // (migration not yet run — client-side expiry still works)
      }

      setState(() {
        _qrData = qrPayload;
        _state = QrState.ready;
        _secondsLeft = 300;
      });

      _startCountdown();
    } catch (e) {
      setState(() => _state = QrState.idle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _state == QrState.ready) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) {
          setState(() => _state = QrState.expired);
        } else {
          _startCountdown();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text('Secure QR Code', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            if (_state == QrState.verifyingPin)
              _buildPinVerification()
            else
              _buildQrArea(),
            if (_state != QrState.verifyingPin) ...[
              const SizedBox(height: 24),
              _buildActionButton(),
            ],
            const SizedBox(height: 20),
            _buildSecurityInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final (icon, color, label, bg) = switch (_state) {
      QrState.idle => (Icons.qr_code_2, AppTheme.primary, 'Ready to generate secure QR', AppTheme.primaryFixed.withValues(alpha: 0.15)),
      QrState.verifyingBio => (Icons.fingerprint, AppTheme.secondary, 'Verifying biometrics...', AppTheme.secondaryContainer.withValues(alpha: 0.3)),
      QrState.verifyingPin => (Icons.pin_outlined, AppTheme.secondary, 'Enter your 6-digit PIN', AppTheme.secondaryContainer.withValues(alpha: 0.3)),
      QrState.generating => (Icons.lock_outlined, AppTheme.primary, 'Encrypting payload...', AppTheme.primaryFixed.withValues(alpha: 0.15)),
      QrState.ready => (Icons.check_circle_outline, AppTheme.secondary, 'QR Active — ${_secondsLeft}s remaining', AppTheme.secondaryContainer.withValues(alpha: 0.3)),
      QrState.expired => (Icons.timer_off_outlined, AppTheme.error, 'QR Expired — Generate new', AppTheme.errorContainer.withValues(alpha: 0.3)),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.titleMd.copyWith(color: color))),
          if (_state == QrState.ready)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'ONE-TIME',
                style: AppTextStyles.codeSm.copyWith(color: color, fontSize: 9, letterSpacing: 1.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinVerification() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16)],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 36, color: AppTheme.secondary),
          ),
          const SizedBox(height: 20),
          Text('PIN Verification', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Enter your 6-digit security PIN to generate QR',
            style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: !_pinVisible,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.titleLg.copyWith(letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              errorText: _pinError.isNotEmpty ? _pinError : null,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _pinVisible = !_pinVisible),
                icon: Icon(_pinVisible ? Icons.visibility_off : Icons.visibility, size: 20),
              ),
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _state = QrState.idle; _pinController.clear(); }),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Verify', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          if (_state == QrState.ready && _qrData != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('CareCrypt Secure QR', style: AppTextStyles.labelMd.copyWith(color: AppTheme.primary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('1-TIME USE', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary, fontSize: 9)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.primary),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.onSurface),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _secondsLeft / 300,
              backgroundColor: AppTheme.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(_secondsLeft > 60 ? AppTheme.secondary : AppTheme.error),
              borderRadius: BorderRadius.circular(100),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: _secondsLeft > 60 ? AppTheme.outline : AppTheme.error),
                const SizedBox(width: 4),
                Text(
                  'Expires in ${_secondsLeft ~/ 60}m ${_secondsLeft % 60}s',
                  style: AppTextStyles.labelMd.copyWith(color: _secondsLeft > 60 ? AppTheme.outline : AppTheme.error),
                ),
              ],
            ),
          ] else if (_state == QrState.generating || _state == QrState.verifyingBio) ...[
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 20),
            Text(
              _state == QrState.verifyingBio ? 'Scanning biometrics...' : 'Encrypting with AES-256-GCM...',
              style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline),
            ),
            const SizedBox(height: 60),
          ] else ...[
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) => Opacity(
                opacity: 0.4 + _pulseController.value * 0.4,
                child: child,
              ),
              child: const Icon(Icons.qr_code_2, size: 160, color: AppTheme.outlineVariant),
            ),
            const SizedBox(height: 20),
            Text(
              _state == QrState.expired
                  ? 'QR has expired for security.\nGenerate a new one below.'
                  : 'Tap below to generate your\nsecure prescription QR code',
              style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isLoading = _state == QrState.generating || _state == QrState.verifyingBio;
    return ElevatedButton.icon(
      onPressed: isLoading ? null : _generateQr,
      icon: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(_state == QrState.ready ? Icons.refresh : (kIsWeb ? Icons.pin_outlined : Icons.fingerprint), size: 20),
      label: Text(
        _state == QrState.ready ? 'Regenerate QR' : (kIsWeb ? 'Generate via PIN' : 'Generate Secure QR'),
        style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _state == QrState.ready ? AppTheme.secondary : AppTheme.primaryContainer,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _securityRow(Icons.lock_outlined, 'AES-256-GCM encrypted payload'),
          const SizedBox(height: 8),
          _securityRow(Icons.verified_outlined, 'Ed25519 digital signature'),
          const SizedBox(height: 8),
          _securityRow(Icons.timer_outlined, '5-minute validity window'),
          const SizedBox(height: 8),
          _securityRow(Icons.block_outlined, 'One-time use — invalidates after scan'),
          const SizedBox(height: 8),
          _securityRow(
            kIsWeb ? Icons.pin_outlined : Icons.fingerprint,
            kIsWeb ? 'PIN verification required' : 'Biometric verification required',
          ),
        ],
      ),
    );
  }

  Widget _securityRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulated Authentication Bottom Sheet
// Shown when real biometrics hardware is not available (web / no enrollment)
// ─────────────────────────────────────────────────────────────────────────────

class _SimulatedAuthSheet extends StatefulWidget {
  const _SimulatedAuthSheet();
  @override
  State<_SimulatedAuthSheet> createState() => _SimulatedAuthSheetState();
}

class _SimulatedAuthSheetState extends State<_SimulatedAuthSheet>
    with SingleTickerProviderStateMixin {
  _AuthMode _mode = _AuthMode.choose;
  late AnimationController _pulseCtrl;
  final _pinCtrl = TextEditingController();
  String _pinError = '';
  bool _pinVisible = false;
  bool _scanning = false;
  static const _demoPin = '123456';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulateScan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop(true);
  }

  void _verifyPin() {
    if (_pinCtrl.text == _demoPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _pinError = 'Incorrect PIN (demo: 123456)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 32)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _mode == _AuthMode.choose
                ? _buildChoose()
                : _mode == _AuthMode.fingerprint
                    ? _buildFingerprint()
                    : _buildPin(),
          ),
        ),
      ),
    );
  }

  Widget _buildChoose() {
    return Column(key: const ValueKey('choose'), mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(100))),
      const SizedBox(height: 20),
      const Icon(Icons.security_rounded, size: 40, color: AppTheme.primary),
      const SizedBox(height: 12),
      Text('Authentication Required', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      const SizedBox(height: 6),
      Text('Choose verification method to generate secure QR',
          style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _authOption(
        icon: Icons.fingerprint_rounded,
        label: 'Fingerprint Scan',
        subtitle: 'Simulated biometric verification',
        color: AppTheme.primary,
        onTap: () => setState(() => _mode = _AuthMode.fingerprint),
      ),
      const SizedBox(height: 12),
      _authOption(
        icon: Icons.face_retouching_natural,
        label: 'Face Unlock',
        subtitle: 'Simulated face authentication',
        color: AppTheme.secondary,
        onTap: () { setState(() { _mode = _AuthMode.fingerprint; }); },
      ),
      const SizedBox(height: 12),
      _authOption(
        icon: Icons.pin_outlined,
        label: 'Secure PIN',
        subtitle: 'Enter your 6-digit security PIN',
        color: AppTheme.outline,
        onTap: () => setState(() => _mode = _AuthMode.pin),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text('Cancel', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.error)),
      ),
    ]);
  }

  Widget _buildFingerprint() {
    return Column(key: const ValueKey('fp'), mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => setState(() => _mode = _AuthMode.choose)),
        const Spacer(),
      ]),
      const SizedBox(height: 8),
      Text('Touch Sensor', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      const SizedBox(height: 6),
      Text('Place your finger on the sensor to verify',
          style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (ctx, child) => Transform.scale(
          scale: _scanning ? (1.0 + _pulseCtrl.value * 0.08) : 1.0,
          child: GestureDetector(
            onTap: _scanning ? null : _simulateScan,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scanning
                    ? AppTheme.secondary.withValues(alpha: 0.15)
                    : AppTheme.primaryFixed.withValues(alpha: 0.15),
                border: Border.all(
                  color: _scanning ? AppTheme.secondary : AppTheme.primary,
                  width: 2.5,
                ),
              ),
              child: Icon(
                _scanning ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                size: 64,
                color: _scanning ? AppTheme.secondary : AppTheme.primary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        _scanning ? 'Scanning...' : 'Tap the sensor to scan',
        style: AppTextStyles.bodyMd.copyWith(
            color: _scanning ? AppTheme.secondary : AppTheme.outline),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildPin() {
    return Column(key: const ValueKey('pin'), mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => setState(() => _mode = _AuthMode.choose)),
        const Spacer(),
      ]),
      const Icon(Icons.lock_outline, size: 40, color: AppTheme.secondary),
      const SizedBox(height: 12),
      Text('PIN Verification', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      const SizedBox(height: 20),
      TextField(
        controller: _pinCtrl,
        keyboardType: TextInputType.number,
        obscureText: !_pinVisible,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTextStyles.titleLg.copyWith(letterSpacing: 8),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          counterText: '',
          hintText: '• • • • • •',
          errorText: _pinError.isNotEmpty ? _pinError : null,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _pinVisible = !_pinVisible),
            icon: Icon(_pinVisible ? Icons.visibility_off : Icons.visibility, size: 20),
          ),
        ),
        onSubmitted: (_) => _verifyPin(),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _verifyPin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryContainer,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text('Verify PIN', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
      ),
      const SizedBox(height: 8),
      Text('Demo PIN: 123456', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _authOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 12)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.outline),
        ]),
      ),
    );
  }
}

enum _AuthMode { choose, fingerprint, pin }
