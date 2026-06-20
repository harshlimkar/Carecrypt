import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/doctor_bloc.dart';
import '../../../shared/widgets/cc_bottom_nav.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedNav = 0;
  NfcSessionState _nfcState = NfcSessionState.idle;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    context.read<DoctorBloc>().add(DoctorLoadDashboard(doctorId: auth.user.id));
  }

  Future<void> _startNfcSession() async {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    final keys = await CryptoService.generateX25519KeyPair();
    final result = await NfcService.initiateSession(
      myPublicKeyBase64: keys['publicKey']!,
      myUserId: auth.user.id,
      role: NfcAccessRole.doctor,
      onStateChange: (state) {
        if (mounted) setState(() => _nfcState = state);
      },
    );

    if (result.success && result.patientId != null) {
      if (mounted) {
        context.push('${AppRoutes.doctorPatientAccess}?patientId=${result.patientId}');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'NFC session failed'), backgroundColor: AppTheme.error),
        );
        setState(() => _nfcState = NfcSessionState.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: _buildNfcFab(),
      body: BlocListener<DoctorBloc, DoctorState>(
        listener: (context, state) {
          if (state is DoctorActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary));
          }
          if (state is DoctorError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.error));
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppTheme.background.withValues(alpha: 0.92),
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: Text('CareCrypt', style: AppTextStyles.titleLg.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
              actions: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Log Out', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
                        content: Text('Sign out of CareCrypt Doctor Portal?', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.read<AuthBloc>().add(AuthLogoutRequested());
                              context.go(AppRoutes.login);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('Log Out', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, shape: BoxShape.circle, border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4))),
                    child: const Icon(Icons.logout_outlined, size: 18, color: AppTheme.outline),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),
                  // Welcome
                  Text('Welcome, Dr. ${auth.user.displayName.split(' ').last}',
                      style: AppTextStyles.headlineLgMobile.copyWith(color: AppTheme.onSurface)),
                  Text(auth.user.email, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                  const SizedBox(height: 24),
                  // NFC connect card
                  _buildNfcConnectCard(),
                  const SizedBox(height: 24),
                  // Quick actions
                  _buildQuickActions(auth),
                  const SizedBox(height: 24),
                  // Patient list
                  _buildPatientList(),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CcBottomNav(
        selectedIndex: _selectedNav,
        role: AppRoles.doctor,
        onTap: (i) => setState(() => _selectedNav = i),
      ),
    );
  }

  Widget _buildNfcConnectCard() {
    final isScanning = _nfcState == NfcSessionState.scanning;
    return GestureDetector(
      onTap: isScanning ? null : _startNfcSession,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isScanning
                ? [AppTheme.secondary, AppTheme.secondaryContainer]
                : [AppTheme.primaryContainer, AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(isScanning ? Icons.wifi_find : Icons.nfc, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isScanning ? 'Scanning for patient...' : 'Connect via NFC',
                    style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                  ),
                  Text(
                    isScanning ? 'Hold near patient device' : 'Tap to establish secure session',
                    style: AppTextStyles.bodyMd.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (isScanning)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AuthAuthenticated auth) {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.biotech_outlined,
            label: 'Lab Request',
            onTap: () => context.push('${AppRoutes.doctorLabRequest}?patientId='),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            icon: Icons.medication_outlined,
            label: 'Prescription',
            onTap: () => context.push('${AppRoutes.doctorPrescription}?patientId='),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primaryFixed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    return BlocBuilder<DoctorBloc, DoctorState>(
      builder: (context, state) {
        if (state is DoctorLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        if (state is! DoctorDashboardLoaded) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Patients', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 12),
            ...state.recentPatients.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryFixed.withValues(alpha: 0.3),
                  child: Text((p['name'] as String? ?? 'P')[0], style: AppTextStyles.titleMd.copyWith(color: AppTheme.primary)),
                ),
                title: Text(p['name'] as String? ?? 'Patient', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                subtitle: Text(p['patient_id'] as String? ?? '', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.outlineVariant),
                onTap: () => context.push('${AppRoutes.doctorPatientAccess}?patientId=${p['patient_id']}'),
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildNfcFab() {
    return FloatingActionButton.extended(
      onPressed: _nfcState == NfcSessionState.scanning ? null : _startNfcSession,
      backgroundColor: AppTheme.primaryContainer,
      icon: const Icon(Icons.nfc, color: AppTheme.onPrimary),
      label: Text('NFC Connect', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
    );
  }
}
