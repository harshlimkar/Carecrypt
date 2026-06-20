import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/doctor_bloc.dart';

class DoctorLabRequestScreen extends StatefulWidget {
  final String patientId;
  const DoctorLabRequestScreen({super.key, required this.patientId});

  @override
  State<DoctorLabRequestScreen> createState() => _DoctorLabRequestScreenState();
}

class _DoctorLabRequestScreenState extends State<DoctorLabRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String _selectedTest = 'Blood Panel';
  String _urgency = 'normal';

  final List<String> _testTypes = [
    'Blood Panel', 'CBC', 'Urine Analysis', 'X-Ray', 'MRI',
    'ECG', 'Thyroid Panel', 'Liver Function', 'Kidney Function', 'HbA1c',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Create Lab Request', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      ),
      body: BlocListener<DoctorBloc, DoctorState>(
        listener: (context, state) {
          if (state is DoctorActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary));
            context.pop();
          }
          if (state is DoctorError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.error));
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Workflow info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryFixed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.info_outline, color: AppTheme.primary, size: 16), const SizedBox(width: 8), Text('Lab Request Workflow', style: AppTextStyles.titleMd.copyWith(color: AppTheme.primary))]),
                    const SizedBox(height: 8),
                    ...['Patient receives notification', 'Patient approves request', 'Lab technician performs test', 'Encrypted report delivered'].map((s) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [const Icon(Icons.arrow_right, color: AppTheme.outline, size: 16), Text(s, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant))]),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Patient ID
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.person_outlined, color: AppTheme.outline, size: 18),
                  const SizedBox(width: 10),
                  Text('Patient: ${widget.patientId}', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                ]),
              ),
              const SizedBox(height: 16),
              // Test type
              Text('Test Type', style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTest,
                    isExpanded: true,
                    items: _testTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedTest = v); },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Urgency
              Text('Urgency', style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _urgencyOption('normal', 'Normal', AppTheme.secondary)),
                  const SizedBox(width: 10),
                  Expanded(child: _urgencyOption('urgent', 'Urgent', AppTheme.warningAmber)),
                  const SizedBox(width: 10),
                  Expanded(child: _urgencyOption('stat', 'STAT', AppTheme.error)),
                ],
              ),
              const SizedBox(height: 16),
              // Notes
              Text('Clinical Notes', style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Additional instructions or context...'),
              ),
              const SizedBox(height: 32),
              // Submit
              BlocBuilder<DoctorBloc, DoctorState>(
                builder: (_, state) => ElevatedButton.icon(
                  onPressed: state is DoctorLoading ? null : () {
                    context.read<DoctorBloc>().add(DoctorCreateLabRequest(
                      patientId: widget.patientId,
                      doctorId: auth.user.id,
                      testType: _selectedTest,
                      notes: _notesController.text.isEmpty ? null : _notesController.text,
                      urgency: _urgency,
                    ));
                  },
                  icon: state is DoctorLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text('Send Lab Request', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urgencyOption(String value, String label, Color color) {
    final isSelected = _urgency == value;
    return GestureDetector(
      onTap: () => setState(() => _urgency = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Center(child: Text(label, style: AppTextStyles.titleMd.copyWith(color: isSelected ? color : AppTheme.outline))),
      ),
    );
  }
}
