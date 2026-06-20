import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../lab/bloc/lab_bloc.dart';

class PharmacyScannerScreen extends StatefulWidget {
  const PharmacyScannerScreen({super.key});
  @override
  State<PharmacyScannerScreen> createState() => _PharmacyScannerScreenState();
}

class _PharmacyScannerScreenState extends State<PharmacyScannerScreen> {
  MobileScannerController? _scanner;
  bool _scannerOpen = false;
  bool _scanned = false;
  Map<String, dynamic>? _lastScanInfo;

  void _openScanner() {
    setState(() {
      _scanner = MobileScannerController();
      _scannerOpen = true;
      _scanned = false;
    });
  }

  void _closeScanner() {
    _scanner?.dispose();
    setState(() {
      _scanner = null;
      _scannerOpen = false;
    });
  }

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocListener<PharmacyBloc, PharmacyState>(
        listener: (context, state) {
          if (state is PharmacyPrescriptionVerified) {
            _closeScanner();
            setState(() {
              _lastScanInfo = {'status': 'verified', 'prescription': state.prescription};
            });
            context.push('${AppRoutes.pharmacyPrescriptionDetail}?id=${state.prescription['id'] ?? 'unknown'}');
          } else if (state is PharmacyQrAlreadyUsed) {
            _closeScanner();
            setState(() => _lastScanInfo = {'status': 'used', 'message': state.message});
          } else if (state is PharmacyQrExpired) {
            _closeScanner();
            setState(() => _lastScanInfo = {'status': 'expired', 'message': state.message});
          } else if (state is PharmacyError) {
            _closeScanner();
            setState(() {
              _scanned = false;
              _lastScanInfo = {'status': 'error', 'message': state.message};
            });
          }
        },
        child: _scannerOpen ? _buildScannerView(auth) : _buildDashboardView(auth),
      ),
    );
  }

  Widget _buildDashboardView(AuthAuthenticated auth) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pharmacy Portal', style: AppTextStyles.titleLg.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
              Text(auth.user.displayName, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.background,
                    title: Text('Log Out', style: AppTextStyles.titleLg.copyWith(color: AppTheme.primary)),
                    content: const Text('Sign out of CareCrypt Pharmacy?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(AuthLogoutRequested());
                          context.go(AppRoutes.login);
                        },
                        child: Text('Log Out', style: AppTextStyles.titleMd.copyWith(color: AppTheme.error)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.logout_outlined, size: 18, color: AppTheme.outline),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero scanner button
              _buildHeroScanButton(),
              const SizedBox(height: 24),
              // Last scan result
              if (_lastScanInfo != null) _buildLastScanResult(),
              if (_lastScanInfo != null) const SizedBox(height: 24),
              // Security info
              _buildSecurityInfo(),
              const SizedBox(height: 24),
              // Instructions
              _buildInstructions(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroScanButton() {
    final state = context.read<PharmacyBloc>().state;
    final isProcessing = state is PharmacyLoading;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryContainer, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : const Icon(Icons.qr_code_scanner, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            isProcessing ? 'Verifying QR...' : 'Scan Patient QR Code',
            style: AppTextStyles.titleLg.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isProcessing
                ? 'Checking token and fetching prescription...'
                : 'Tap to open camera and scan the patient\'s encrypted QR',
            style: AppTextStyles.bodyMd.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : _openScanner,
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text('Open Scanner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: AppTextStyles.titleMd.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastScanResult() {
    final info = _lastScanInfo!;
    final status = info['status'] as String;

    final (icon, color, bg, title, subtitle) = switch (status) {
      'verified' => (
          Icons.check_circle_outline,
          AppTheme.secondary,
          AppTheme.secondaryContainer.withValues(alpha: 0.2),
          'Prescription Verified',
          'QR was valid. Prescription retrieved successfully.',
        ),
      'used' => (
          Icons.block_outlined,
          AppTheme.error,
          AppTheme.errorContainer.withValues(alpha: 0.2),
          'QR Already Used',
          info['message'] as String? ?? 'This QR code has already been scanned and used.',
        ),
      'expired' => (
          Icons.timer_off_outlined,
          AppTheme.warningAmber,
          AppTheme.warningContainer.withValues(alpha: 0.5),
          'QR Expired',
          info['message'] as String? ?? 'This QR code has expired. Patient needs to generate a new one.',
        ),
      _ => (
          Icons.error_outline,
          AppTheme.error,
          AppTheme.errorContainer.withValues(alpha: 0.2),
          'Scan Failed',
          info['message'] as String? ?? 'Could not process QR code.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMd.copyWith(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _lastScanInfo = null),
            icon: Icon(Icons.close, size: 18, color: color.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _infoRow(Icons.lock_outlined, 'AES-256-GCM encrypted prescriptions'),
          const SizedBox(height: 10),
          _infoRow(Icons.verified_outlined, 'Ed25519 digital signature verification'),
          const SizedBox(height: 10),
          _infoRow(Icons.block_outlined, 'One-time QR — invalidates after first scan'),
          const SizedBox(height: 10),
          _infoRow(Icons.timer_outlined, '5-minute validity window'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant))),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryFixed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('How to Scan', style: AppTextStyles.titleMd.copyWith(color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 10),
          _step('1', 'Ask patient to open CareCrypt and generate QR'),
          _step('2', 'Tap "Open Scanner" above'),
          _step('3', 'Point camera at patient\'s QR code'),
          _step('4', 'QR auto-validates and closes camera'),
          _step('5', 'Review and dispense prescription'),
        ],
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
            child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface))),
        ],
      ),
    );
  }

  Widget _buildScannerView(AuthAuthenticated auth) {
    return Stack(
      children: [
        // Camera feed
        MobileScanner(
          controller: _scanner!,
          onDetect: (capture) {
            if (_scanned) return;
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              setState(() => _scanned = true);
              context.read<PharmacyBloc>().add(PharmacyScanQr(
                qrPayload: barcode!.rawValue!,
                pharmacistId: auth.user.id,
              ));
            }
          },
        ),
        // Overlay
        SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _closeScanner,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    Text('CareCrypt Pharmacy', style: AppTextStyles.titleMd.copyWith(color: Colors.white, shadows: [const Shadow(blurRadius: 8)])),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _scanner?.toggleTorch(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.flashlight_on_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Scanner frame
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryContainer, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _scanned
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 16),
                              Text('Verifying...', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                            ]),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Align QR within frame', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Scanner closes automatically after detection', style: AppTextStyles.bodyMd.copyWith(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outlined, size: 14, color: AppTheme.secondaryFixed),
                        const SizedBox(width: 4),
                        Text('AES-256-GCM + One-Time Token', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondaryFixed)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _closeScanner,
                      icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                      label: const Text('Close Camera', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pharmacy Prescription Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class PharmacyPrescriptionDetailScreen extends StatelessWidget {
  final String prescriptionId;
  const PharmacyPrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Prescription Details', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        elevation: 0,
      ),
      body: BlocConsumer<PharmacyBloc, PharmacyState>(
        listener: (context, state) {
          if (state is PharmacyDispenseSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Medicine dispensed successfully'), backgroundColor: AppTheme.secondary),
            );
            context.pop();
          }
        },
        builder: (context, state) {
          if (state is! PharmacyPrescriptionVerified) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final rx = state.prescription;
          final meds = (rx['medicines'] as List<dynamic>? ?? []).map((m) => m.toString()).toList();
          final auth = context.read<AuthBloc>().state as AuthAuthenticated;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Verification banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: state.signatureValid ? AppTheme.safeGreenContainer : AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (state.signatureValid ? AppTheme.safeGreen : AppTheme.warningAmber).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (state.signatureValid ? AppTheme.safeGreen : AppTheme.warningAmber).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        state.signatureValid ? Icons.verified : Icons.warning_amber,
                        color: state.signatureValid ? AppTheme.safeGreen : AppTheme.warningAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.signatureValid ? 'Signature Verified' : 'Unverified Signature',
                            style: AppTextStyles.titleMd.copyWith(
                              color: state.signatureValid ? AppTheme.safeGreen : AppTheme.warningAmber,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            state.signatureValid
                                ? 'Ed25519 authenticated — prescription is authentic'
                                : 'Could not verify doctor signature',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: (state.signatureValid ? AppTheme.safeGreen : AppTheme.warningAmber).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Prescription card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medication_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Prescription', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('${meds.length} Medicine${meds.length != 1 ? 's' : ''}',
                              style: AppTextStyles.labelMd.copyWith(color: AppTheme.secondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...meds.asMap().entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${e.key + 1}',
                                  style: AppTextStyles.titleMd.copyWith(color: AppTheme.secondary, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.value, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface))),
                          const Icon(Icons.medication, size: 16, color: AppTheme.outline),
                        ],
                      ),
                    )),
                    if (rx['instructions'] != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.notes_outlined, size: 16, color: AppTheme.outline),
                          const SizedBox(width: 6),
                          Text('Instructions', style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(rx['instructions'] as String, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Dispense button
              ElevatedButton.icon(
                onPressed: () => context.read<PharmacyBloc>().add(PharmacyDispenseMedicine(
                  prescriptionId: rx['id'] as String? ?? '',
                  pharmacistId: auth.user.id,
                  patientId: rx['patient_id'] as String? ?? '',
                  medicines: meds,
                )),
                icon: const Icon(Icons.local_pharmacy_outlined, size: 20),
                label: Text('Dispense Medicine', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
