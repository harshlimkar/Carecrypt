import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/doctor_bloc.dart';

class DoctorPatientAccessScreen extends StatefulWidget {
  final String patientId;
  const DoctorPatientAccessScreen({super.key, required this.patientId});

  @override
  State<DoctorPatientAccessScreen> createState() => _DoctorPatientAccessScreenState();
}

class _DoctorPatientAccessScreenState extends State<DoctorPatientAccessScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    context.read<DoctorBloc>().add(DoctorLoadPatient(patientId: widget.patientId, doctorId: auth.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Patient Record', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 14, color: AppTheme.secondary),
                const SizedBox(width: 4),
                Text('NFC Session', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<DoctorBloc, DoctorState>(
        builder: (context, state) {
          if (state is DoctorLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          if (state is DoctorError) return Center(child: Text(state.message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.error)));
          if (state is! DoctorPatientLoaded) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientHeader(state.patient),
                const SizedBox(height: 20),
                _buildActionButtons(state),
                const SizedBox(height: 20),
                _buildSection('Active Diagnoses', _buildDiagnosisList(state.diagnoses)),
                const SizedBox(height: 16),
                _buildSection('Prescriptions', _buildPrescriptionList(state.prescriptions)),
                const SizedBox(height: 16),
                _buildSection('Lab Reports', _buildLabList(state.labReports)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientHeader(Map<String, dynamic> patient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primaryContainer, AppTheme.secondary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (patient['name'] as String? ?? 'P')[0],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(patient['name'] as String? ?? 'Patient', style: AppTextStyles.titleLg.copyWith(color: Colors.white)),
              Text(patient['patient_id'] as String? ?? '', style: AppTextStyles.codeSm.copyWith(color: Colors.white70)),
              Text('${patient['blood_type'] ?? 'N/A'} • ${patient['gender'] ?? ''}', style: AppTextStyles.bodyMd.copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DoctorPatientLoaded state) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Row(
      children: [
        Expanded(child: _actionBtn(Icons.monitor_heart_outlined, 'Diagnose', AppTheme.error, () => _showDiagnosisDialog(auth.user.id))),
        const SizedBox(width: 10),
        Expanded(child: _actionBtn(Icons.biotech_outlined, 'Lab Test', AppTheme.tertiary, () => context.push('${AppRoutes.doctorLabRequest}?patientId=${widget.patientId}'))),
        const SizedBox(width: 10),
        Expanded(child: _actionBtn(Icons.medication_outlined, 'Prescribe', AppTheme.secondary, () => context.push('${AppRoutes.doctorPrescription}?patientId=${widget.patientId}'))),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelMd.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildDiagnosisList(List<Map<String, dynamic>> diagnoses) {
    if (diagnoses.isEmpty) return Text('No diagnoses', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline));
    return Column(
      children: diagnoses.map((d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.monitor_heart_outlined, color: AppTheme.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(d['diagnosis'] as String? ?? '', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.errorContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(100)),
              child: Text('Active', style: AppTextStyles.codeSm.copyWith(color: AppTheme.error)),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPrescriptionList(List<Map<String, dynamic>> prescriptions) {
    if (prescriptions.isEmpty) return Text('No prescriptions', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline));
    return Column(
      children: prescriptions.map((rx) {
        final meds = (rx['medicines'] as List<dynamic>? ?? []).map((m) => m.toString()).toList();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meds.join(', '), style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
              if (rx['instructions'] != null) Text(rx['instructions'] as String, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabList(List<Map<String, dynamic>> reports) {
    if (reports.isEmpty) return Text('No lab reports', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline));
    return Column(
      children: reports.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppTheme.tertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Lab Report ${r['id']?.toString().substring(0, 8)}...', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface))),
            if (r['sha256_hash'] != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_outlined, size: 14, color: AppTheme.secondary),
                const SizedBox(width: 4),
                Text('Verified', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
              ]),
          ],
        ),
      )).toList(),
    );
  }

  void _showDiagnosisDialog(String doctorId) {
    final controller = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Diagnosis', style: AppTextStyles.titleLg),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'Diagnosis name')),
            const SizedBox(height: 12),
            TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(hintText: 'Notes (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<DoctorBloc>().add(DoctorCreateDiagnosis(
                  patientId: widget.patientId,
                  doctorId: doctorId,
                  diagnosis: controller.text,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
