import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../lab/bloc/lab_bloc.dart';

class NurseNfcScreen extends StatefulWidget {
  const NurseNfcScreen({super.key});
  @override
  State<NurseNfcScreen> createState() => _NurseNfcScreenState();
}

class _NurseNfcScreenState extends State<NurseNfcScreen> with SingleTickerProviderStateMixin {
  NfcSessionState _nfcState = NfcSessionState.idle;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC is not available on Web. Please use the native Android/iOS app.'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      }
      return;
    }
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    final keys = await CryptoService.generateX25519KeyPair();

    final result = await NfcService.initiateSession(
      myPublicKeyBase64: keys['publicKey']!,
      myUserId: auth.user.id,
      role: NfcAccessRole.nurse,
      onStateChange: (state) { if (mounted) setState(() => _nfcState = state); },
    );

    if (result.success && result.patientId != null) {
      if (mounted) context.push('${AppRoutes.nurseTreatment}?patientId=${result.patientId}');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'NFC failed'), backgroundColor: AppTheme.error));
        setState(() => _nfcState = NfcSessionState.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text('Nurse NFC Access', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        actions: [
          IconButton(
            onPressed: () { context.read<AuthBloc>().add(AuthLogoutRequested()); context.go(AppRoutes.login); },
            icon: const Icon(Icons.logout_outlined, color: AppTheme.outline),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NFC icon with pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, child) => Transform.scale(
                  scale: _nfcState == NfcSessionState.scanning ? 1.0 + _pulseController.value * 0.1 : 1.0,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppTheme.primaryContainer.withValues(alpha: 0.3 + _pulseController.value * 0.2),
                        AppTheme.primaryFixed.withValues(alpha: 0.05),
                      ]),
                    ),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _nfcState == NfcSessionState.scanning ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryContainer, width: 2),
                        ),
                        child: Icon(
                          Icons.nfc_rounded,
                          size: 60,
                          color: _nfcState == NfcSessionState.scanning ? AppTheme.onPrimary : AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _nfcState == NfcSessionState.scanning
                    ? 'Hold near patient device...'
                    : _nfcState == NfcSessionState.connected
                        ? 'Connected!'
                        : 'Tap NFC to Access Patient',
                style: AppTextStyles.headlineMd.copyWith(color: AppTheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hold your device near the patient\'s phone or NFC tag to establish a secure X25519 session',
                style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _nfcState == NfcSessionState.scanning ? null : _startNfcScan,
                icon: _nfcState == NfcSessionState.scanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.nfc_outlined, size: 22),
                label: Text(
                  _nfcState == NfcSessionState.scanning ? 'Scanning...' : 'Start NFC Scan',
                  style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
              const SizedBox(height: 24),
              // Security badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_outlined, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('X25519 key exchange • End-to-end encrypted session', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NurseTreatmentScreen extends StatefulWidget {
  final String patientId;
  const NurseTreatmentScreen({super.key, required this.patientId});
  @override
  State<NurseTreatmentScreen> createState() => _NurseTreatmentScreenState();
}

class _NurseTreatmentScreenState extends State<NurseTreatmentScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    context.read<NurseBloc>().add(NurseLoadTreatment(patientId: widget.patientId, nurseId: auth.user.id));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Treatment Dashboard', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(100)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 12, color: AppTheme.secondary),
                const SizedBox(width: 4),
                Text('NFC Active', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
              ],
            ),
          ),
        ],
      ),
      body: BlocConsumer<NurseBloc, NurseState>(
        listener: (context, state) {
          if (state is NurseActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary));
          }
          if (state is NurseError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.error));
          }
        },
        builder: (context, state) {
          if (state is NurseLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          if (state is! NurseTreatmentLoaded) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Patient header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryContainer, AppTheme.secondary]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text((state.patient['name'] as String? ?? 'P')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(state.patient['name'] as String? ?? '', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                      Text(widget.patientId, style: AppTextStyles.codeSm.copyWith(color: Colors.white70)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Diagnoses (read-only)
              Text('Current Diagnoses', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              ...state.diagnoses.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                ),
                child: Text(d['diagnosis'] as String? ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface)),
              )),
              const SizedBox(height: 16),
              // Medicines
              Text('Medicine Schedule', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              if (state.prescriptions.isEmpty) Text('No prescriptions', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
              ...state.prescriptions.expand((rx) {
                final meds = (rx['medicines'] as List<dynamic>? ?? []).map((m) => m.toString()).toList();
                return meds.map((med) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.medication_outlined, color: AppTheme.secondary),
                    title: Text(med, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    trailing: ElevatedButton(
                      onPressed: () => context.read<NurseBloc>().add(NurseUpdateMedicine(
                        patientId: widget.patientId,
                        nurseId: auth.user.id,
                        medicine: med,
                      )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Given ✓', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ));
              }),
            ],
          );
        },
      ),
    );
  }
}
