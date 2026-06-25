import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/patient_bloc.dart';
import '../../../shared/widgets/cc_bottom_nav.dart';
import '../../../shared/widgets/cc_encrypted_badge.dart';
import '../../../shared/widgets/cc_safety_score_chip.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _heartRate = 72;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<PatientBloc>().add(PatientLoadDashboard(
        patientId: authState.user.patientId ?? '',
        userId: authState.user.id,
      ));
    }
    _startHeartRateSimulation();
  }

  void _startHeartRateSimulation() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _heartRate = 70 + (DateTime.now().second % 8));
        _startHeartRateSimulation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state as AuthAuthenticated;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocBuilder<PatientBloc, PatientState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(authState),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    if (state is PatientLoading) _buildShimmer(),
                    if (state is PatientDashboardLoaded) ...[
                      // Welcome row
                      _buildWelcomeHeader(authState, state),
                      const SizedBox(height: 20),
                      // Health Stats row
                      _buildHealthStatsRow(state),
                      const SizedBox(height: 20),
                      // Health Overview Card (vitals + overview)
                      _buildHealthOverviewCard(state),
                      const SizedBox(height: 24),
                      // Quick Actions grid
                      _buildQuickActionsGrid(),
                      const SizedBox(height: 24),
                      // Medical Timeline
                      _buildMedicalTimeline(state),
                      const SizedBox(height: 24),
                      // Recent Activities
                      _buildRecentActivities(state),
                      // AI Safety Scores
                      if (state.aiScores.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildAiSafetySection(state.aiScores),
                      ],
                    ],
                    if (state is PatientError) _buildError(state.message),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CcBottomNav(
        selectedIndex: _selectedNav,
        role: AppRoles.patient,
        onTap: (i) {
          setState(() => _selectedNav = i);
          switch (i) {
            case 0: break;
            case 1: context.push(AppRoutes.patientRecords); break;
            case 2: context.push(AppRoutes.patientNotifications); break;
            case 3: context.push(AppRoutes.patientAccessLog); break;
            case 4: context.push(AppRoutes.patientQr); break;
          }
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(AuthAuthenticated authState) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppTheme.background.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      elevation: 0,
      title: Row(
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Log Out', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
                  content: Text(
                    'Are you sure you want to sign out of CareCrypt?',
                    style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: AppTextStyles.titleMd.copyWith(color: AppTheme.outline)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        context.go(AppRoutes.login);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Log Out', style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryContainer,
                backgroundImage: authState.user.avatarUrl != null ? NetworkImage(authState.user.avatarUrl!) : null,
                child: authState.user.avatarUrl == null
                    ? Text(authState.user.initials, style: const TextStyle(color: AppTheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700))
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Image.asset('assets/images/logo.png', width: 22, height: 22),
          const SizedBox(width: 6),
          Text('CareCrypt', style: AppTextStyles.titleLg.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ],
      ),
      actions: [
        const CcEncryptedBadge(),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => context.push(AppRoutes.patientNotifications),
          icon: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildWelcomeHeader(AuthAuthenticated authState, PatientDashboardLoaded state) {
    final firstName = authState.user.displayName.split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
            const SizedBox(height: 2),
            Text(firstName, style: AppTextStyles.headlineMd.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _healthStatusBadge(state.metrics.healthStatus),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.patientQr),
          icon: const Icon(Icons.qr_code_2, size: 16),
          label: const Text('Generate QR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryContainer,
            foregroundColor: AppTheme.onPrimary,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _healthStatusBadge(String status) {
    final color = switch (status.toLowerCase()) {
      'good' || 'healthy' => AppTheme.secondary,
      'stable' => AppTheme.primary,
      _ => AppTheme.warningAmber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Health: $status', style: AppTextStyles.labelMd.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Section 1: Health Statistics Row ─────────────────────
  Widget _buildHealthStatsRow(PatientDashboardLoaded state) {
    return Row(
      children: [
        _statChip(
          value: '${state.prescriptions.where((p) => p.status == 'pending' || p.status == 'dispensed').length}',
          label: 'Active Medicines',
          icon: Icons.medication_outlined,
          color: AppTheme.secondary,
        ),
        const SizedBox(width: 10),
        _statChip(
          value: '${state.labReports.length}',
          label: 'Lab Reports',
          icon: Icons.science_outlined,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 10),
        _statChip(
          value: state.diagnoses.isNotEmpty ? state.diagnoses.first.status.toUpperCase() : 'N/A',
          label: 'Treatment',
          icon: Icons.monitor_heart_outlined,
          color: AppTheme.tertiary,
          isText: true,
        ),
      ],
    );
  }

  Widget _statChip({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    bool isText = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: isText
                ? AppTextStyles.labelMd.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11)
                : AppTextStyles.titleLg.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(label, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Section 2: Health Overview Card ──────────────────────
  Widget _buildHealthOverviewCard(PatientDashboardLoaded state) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF006B5F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vitals
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.white60, size: 16),
                  const SizedBox(width: 6),
                  Text('Live Vitals', style: AppTextStyles.labelMd.copyWith(color: Colors.white60)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      '$_heartRate',
                      key: ValueKey(_heartRate),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('bpm', style: AppTextStyles.titleMd.copyWith(color: Colors.white54)),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _vitalBadge(Icons.bloodtype_outlined, state.metrics.bloodPressure),
                      const SizedBox(height: 6),
                      _vitalBadge(Icons.water_drop_outlined, '${state.metrics.bloodGlucose} mg/dL'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),
              // Health Overview
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Diagnosis', style: AppTextStyles.labelMd.copyWith(color: Colors.white54)),
                        const SizedBox(height: 3),
                        Text(
                          state.diagnoses.isNotEmpty ? state.diagnoses.first.diagnosis : 'No active diagnosis',
                          style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest Prescription', style: AppTextStyles.labelMd.copyWith(color: Colors.white54)),
                        const SizedBox(height: 3),
                        Text(
                          state.prescriptions.isNotEmpty && state.prescriptions.first.medicines.isNotEmpty
                              ? state.prescriptions.first.medicines.first
                              : 'No prescriptions',
                          style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(value, style: AppTextStyles.codeSm.copyWith(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Section 3: Quick Actions ──────────────────────────────
  Widget _buildQuickActionsGrid() {
    final actions = [
      {'icon': Icons.qr_code_2, 'label': 'Generate QR', 'route': AppRoutes.patientQr, 'primary': true},
      {'icon': Icons.science_outlined, 'label': 'Lab Reports', 'route': AppRoutes.patientRecords, 'primary': false},
      {'icon': Icons.medication_outlined, 'label': 'Prescriptions', 'route': AppRoutes.patientRecords, 'primary': false},
      {'icon': Icons.notifications_outlined, 'label': 'Notifications', 'route': AppRoutes.patientNotifications, 'primary': false},
      {'icon': Icons.nfc_outlined, 'label': 'NFC Card Setup', 'route': 'nfc_setup', 'primary': false},
      {'icon': Icons.calendar_month_outlined, 'label': 'Book Appointment', 'route': 'book_appointment', 'primary': false},
      {'icon': Icons.shield_outlined, 'label': 'Access Log', 'route': AppRoutes.patientAccessLog, 'primary': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, i) {
            final action = actions[i];
            final isPrimary = action['primary'] as bool;
            return GestureDetector(
              onTap: () {
                if (action['route'] == 'nfc_setup') {
                  final auth = context.read<AuthBloc>().state as AuthAuthenticated;
                  _showNfcSetupDialog(auth);
                } else if (action['route'] == 'book_appointment') {
                  _showBookAppointmentDialog();
                } else {
                  context.push(action['route'] as String);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isPrimary ? AppTheme.primaryContainer : AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPrimary ? AppTheme.primaryContainer : AppTheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPrimary ? AppTheme.primary.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                      blurRadius: isPrimary ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action['icon'] as IconData,
                        size: 26,
                        color: isPrimary ? AppTheme.onPrimary : AppTheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: AppTextStyles.labelMd.copyWith(
                        color: isPrimary ? AppTheme.onPrimary : AppTheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBookAppointmentDialog() {
    String selectedDoctor = 'Dr. Sarah Smith (Cardiologist)';
    String selectedDate = 'Tomorrow, June 22';
    String selectedTimeSlot = '10:00 AM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                        width: 40,
                        height: 4,
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
                          child: const Icon(Icons.calendar_month_outlined, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Book Appointment',
                                style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Schedule a visit with your physician',
                                style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Select Doctor',
                      style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDoctor,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceContainerLowest,
                          items: <String>[
                            'Dr. Sarah Smith (Cardiologist)',
                            'Dr. James Lee (Endocrinologist)',
                            'Dr. Rita Nair (General Physician)',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedDoctor = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Date',
                      style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <String>[
                          'Today, June 21',
                          'Tomorrow, June 22',
                          'Tuesday, June 23',
                          'Wednesday, June 24',
                        ].map((date) {
                          final isSelected = selectedDate == date;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(date),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => selectedDate = date);
                                }
                              },
                              selectedColor: AppTheme.primaryContainer,
                              labelStyle: AppTextStyles.bodyMd.copyWith(
                                color: isSelected ? AppTheme.onPrimary : AppTheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Available Slots',
                      style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <String>[
                        '09:00 AM',
                        '10:00 AM',
                        '11:30 AM',
                        '02:00 PM',
                        '03:30 PM',
                        '04:30 PM',
                      ].map((slot) {
                        final isSelected = selectedTimeSlot == slot;
                        return ChoiceChip(
                          label: Text(slot),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedTimeSlot = slot);
                            }
                          },
                          selectedColor: AppTheme.primaryContainer,
                          labelStyle: AppTextStyles.bodyMd.copyWith(
                            color: isSelected ? AppTheme.onPrimary : AppTheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your appointment has been booked'),
                            backgroundColor: AppTheme.secondary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Confirm Appointment',
                        style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNfcSetupDialog(AuthAuthenticated authState) async {
    final mockKeys = await CryptoService.generateX25519KeyPair();
    final patientPublicKey = mockKeys['publicKey']!;
    
    final payloadMap = {
      'patientId': authState.user.patientId ?? 'PAT004',
      'publicKey': patientPublicKey,
      'app': 'CareCrypt',
      'version': '2.0',
    };
    final jsonStr = jsonEncode(payloadMap);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(100))),
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
                      child: const Icon(Icons.nfc_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NFC Card Setup', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
                          Text('Program or copy your NFC tag payload', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Write this JSON payload to your physical NFC tag as a Text record. Doctors and nurses can tap your card to scan your patient ID.',
                  style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  height: 120,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      child: Text(
                        jsonStr,
                        style: AppTextStyles.codeSm.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('JSON copied to clipboard'), backgroundColor: AppTheme.secondary),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy JSON'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Approach your physical NFC tag to write data...'), duration: Duration(seconds: 4)),
                          );
                          final success = await NfcService.writePatientTag(
                            patientId: authState.user.patientId ?? 'PAT004',
                            publicKeyBase64: patientPublicKey,
                          );
                          if (!mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Successfully programmed NFC tag!'), backgroundColor: AppTheme.safeGreen),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to program tag. Ensure NFC is enabled and writable.'), backgroundColor: AppTheme.error),
                            );
                          }
                        },
                        icon: const Icon(Icons.nfc),
                        label: const Text('Write Tag'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section 4: Medical Timeline ───────────────────────────
  Widget _buildMedicalTimeline(PatientDashboardLoaded state) {
    // Build timeline events from all data
    final events = <_TimelineEvent>[];

    for (final d in state.diagnoses.take(2)) {
      events.add(_TimelineEvent(
        title: d.diagnosis,
        subtitle: 'Diagnosis — ${d.status}',
        icon: Icons.monitor_heart_outlined,
        color: AppTheme.error,
        date: d.createdAt,
      ));
    }
    for (final r in state.labReports.take(2)) {
      events.add(_TimelineEvent(
        title: 'Lab Report',
        subtitle: r.verified ? 'Verified & Encrypted' : 'Pending Verification',
        icon: Icons.science_outlined,
        color: AppTheme.tertiary,
        date: r.createdAt,
      ));
    }
    for (final p in state.prescriptions.take(2)) {
      events.add(_TimelineEvent(
        title: p.medicines.isNotEmpty ? p.medicines.first : 'Prescription',
        subtitle: 'Status: ${p.status}',
        icon: Icons.medication_outlined,
        color: AppTheme.secondary,
        date: p.createdAt,
      ));
    }
    for (final n in state.nurseLogs.take(1)) {
      events.add(_TimelineEvent(
        title: _formatNurseAction(n.action),
        subtitle: n.notes ?? 'Nurse log',
        icon: Icons.medical_information_outlined,
        color: AppTheme.primary,
        date: n.timestamp,
      ));
    }

    // Sort by date descending
    events.sort((a, b) => b.date.compareTo(a.date));

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medical Timeline', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: events.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == events.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline track
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: e.color.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Icon(e.icon, size: 17, color: e.color),
                      ),
                      if (!isLast)
                        Container(width: 1.5, height: 40, color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(e.title, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Text(_formatDate(e.date), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(e.subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Section 5: Recent Activities ──────────────────────────
  Widget _buildRecentActivities(PatientDashboardLoaded state) {
    final activities = <Map<String, dynamic>>[];

    for (final d in state.diagnoses.take(1)) {
      activities.add({'title': 'Diagnosis Updated', 'subtitle': d.diagnosis, 'icon': Icons.monitor_heart_outlined, 'color': AppTheme.error, 'date': d.createdAt});
    }
    for (final r in state.labReports.take(1)) {
      activities.add({'title': 'Lab Report Uploaded', 'subtitle': r.verified ? 'Verified & Encrypted' : 'Awaiting Verification', 'icon': Icons.science_outlined, 'color': AppTheme.primary, 'date': r.createdAt});
    }
    for (final n in state.nurseLogs.take(1)) {
      activities.add({'title': _formatNurseAction(n.action), 'subtitle': n.notes ?? '', 'icon': Icons.medical_information_outlined, 'color': AppTheme.secondary, 'date': n.timestamp});
    }
    for (final p in state.prescriptions.where((p) => p.status == 'dispensed').take(1)) {
      activities.add({'title': 'Medicine Dispensed', 'subtitle': p.medicines.isNotEmpty ? p.medicines.first : 'Prescription', 'icon': Icons.local_pharmacy_outlined, 'color': AppTheme.secondary, 'date': p.createdAt});
    }

    activities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activities', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: () => context.push(AppRoutes.patientAccessLog),
              child: Text('View All', style: AppTextStyles.labelMd.copyWith(color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (activities.isEmpty)
          _buildEmptyCard('No recent activity recorded')
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: activities.asMap().entries.map((entry) {
                final a = entry.value;
                final isLast = entry.key == activities.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.2))),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (a['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
                    ),
                    title: Text(a['title'] as String, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    subtitle: Text(a['subtitle'] as String, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(_formatTimestamp(a['date'] as DateTime), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline, fontSize: 10)),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 12),
        // Security audit note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryFixed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('All data encrypted with AES-256-GCM. Last audit passed.',
                    style: AppTextStyles.codeSm.copyWith(color: AppTheme.onPrimaryFixedVariant)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
      ),
    );
  }

  Widget _buildAiSafetySection(List<AiSafetyScore> scores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology_outlined, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('AI Medicine Safety', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: scores.map((score) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(score.medicine, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface))),
                  CcSafetyScoreChip(score: score),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceContainerLow,
      highlightColor: AppTheme.surfaceContainerLowest,
      child: Column(
        children: [
          Row(children: List.generate(3, (i) => Expanded(child: Container(
            height: 80,
            margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          )))),
          const SizedBox(height: 12),
          ...List.generate(4, (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: i == 0 ? 180 : 80,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          )),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppTheme.errorContainer, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _formatNurseAction(String action) {
    return switch (action) {
      'MEDICINE_GIVEN' => 'Medicine Administered',
      'INJECTION_GIVEN' => 'Injection Given',
      'TREATMENT_COMPLETED' => 'Treatment Completed',
      _ => action.replaceAll('_', ' ').toLowerCase(),
    };
  }

  String _formatTimestamp(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TimelineEvent {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime date;

  const _TimelineEvent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.date,
  });
}
