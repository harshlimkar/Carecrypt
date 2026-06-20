import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/ai_service.dart';
import '../bloc/patient_bloc.dart';
import '../models/patient_models.dart';
import '../../../shared/widgets/cc_encrypted_badge.dart';
import '../../../shared/widgets/cc_safety_score_chip.dart';

class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text('Health Records', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        actions: const [CcEncryptedBadge(), SizedBox(width: 12)],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.outline,
          indicatorColor: AppTheme.primary,
          labelStyle: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Diagnoses'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Reports'),
            Tab(text: 'Nurse Logs'),
            Tab(text: 'Access Logs'),
          ],
        ),
      ),
      body: BlocBuilder<PatientBloc, PatientState>(
        builder: (context, state) {
          if (state is! PatientDashboardLoaded) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildDiagnoses(state.diagnoses),
              _buildPrescriptions(state.prescriptions, state.aiScores),
              _buildLabReports(state.labReports),
              _buildNurseLogs(state.nurseLogs),
              _buildAccessLogs(state.accessLogs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagnoses(List<Diagnosis> diagnoses) {
    if (diagnoses.isEmpty) return _emptyState('No diagnoses on record');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: diagnoses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final d = diagnoses[i];
        return _recordCard(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.monitor_heart_outlined, color: AppTheme.error, size: 22),
          ),
          title: d.diagnosis,
          subtitle: 'Dr. ID: ${d.doctorId.substring(0, 8)}...',
          trailing: _statusChip(d.status),
          date: _formatDate(d.createdAt),
        );
      },
    );
  }

  Widget _buildPrescriptions(List<Prescription> prescriptions, List<AiSafetyScore> scores) {
    if (prescriptions.isEmpty) return _emptyState('No prescriptions on record');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final rx = prescriptions[i];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_outlined, color: AppTheme.onSecondaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prescription', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                        Text(_formatDate(rx.createdAt), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                      ],
                    ),
                  ),
                  _statusChip(rx.status),
                ],
              ),
              if (rx.medicines.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text('Medicines', style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                ...rx.medicines.map((med) {
                  final matchingScore = scores.where((s) => s.medicine.toLowerCase() == med.toLowerCase()).firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppTheme.outline),
                        const SizedBox(width: 10),
                        Expanded(child: Text(med, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface))),
                        if (matchingScore != null) CcSafetyScoreChip(score: matchingScore),
                      ],
                    ),
                  );
                }),
              ],
              if (rx.signature != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text('Ed25519 Signed', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabReports(List<LabReport> reports) {
    if (reports.isEmpty) return _emptyState('No lab reports yet');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = reports[i];
        return _recordCard(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.tertiaryFixed.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.science_outlined, color: AppTheme.tertiary, size: 22),
          ),
          title: 'Lab Report',
          subtitle: 'Request: ${r.requestId.substring(0, 8)}...',
          trailing: r.verified
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppTheme.secondary),
                  const SizedBox(width: 4),
                  Text('Verified', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
                ])
              : const SizedBox.shrink(),
          date: _formatDate(r.createdAt),
        );
      },
    );
  }

  Widget _buildNurseLogs(List<NurseLog> logs) {
    if (logs.isEmpty) return _emptyState('No nurse activity recorded');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final log = logs[i];
        return _recordCard(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medical_information_outlined, color: AppTheme.primary, size: 22),
          ),
          title: log.action.replaceAll('_', ' '),
          subtitle: log.notes ?? 'No notes',
          trailing: const SizedBox.shrink(),
          date: _formatDate(log.timestamp),
        );
      },
    );
  }

  Widget _buildAccessLogs(List<AccessLog> logs) {
    if (logs.isEmpty) return _emptyState('No access events recorded');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final log = logs[i];
        return Container(
          decoration: BoxDecoration(
            color: log.isHoneypot
                ? AppTheme.errorContainer.withValues(alpha: 0.3)
                : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: log.isHoneypot ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                log.isHoneypot ? Icons.warning_amber_rounded : Icons.security_outlined,
                color: log.isHoneypot ? AppTheme.error : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.action.replaceAll('_', ' '), style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    Text(log.accessorId, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                  ],
                ),
              ),
              Text(_formatDate(log.timestamp), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
            ],
          ),
        );
      },
    );
  }

  Widget _recordCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget trailing,
    required String date,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                Text(date, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (color, bg) = switch (status.toLowerCase()) {
      'active' || 'approved' || 'completed' || 'dispensed' => (AppTheme.safeGreen, AppTheme.safeGreenContainer),
      'pending' => (AppTheme.warningAmber, AppTheme.warningContainer),
      'rejected' || 'cancelled' => (AppTheme.dangerRed, AppTheme.dangerContainer),
      _ => (AppTheme.outline, AppTheme.surfaceContainerLow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(status.toUpperCase(), style: AppTextStyles.codeSm.copyWith(color: color, fontSize: 10)),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppTheme.outlineVariant),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
