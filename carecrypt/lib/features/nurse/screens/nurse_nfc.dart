import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../lab/bloc/lab_bloc.dart';

// NurseBloc is in lab_bloc.dart (same file)

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
    // Web or no NFC: show demo picker
    if (kIsWeb) {
      _showNfcDemoSheet();
      return;
    }

    try {
      final available = await NfcService.isAvailable();
      if (!available) {
        if (mounted) _showNfcDemoSheet();
        return;
      }
    } catch (_) {
      if (mounted) _showNfcDemoSheet();
      return;
    }

    if (!mounted) return;
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
        _showNfcDemoSheet();
        setState(() => _nfcState = NfcSessionState.idle);
      }
    }
  }

  void _showNfcDemoSheet() async {
    // Fetch patients for demo
    setState(() => _nfcState = NfcSessionState.scanning);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _nfcState = NfcSessionState.idle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NurseDemoSheet(
        onPatientSelected: (patientId) {
          context.push('${AppRoutes.nurseTreatment}?patientId=$patientId');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text('Nurse NFC Access', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
          ],
        ),
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
                    ? 'Connecting to patient device...'
                    : _nfcState == NfcSessionState.connected
                        ? 'Connected!'
                        : 'Tap NFC to Access Patient',
                style: AppTextStyles.headlineMd.copyWith(color: AppTheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'NFC demo mode — tap below to select a patient'
                    : 'Hold your device near the patient\'s phone or NFC tag to establish a secure X25519 session',
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
                  _nfcState == NfcSessionState.scanning
                      ? 'Scanning...'
                      : kIsWeb
                          ? 'Select Patient (Demo)'
                          : 'Start NFC Scan',
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
                      child: Text(
                        kIsWeb
                            ? 'Demo mode active • Role-scoped access • Treatment data only'
                            : 'X25519 key exchange • End-to-end encrypted • Treatment scope only',
                        style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                      ),
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

// ─── NFC Demo Sheet ─────────────────────────────────────
class _NurseDemoSheet extends StatefulWidget {
  final void Function(String patientId) onPatientSelected;
  const _NurseDemoSheet({required this.onPatientSelected});

  @override
  State<_NurseDemoSheet> createState() => _NurseDemoSheetState();
}

class _NurseDemoSheetState extends State<_NurseDemoSheet> {
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('patients')
          .select('patient_id, name, health_status, blood_type')
          .limit(8);
      if (mounted) {
        setState(() {
          _patients = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(100)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.nfc_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NFC Patient Access — Demo', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
                        Text('Select patient to simulate nurse NFC scan', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nurse access is role-scoped: only treatment data (medicines, injections, diagnosis summary)',
                        style: AppTextStyles.labelMd.copyWith(color: AppTheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Patient', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else if (_patients.isEmpty)
                Center(child: Text('No patients found', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)))
              else
                ..._patients.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      child: Text(
                        (p['name'] as String? ?? 'P')[0],
                        style: const TextStyle(color: AppTheme.onPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(p['name'] as String? ?? 'Patient', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    subtitle: Row(
                      children: [
                        Text(p['patient_id'] as String? ?? '', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                        if (p['blood_type'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(p['blood_type'] as String, style: AppTextStyles.codeSm.copyWith(color: AppTheme.error, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.nfc, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text('Scan', style: AppTextStyles.codeSm.copyWith(color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final patientId = p['patient_id'] as String? ?? '';
                      if (patientId.isNotEmpty) {
                        widget.onPatientSelected(patientId);
                      }
                    },
                  ),
                )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}



// ─── Nurse Treatment Screen ──────────────────────────────

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
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text('Treatment Dashboard', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
          ],
        ),
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
            // Reload treatment data after action
            final auth = context.read<AuthBloc>().state as AuthAuthenticated;
            context.read<NurseBloc>().add(NurseLoadTreatment(patientId: widget.patientId, nurseId: auth.user.id));
          }
          if (state is NurseError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.error));
          }
        },
        builder: (context, state) {
          if (state is NurseLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (state is NurseError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<NurseBloc>().add(NurseLoadTreatment(patientId: widget.patientId, nurseId: auth.user.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is! NurseTreatmentLoaded) {
            return const SizedBox.shrink();
          }

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
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text((state.patient['name'] as String? ?? 'P')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(state.patient['name'] as String? ?? '', style: AppTextStyles.titleLg.copyWith(color: Colors.white)),
                      Text(widget.patientId, style: AppTextStyles.codeSm.copyWith(color: Colors.white70)),
                      if (state.patient['blood_type'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('${state.patient['blood_type']} • ${state.patient['gender'] ?? ''}', style: AppTextStyles.labelMd.copyWith(color: Colors.white)),
                        ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Allergies alert
              if (state.patient['allergies'] != null && state.patient['allergies'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('⚠️ Allergies: ${state.patient['allergies']}', style: AppTextStyles.titleMd.copyWith(color: AppTheme.error))),
                  ]),
                ),

              // Diagnoses (read-only)
              Text('Current Diagnoses', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              if (state.diagnoses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text('No active diagnoses', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                )
              else
                ...state.diagnoses.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.monitor_heart_outlined, color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d['diagnosis'] as String? ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(d['status'] as String? ?? 'active', style: AppTextStyles.codeSm.copyWith(color: AppTheme.error, fontSize: 10)),
                    ),
                  ]),
                )),
              const SizedBox(height: 16),

              // Medicine Schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Medicine Schedule', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                    child: Text('Tap "Given" to log administration', style: AppTextStyles.labelMd.copyWith(color: AppTheme.secondary, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.prescriptions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text('No current prescriptions', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                )
              else
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
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.medication_outlined, color: AppTheme.secondary, size: 20),
                      ),
                      title: Text(med, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                      subtitle: rx['instructions'] != null ? Text(rx['instructions'] as String, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline, fontSize: 12)) : null,
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
              const SizedBox(height: 16),

              // Injection log button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vaccines_outlined, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Log Injection / Procedure', style: AppTextStyles.titleMd.copyWith(color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showInjectionDialog(auth.user.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Record Injection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Vital Signs Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_heart_outlined, color: AppTheme.tertiary, size: 18),
                        const SizedBox(width: 8),
                        Text('Record Vital Signs', style: AppTextStyles.titleMd.copyWith(color: AppTheme.tertiary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showVitalsDialog(auth.user.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Record BP / Temp / HR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tertiary,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lab Reports (Read-Only)
              Text('Lab Reports (Read-Only)', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              if (state.labReports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text('No lab reports available', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                )
              else
                ...state.labReports.map((report) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.biotech_outlined, color: AppTheme.primary),
                    title: Text(report['test_type'] as String? ?? 'Lab Test', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    subtitle: Text('Status: ${report['status'] ?? 'pending'}', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                    trailing: const Icon(Icons.lock_outline, size: 16, color: AppTheme.outline),
                  ),
                )),
              const SizedBox(height: 16),

              // Treatment & Vitals History
              Text('Treatment & Vitals History', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              const SizedBox(height: 8),
              if (state.nurseLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                  child: Text('No actions logged yet', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                )
              else
                ...state.nurseLogs.map((log) {
                  final isVitals = log['action'] == 'VITALS_RECORDED';
                  final isInjection = log['action'] == 'INJECTION_GIVEN';
                  final title = isVitals 
                      ? 'Vitals Recorded' 
                      : (isInjection ? 'Injection Logged' : 'Medicine Administered');
                  final icon = isVitals 
                      ? Icons.monitor_heart_outlined 
                      : (isInjection ? Icons.vaccines_outlined : Icons.medication_outlined);
                  final color = isVitals 
                      ? AppTheme.tertiary 
                      : (isInjection ? AppTheme.primary : AppTheme.secondary);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(log['notes'] as String? ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                              const SizedBox(height: 4),
                              Text(
                                log['timestamp'] != null 
                                    ? DateTime.parse(log['timestamp'] as String).toLocal().toString().substring(0, 16)
                                    : '',
                                style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // Security note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_outlined, color: AppTheme.outline, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nurse view: scoped access • Read-only lab test status • No private patient keys',
                        style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInjectionDialog(String nurseId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Injection', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g. Insulin 10 units subcutaneous',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<NurseBloc>().add(NurseUpdateInjection(
                  patientId: widget.patientId,
                  nurseId: nurseId,
                  injection: controller.text,
                ));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Log', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVitalsDialog(String nurseId) {
    final bpController = TextEditingController(text: '120/80');
    final tempController = TextEditingController(text: '98.6');
    final hrController = TextEditingController(text: '72');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Record Vital Signs', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bpController,
              decoration: const InputDecoration(
                labelText: 'Blood Pressure (e.g. 120/80)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tempController,
              decoration: const InputDecoration(
                labelText: 'Temperature (°F, e.g. 98.6)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hrController,
              decoration: const InputDecoration(
                labelText: 'Heart Rate (bpm, e.g. 72)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<NurseBloc>().add(NurseUpdateVitals(
                patientId: widget.patientId,
                nurseId: nurseId,
                bp: bpController.text.trim(),
                temp: tempController.text.trim(),
                hr: hrController.text.trim(),
              ));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tertiary),
            child: Text('Record', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
