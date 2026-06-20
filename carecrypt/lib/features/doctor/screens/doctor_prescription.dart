import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/doctor_bloc.dart';
import '../../../core/services/ai_service.dart';
import '../../../shared/widgets/cc_safety_score_chip.dart';

class DoctorPrescriptionScreen extends StatefulWidget {
  final String patientId;
  const DoctorPrescriptionScreen({super.key, required this.patientId});

  @override
  State<DoctorPrescriptionScreen> createState() => _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final List<String> _medicines = [];
  final _medController = TextEditingController();
  final _instructionsController = TextEditingController();
  AiAnalysisResult? _aiResult;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('New Prescription', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      ),
      body: BlocListener<DoctorBloc, DoctorState>(
        listener: (context, state) {
          if (state is DoctorActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary));
            context.pop();
          }
          if (state is DoctorAiAnalysisResult) {
            setState(() => _aiResult = state.result);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Add medicine
            Text('Medicines', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _medController,
                    decoration: const InputDecoration(hintText: 'e.g. Paracetamol 500mg'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_medController.text.isNotEmpty) {
                      setState(() { _medicines.add(_medController.text.trim()); _medController.clear(); });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.add, color: AppTheme.onPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Medicines list
            ..._medicines.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, size: 18, color: AppTheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface))),
                  if (_aiResult != null) ...[
                    Builder(builder: (_) {
                      final score = _aiResult!.scores.where((s) => s.medicine.toLowerCase() == e.value.toLowerCase()).firstOrNull;
                      if (score != null) return CcSafetyScoreChip(score: score);
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => setState(() => _medicines.removeAt(e.key)),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.outline),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            // AI Analysis button
            if (_medicines.isNotEmpty) ...[
              BlocBuilder<DoctorBloc, DoctorState>(
                builder: (_, state) => OutlinedButton.icon(
                  onPressed: state is DoctorLoading ? null : () {
                    context.read<DoctorBloc>().add(DoctorAnalyzePrescription(
                      medicines: _medicines,
                      diagnoses: [],
                      history: [],
                    ));
                  },
                  icon: const Icon(Icons.psychology_outlined, size: 18),
                  label: Text(state is DoctorLoading ? 'Analyzing...' : 'Run AI Safety Analysis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // AI Results
            if (_aiResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryFixed),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.psychology_outlined, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Llama 3 Safety Analysis', style: AppTextStyles.titleMd.copyWith(color: AppTheme.primary)),
                    ]),
                    const SizedBox(height: 12),
                    if (_aiResult!.interactions.isNotEmpty) ...[
                      Text('⚠️ Interactions:', style: AppTextStyles.labelMd.copyWith(color: AppTheme.error)),
                      ..._aiResult!.interactions.map((i) => Text('• $i', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface))),
                      const SizedBox(height: 8),
                    ],
                    Text(_aiResult!.overallRecommendation, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Instructions
            Text('Instructions', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Dosage, frequency, special instructions...'),
            ),
            const SizedBox(height: 32),
            // Submit
            BlocBuilder<DoctorBloc, DoctorState>(
              builder: (_, state) => ElevatedButton.icon(
                onPressed: (_medicines.isEmpty || state is DoctorLoading) ? null : () {
                  context.read<DoctorBloc>().add(DoctorCreatePrescription(
                    patientId: widget.patientId,
                    doctorId: auth.user.id,
                    medicines: _medicines,
                    instructions: _instructionsController.text.isEmpty ? null : _instructionsController.text,
                    privateKeyBase64: '',
                  ));
                },
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text('Issue Prescription', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
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
    );
  }
}
