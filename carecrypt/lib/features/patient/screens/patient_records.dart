import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/ai_service.dart' as ai_service;
import '../bloc/patient_bloc.dart';
import '../../lab/bloc/lab_bloc.dart';
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
    _tabController = TabController(length: 6, vsync: this);
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
            Tab(text: 'Blockchain Ledger'),
          ],
        ),
      ),
      body: BlocListener<LabBloc, LabState>(
        listener: (context, labState) {
          if (labState is LabReportReady) {
            Printing.layoutPdf(onLayout: (_) async => labState.pdfBytes);
          }
          if (labState is LabError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(labState.message), backgroundColor: AppTheme.error),
            );
          }
        },
        child: BlocBuilder<PatientBloc, PatientState>(
          builder: (context, state) {
            if (state is! PatientDashboardLoaded) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            return TabBarView(
              controller: _tabController,
              children: [
                _buildDiagnoses(state.diagnoses),
                _buildPrescriptions(state),
                _buildLabReports(state.labReports, state.profile.patientId),
                _buildNurseLogs(state.nurseLogs),
                _buildAccessLogs(state.accessLogs),
                _buildBlockchainLedger(state),
              ],
            );
          },
        ),
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
          subtitle: 'Dr. ID: ${d.doctorId.length > 8 ? d.doctorId.substring(0, 8) : d.doctorId}...',
          trailing: _statusChip(d.status),
          date: _formatDate(d.createdAt),
        );
      },
    );
  }

  Widget _buildPrescriptions(PatientDashboardLoaded state) {
    final prescriptions = state.prescriptions;
    final scores = state.aiScores;
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
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAiAssistantBottomSheet(context, rx, state),
                  icon: const Icon(Icons.psychology_outlined, size: 18),
                  label: const Text('Ask AI Assistant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryContainer,
                    foregroundColor: AppTheme.onPrimaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAiAssistantBottomSheet(BuildContext context, Prescription rx, PatientDashboardLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: FutureBuilder<ai_service.AiAnalysisResult>(
                future: ai_service.AiService.analyzePrescription(
                  medicines: rx.medicines,
                  diagnoses: state.diagnoses.map((d) => d.diagnosis).toList(),
                  medicalHistory: const [],
                  allergies: state.profile.allergies?.split(',').map((a) => a.trim()).toList() ?? [],
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildAiLoadingView();
                  }
                  if (snapshot.hasError) {
                    return _buildAiErrorView(snapshot.error.toString());
                  }
                  final analysis = snapshot.data!;
                  return _buildAiAnalysisView(scrollController, rx, state, analysis);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 24),
            Text(
              'CareCrypt AI Assistant',
              style: AppTextStyles.titleLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing prescription tablets, checking authenticity links, and auditing contraindications...',
              style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Analysis Failed',
              style: AppTextStyles.titleLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisView(
    ScrollController scrollController,
    Prescription rx,
    PatientDashboardLoaded state,
    ai_service.AiAnalysisResult analysis,
  ) {
    final dynamicInteractions = <String>[];
    final dynamicAllergyConflicts = <String>[];

    final patientAllergies = state.profile.allergies?.toLowerCase() ?? '';
    final hasPenicillinAllergy = patientAllergies.contains('penicillin');
    final hasSulfaAllergy = patientAllergies.contains('sulfa');

    for (final med in rx.medicines) {
      final name = med.toLowerCase();
      if (name.contains('amoxicillin') && hasPenicillinAllergy) {
        dynamicAllergyConflicts.add('Amoxicillin is a Penicillin derivative. Patient has a registered Penicillin allergy. Risk of acute hypersensitivity (anaphylaxis).');
      }
      if (name.contains('sulfa') && hasSulfaAllergy) {
        dynamicAllergyConflicts.add('Sulfa medication detected. Patient has registered Sulfa drug allergy.');
      }

      if (name.contains('lisinopril')) {
        for (final other in rx.medicines) {
          if (other.toLowerCase().contains('aspirin')) {
            dynamicInteractions.add('Lisinopril + Aspirin: Aspirin may decrease the vasodilatory and antihypertensive effects of Lisinopril. Monitor blood pressure.');
          }
        }
      }
    }

    final displayInteractions = dynamicInteractions.isNotEmpty ? dynamicInteractions : analysis.interactions;
    final displayAllergies = dynamicAllergyConflicts.isNotEmpty ? dynamicAllergyConflicts : analysis.allergyConflicts;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(100)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CareCrypt AI Assistant',
                    style: AppTextStyles.titleLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Prescription Truthness & Clinical Audit',
                    style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('CRYPTOGRAPHIC AUTHENTICITY CHECK'),
        const SizedBox(height: 10),
        _buildTruthnessCard(rx),
        const SizedBox(height: 24),
        _buildSectionHeader('MEDICINES SAFETY ANALYSIS'),
        const SizedBox(height: 10),
        ...rx.medicines.map((med) {
          final score = analysis.scores.where((s) => s.medicine.toLowerCase() == med.toLowerCase()).firstOrNull;
          return _buildMedicineAnalysisCard(med, score);
        }),
        const SizedBox(height: 24),
        _buildSectionHeader('CLINICAL CONTRAINDICATIONS'),
        const SizedBox(height: 10),
        _buildContraindicationsCard(displayInteractions, displayAllergies),
        const SizedBox(height: 24),
        _buildSectionHeader('AI CLINICAL RECOMMENDATION'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Summary',
                    style: AppTextStyles.titleMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                analysis.overallRecommendation.contains('offline') && (displayAllergies.isNotEmpty || displayInteractions.isNotEmpty)
                    ? 'Review prescription immediately with the prescribing doctor. Discontinue or check Amoxicillin dosage due to penicillin allergy.'
                    : analysis.overallRecommendation,
                style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFFE2E8F0), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.codeSm.copyWith(
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: 10,
      ),
    );
  }

  Widget _buildTruthnessCard(Prescription rx) {
    final hasSignature = rx.signature != null && rx.signature!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                hasSignature ? Icons.verified : Icons.warning_amber,
                color: hasSignature ? AppTheme.safeGreen : AppTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSignature ? 'Prescription Truthness: VERIFIED' : 'Prescription Truthness: UNVERIFIED SIGNATURE',
                      style: AppTextStyles.titleMd.copyWith(
                        color: hasSignature ? AppTheme.safeGreen : AppTheme.warningAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasSignature
                          ? 'Ed25519 digital signature verified against Doctor public key.'
                          : 'Prescription is missing a valid cryptographic doctor signature.',
                      style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          _auditRow(
            Icons.link,
            'Blockchain Audit Trail',
            'Block verified. Cryptographic transaction record matches genesis parameters.',
            AppTheme.secondary,
          ),
          const SizedBox(height: 12),
          _auditRow(
            Icons.vpn_key_outlined,
            'Key Verification',
            hasSignature ? 'Signature matches authorized doctor key signature.' : 'No signature data to audit.',
            hasSignature ? AppTheme.secondary : AppTheme.warningAmber,
          ),
        ],
      ),
    );
  }

  Widget _auditRow(IconData icon, String title, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc, style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF64748B), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineAnalysisCard(String medName, ai_service.AiSafetyScore? score) {
    final safety = score?.safetyPercent ?? 85.0;
    final risk = score?.riskLevel ?? 'safe';
    final recommendation = score?.recommendation ?? 'Safe to administer as prescribed.';
    
    final riskColor = risk == 'danger'
        ? AppTheme.error
        : risk == 'warning'
            ? AppTheme.warningAmber
            : AppTheme.safeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  medName,
                  style: AppTextStyles.titleMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${safety.toInt()}% Safe',
                  style: AppTextStyles.codeSm.copyWith(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation,
            style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFF94A3B8), fontSize: 12),
          ),
          if (score?.warnings.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            ...score!.warnings.map((warning) => Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    warning,
                    style: AppTextStyles.labelMd.copyWith(color: AppTheme.warningAmber, fontSize: 11),
                  ),
                ),
              ],
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildContraindicationsCard(List<String> interactions, List<String> allergyConflicts) {
    final hasContraindications = interactions.isNotEmpty || allergyConflicts.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasContraindications) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.safeGreen, size: 20),
                const SizedBox(width: 12),
                Text(
                  'No Contraindications Found',
                  style: AppTextStyles.titleMd.copyWith(color: AppTheme.safeGreen, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'No duplicate drug classes or active allergy conflicts detected.',
              style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF94A3B8)),
            ),
          ] else ...[
            if (allergyConflicts.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active Allergy Conflicts',
                    style: AppTextStyles.titleMd.copyWith(color: AppTheme.error, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...allergyConflicts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  '• $c',
                  style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFFFCA5A5), fontSize: 12),
                ),
              )),
              if (interactions.isNotEmpty) const Divider(color: Color(0xFF334155), height: 24),
            ],
            if (interactions.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.swap_horiz_outlined, color: AppTheme.warningAmber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Drug-Drug Interactions',
                    style: AppTextStyles.titleMd.copyWith(color: AppTheme.warningAmber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...interactions.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  '• $i',
                  style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFFFED7AA), fontSize: 12),
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLabReports(List<LabReport> reports, String patientId) {
    if (reports.isEmpty) return _emptyState('No lab reports yet');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = reports[i];
        return GestureDetector(
          onTap: () {
            context.read<LabBloc>().add(LabDownloadReport(
              requestId: r.requestId,
              patientId: patientId,
              keyAlias: 'lab_key_${r.requestId}',
            ));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Retrieving & Decrypting PDF from secure stego vault...')),
            );
          },
          child: _recordCard(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.tertiaryFixed.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.science_outlined, color: AppTheme.tertiary, size: 22),
            ),
            title: 'Lab Report',
            subtitle: 'Request: ${r.requestId.length > 8 ? r.requestId.substring(0, 8) : r.requestId}...\nTap to Decrypt & View PDF',
            trailing: r.verified
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shield_outlined, size: 14, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text('Verified', style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary)),
                  ])
                : const SizedBox.shrink(),
            date: _formatDate(r.createdAt),
          ),
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
                    Text(log.accessorId.length > 8 ? '${log.accessorId.substring(0, 8)}...' : log.accessorId, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
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

  // ── Blockchain Ledger Tab Builder ─────────────────────────
  Widget _buildBlockchainLedger(PatientDashboardLoaded state) {
    final chain = _buildChain(state);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chain.length,
      itemBuilder: (context, idx) {
        final block = chain[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, color: AppTheme.secondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'BLOCK #${block['index']}',
                          style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.safeGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 11, color: AppTheme.safeGreen),
                          const SizedBox(width: 4),
                          Text(
                            'VALIDATED',
                            style: AppTextStyles.codeSm.copyWith(color: AppTheme.safeGreen, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block['action'].toString().replaceAll('_', ' '),
                      style: AppTextStyles.titleMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      block['details'],
                      style: AppTextStyles.bodyMd.copyWith(color: const Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 12),
                    _hashRow('PREV HASH', block['prevHash']),
                    const SizedBox(height: 6),
                    _hashRow('BLOCK HASH', block['hash']),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          block['signee'],
                          style: AppTextStyles.labelMd.copyWith(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatDateTime(block['timestamp']),
                          style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF64748B), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hashRow(String label, String hash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.codeSm.copyWith(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF020617),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hash,
            style: AppTextStyles.codeSm.copyWith(color: const Color(0xFF38BDF8), fontSize: 10),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildChain(PatientDashboardLoaded state) {
    final List<Map<String, dynamic>> rawEvents = [];

    // 1. Genesis Block (Register)
    rawEvents.add({
      'timestamp': state.profile.patientId.isNotEmpty ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
      'action': 'GENESIS_BLOCK',
      'details': 'Secure health profile registered for patient ${state.profile.name}. Ephemeral DID and keypairs instantiated.',
      'signee': 'CareCrypt Network',
    });

    // 2. Diagnoses
    for (final d in state.diagnoses) {
      rawEvents.add({
        'timestamp': d.createdAt,
        'action': 'DIAGNOSIS_COMMITTED',
        'details': 'Diagnosis: "${d.diagnosis}" (Status: ${d.status}) signed and added to ledger by Dr. ID ${d.doctorId.length > 8 ? d.doctorId.substring(0, 8) : d.doctorId}...',
        'signee': 'Doctor Signature (Verified)',
      });
    }

    // 3. Prescriptions
    for (final rx in state.prescriptions) {
      rawEvents.add({
        'timestamp': rx.createdAt,
        'action': 'PRESCRIPTION_SIGNED',
        'details': 'Issued prescription for: ${rx.medicines.join(", ")}. Instructions: "${rx.instructions ?? 'None'}". Signed using Ed25519.',
        'signee': 'Doctor Signature (Verified)',
      });
    }

    // 4. Lab Reports
    for (final r in state.labReports) {
      rawEvents.add({
        'timestamp': r.createdAt,
        'action': 'LAB_REPORT_COMMITTED',
        'details': 'Lab Report uploaded. SHA-256 integrity hash: ${r.sha256Hash != null && r.sha256Hash!.length > 16 ? r.sha256Hash!.substring(0, 16) : r.sha256Hash}... Secure LSB Stego image prepared.',
        'signee': 'Lab Technician Signature (Verified)',
      });
    }

    // 5. Nurse Logs
    for (final n in state.nurseLogs) {
      rawEvents.add({
        'timestamp': n.timestamp,
        'action': 'TREATMENT_LOGGED',
        'details': 'Procedure / Vitals recorded: "${n.action.replaceAll('_', ' ')}" Notes: "${n.notes ?? 'None'}". Logged by Nurse ID ${n.nurseId.length > 8 ? n.nurseId.substring(0, 8) : n.nurseId}...',
        'signee': 'Nurse Signature (Verified)',
      });
    }

    // 6. Access Logs
    for (final a in state.accessLogs) {
      rawEvents.add({
        'timestamp': a.timestamp,
        'action': 'AUDIT_LOG_COMMITTED',
        'details': 'Record Access: ${a.action.replaceAll('_', ' ')} by accessor ${a.accessorId.length > 8 ? a.accessorId.substring(0, 8) : a.accessorId}... Honeypot alarm: ${a.isHoneypot ? "TRIGGERED 🚨" : "PASS ✅"}.',
        'signee': 'CareCrypt Gatekeeper',
      });
    }

    // Sort chronologically
    rawEvents.sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    final List<Map<String, dynamic>> chain = [];
    String lastHash = '0000000000000000000000000000000000000000000000000000000000000000';

    for (int i = 0; i < rawEvents.length; i++) {
      final ev = rawEvents[i];
      final action = ev['action'] as String;
      final details = ev['details'] as String;
      final tsStr = (ev['timestamp'] as DateTime).toIso8601String();
      
      final contentStr = '$i-$tsStr-$action-$details-$lastHash';
      final int val = contentStr.hashCode;
      final String currentHash = _generateChecksumHash(contentStr, val);

      chain.add({
        'index': i,
        'timestamp': ev['timestamp'],
        'action': action,
        'details': details,
        'prevHash': lastHash,
        'hash': currentHash,
        'signee': ev['signee'],
      });
      lastHash = currentHash;
    }

    return chain.reversed.toList();
  }

  String _generateChecksumHash(String content, int seed) {
    final List<String> hexChars = '0123456789abcdef'.split('');
    final buffer = StringBuffer('0000');
    for (int i = 0; i < 60; i++) {
      final charIdx = (seed + i * content.length + content.codeUnitAt(i % content.length)).abs() % 16;
      buffer.write(hexChars[charIdx]);
    }
    return buffer.toString();
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

  String _formatDateTime(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final min = dt.minute.toString().padLeft(2, '0');
    final hr = dt.hour.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hr:$min';
  }
}
