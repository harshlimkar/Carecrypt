import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/lab_bloc.dart';

class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key});
  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    context.read<LabBloc>().add(LabLoadDashboard(labId: auth.user.id));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocConsumer<LabBloc, LabState>(
        listener: (context, state) {
          if (state is LabReportReady) {
            // Open the decrypted PDF in a print/share viewer
            Printing.layoutPdf(onLayout: (_) async => state.pdfBytes);
          }
          if (state is LabError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────
              _buildSliverAppBar(auth, state),
              // ── Content ──────────────────────────
              SliverFillRemaining(
                child: state is LabLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : state is LabError
                        ? _buildError(state.message)
                        : state is LabDashboardLoaded
                            ? _buildDashboardContent(state)
                            : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(AuthAuthenticated auth, LabState state) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lab Portal', style: AppTextStyles.titleLg.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
          Text(auth.user.displayName, style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () { context.read<AuthBloc>().add(AuthLogoutRequested()); context.go(AppRoutes.login); },
          icon: const Icon(Icons.logout_outlined, color: AppTheme.outline),
          tooltip: 'Logout',
        ),
      ],
      bottom: state is LabDashboardLoaded ? _buildTabBar(state) : null,
    );
  }

  PreferredSizeWidget _buildTabBar(LabDashboardLoaded state) {
    return TabBar(
      controller: _tabController,
      labelColor: AppTheme.primary,
      unselectedLabelColor: AppTheme.outline,
      indicatorColor: AppTheme.primaryContainer,
      indicatorWeight: 3,
      labelStyle: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w600),
      tabs: [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Awaiting'),
              if (state.pendingApprovalRequests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppTheme.outline, shape: BoxShape.circle),
                  child: Text('${state.pendingApprovalRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Action'),
              if (state.approvedRequests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                  child: Text('${state.approvedRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Done'),
              if (state.completedRequests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
                  child: Text('${state.completedRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent(LabDashboardLoaded state) {
    return Column(
      children: [
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _statChip('${state.pendingApprovalRequests.length}', 'Awaiting Approval', AppTheme.outline, Icons.hourglass_empty_outlined),
              const SizedBox(width: 10),
              _statChip('${state.approvedRequests.length}', 'Ready to Process', AppTheme.error, Icons.pending_outlined),
              const SizedBox(width: 10),
              _statChip('${state.completedRequests.length}', 'Completed', AppTheme.secondary, Icons.check_circle_outline),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingApprovalTab(state.pendingApprovalRequests),
              _buildActionableTab(state.approvedRequests),
              _buildCompletedTab(state.completedRequests),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(String count, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(count, style: AppTextStyles.titleLg.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(label, style: AppTextStyles.labelMd.copyWith(color: color, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalTab(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.hourglass_empty_outlined,
        title: 'No Pending Approvals',
        subtitle: 'All lab requests have been actioned by patients.',
        color: AppTheme.outline,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, i) => _requestCard(requests[i], status: RequestCardStatus.awaitingApproval),
    );
  }

  Widget _buildActionableTab(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Tests to Process',
        subtitle: 'Tests approved by patients will appear here.',
        color: AppTheme.secondary,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, i) => _requestCard(requests[i], status: RequestCardStatus.approved),
    );
  }

  Widget _buildCompletedTab(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.science_outlined,
        title: 'No Completed Tests',
        subtitle: 'Reports you upload will appear here.',
        color: AppTheme.secondary,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, i) => _requestCard(requests[i], status: RequestCardStatus.completed),
    );
  }

  Widget _requestCard(Map<String, dynamic> req, {required RequestCardStatus status}) {
    // Safely extract patient info (lab sees only patient ID and name, not full record)
    String patientId = 'Unknown';
    String patientName = 'Unknown';
    final patients = req['patients'];
    if (patients is Map<String, dynamic>) {
      patientId = patients['patient_id'] as String? ?? 'Unknown';
      patientName = patients['name'] as String? ?? 'Unknown';
    } else if (patients is List && patients.isNotEmpty) {
      final p = patients.first as Map<String, dynamic>?;
      patientId = p?['patient_id'] as String? ?? 'Unknown';
      patientName = p?['name'] as String? ?? 'Unknown';
    }

    final testType = req['test_type'] as String? ?? 'Unknown Test';
    final urgency = req['urgency'] as String? ?? 'normal';
    final createdAt = req['created_at'] != null
        ? DateTime.tryParse(req['created_at'] as String)
        : null;

    final (borderColor, iconColor, statusLabel, statusBg) = switch (status) {
      RequestCardStatus.awaitingApproval => (AppTheme.outline.withValues(alpha: 0.3), AppTheme.outline, 'Awaiting Patient Approval', AppTheme.surfaceContainerLow),
      RequestCardStatus.approved => (AppTheme.error.withValues(alpha: 0.4), AppTheme.error, 'Ready to Process', AppTheme.errorContainer.withValues(alpha: 0.3)),
      RequestCardStatus.completed => (AppTheme.secondary.withValues(alpha: 0.3), AppTheme.secondary, 'Completed', AppTheme.secondaryContainer.withValues(alpha: 0.2)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.biotech_outlined, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(testType, style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                      const SizedBox(height: 4),
                      // Lab sees only Patient ID + Name (restricted view)
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: AppTheme.outline),
                          const SizedBox(width: 4),
                          Text('$patientId • $patientName', style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.outline),
                            const SizedBox(width: 4),
                            Text(
                              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                              style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(100)),
                            child: Text(statusLabel, style: AppTextStyles.codeSm.copyWith(color: iconColor, fontSize: 10)),
                          ),
                          if (urgency == 'urgent' || urgency == 'stat') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.errorContainer, borderRadius: BorderRadius.circular(100)),
                              child: Text(urgency.toUpperCase(), style: AppTextStyles.codeSm.copyWith(color: AppTheme.error, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (status == RequestCardStatus.approved)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: ListTile(
                leading: const Icon(Icons.upload_file_outlined, color: AppTheme.primaryContainer, size: 20),
                title: Text('Upload Report', style: AppTextStyles.titleMd.copyWith(color: AppTheme.primaryContainer)),
                subtitle: Text('Encrypt, hash & steganograph', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryContainer),
                onTap: () => context.push('${AppRoutes.labUploadReport}?requestId=${req['id']}&patientId=$patientId'),
              ),
            ),
          if (status == RequestCardStatus.completed)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.secondaryContainer.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.secondary, size: 20),
                title: Text('View Report', style: AppTextStyles.titleMd.copyWith(color: AppTheme.secondary)),
                subtitle: Text('Decrypt & open PDF', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.secondary),
                onTap: () {
                  context.read<LabBloc>().add(LabDownloadReport(
                    requestId: req['id'] as String? ?? '',
                    patientId: patientId,
                    keyAlias: 'lab_report_${req['id']}',
                  ));
                },

              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final auth = context.read<AuthBloc>().state as AuthAuthenticated;
                context.read<LabBloc>().add(LabLoadDashboard(labId: auth.user.id));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

enum RequestCardStatus { awaitingApproval, approved, completed }

// ─────────────────────────────────────────────────────────
// Lab Upload Report Screen (Structured Form)
// ─────────────────────────────────────────────────────────

class LabUploadReportScreen extends StatefulWidget {
  final String requestId;
  final String patientId;
  const LabUploadReportScreen({super.key, required this.requestId, this.patientId = ''});
  @override
  State<LabUploadReportScreen> createState() => _LabUploadReportScreenState();
}

class _LabUploadReportScreenState extends State<LabUploadReportScreen> {
  Uint8List? _reportBytes;
  String? _reportName;
  final _resultController = TextEditingController();
  final _observationController = TextEditingController();
  final _remarksController = TextEditingController();
  ReportDraftStatus _draftStatus = ReportDraftStatus.draft;

  @override
  void dispose() {
    _resultController.dispose();
    _observationController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickReport() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() { _reportBytes = bytes; _reportName = file.name; });
    }
  }

  bool get _canUpload =>
      _resultController.text.trim().isNotEmpty &&
      _observationController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Upload Lab Report', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
        elevation: 0,
      ),
      body: BlocConsumer<LabBloc, LabState>(
        listener: (context, state) {
          if (state is LabReportUploaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary),
            );
            context.pop();
          }
          if (state is LabReportUploading) {
            setState(() {
              _draftStatus = switch (state.reportStatus) {
                ReportUploadStatus.draft => ReportDraftStatus.draft,
                ReportUploadStatus.encrypted => ReportDraftStatus.encrypted,
                ReportUploadStatus.uploaded => ReportDraftStatus.uploaded,
              };
            });
          }
          if (state is LabError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
            );
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Report Status Indicator
            _buildReportStatusChips(),
            const SizedBox(height: 20),
            // Security pipeline
            _buildPipeline(state),
            const SizedBox(height: 24),
            // Structured Form Fields
            Text('Report Details', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 12),
            _buildFormField(
              controller: _resultController,
              label: 'Test Result *',
              hint: 'e.g., HbA1c: 6.2%, Normal range',
              icon: Icons.assignment_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildFormField(
              controller: _observationController,
              label: 'Observation *',
              hint: 'Clinical observations and findings',
              icon: Icons.visibility_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _buildFormField(
              controller: _remarksController,
              label: 'Remarks (Optional)',
              hint: 'Additional notes or recommendations',
              icon: Icons.note_alt_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Optional: attach report image
            Text('Attach Report Image (Optional)', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
            const SizedBox(height: 12),
            _buildFilePicker('Report Image / Scan', _reportName, _pickReport, Icons.description_outlined),
            const SizedBox(height: 12),
            // Auto-stego info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cover image auto-generated locally — no upload needed. Data hidden with LSB steganography.',
                      style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onPrimaryFixedVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Upload button
            ElevatedButton.icon(
              onPressed: (!_canUpload || state is LabReportUploading) ? null : () {
                context.read<LabBloc>().add(LabUploadReport(
                  requestId: widget.requestId,
                  patientId: widget.patientId,
                  labId: auth.user.id,
                  reportBytes: _reportBytes ?? Uint8List(0),
                  encryptionKeyAlias: 'lab_key_${widget.requestId}',
                  testResult: _resultController.text.trim(),
                  observation: _observationController.text.trim(),
                  remarks: _remarksController.text.trim(),
                ));
              },
              icon: state is LabReportUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.security_outlined, size: 18),
              label: Text(
                state is LabReportUploading ? state.step : 'Encrypt & Upload Securely',
                style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryContainer,
                disabledBackgroundColor: AppTheme.outline.withValues(alpha: 0.3),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStatusChips() {
    return Row(
      children: ReportDraftStatus.values.map((s) {
        final isActive = s == _draftStatus;
        final isPast = s.index < _draftStatus.index;
        final (label, color, icon) = switch (s) {
          ReportDraftStatus.draft => ('Draft', AppTheme.outline, Icons.edit_note_outlined),
          ReportDraftStatus.encrypted => ('Encrypted', AppTheme.primary, Icons.lock_outlined),
          ReportDraftStatus.uploaded => ('Uploaded', AppTheme.secondary, Icons.cloud_done_outlined),
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s != ReportDraftStatus.uploaded ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: (isActive || isPast) ? color.withValues(alpha: 0.12) : AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isActive || isPast) ? color.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(isPast ? Icons.check_circle : icon, color: (isActive || isPast) ? color : AppTheme.outline, size: 18),
                  const SizedBox(height: 4),
                  Text(label, style: AppTextStyles.labelMd.copyWith(
                    color: (isActive || isPast) ? color : AppTheme.outline,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppTheme.outline),
          ),
        ),
      ],
    );
  }

  Widget _buildPipeline(LabState state) {
    final steps = ['AES-256-GCM Encrypt', 'SHA-256 Hash', 'Steganography', 'Supabase Upload', 'Notify Patient'];
    int activeStep = 0;
    if (state is LabReportUploading) {
      final step = state.step;
      if (step.contains('SHA')) { activeStep = 1; }
      else if (step.contains('steg') || step.contains('Steg')) { activeStep = 2; }
      else if (step.contains('Upload') || step.contains('upload')) { activeStep = 3; }
      else if (step.contains('Saving') || step.contains('Notif')) { activeStep = 4; }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Security Pipeline', style: AppTextStyles.labelMd.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: e.key < activeStep
                        ? AppTheme.secondary
                        : e.key == activeStep
                            ? AppTheme.primaryContainer
                            : AppTheme.outlineVariant.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: e.key < activeStep
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : e.key == activeStep
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            )
                          : Center(
                              child: Text('${e.key + 1}', style: TextStyle(
                                color: e.key == activeStep ? Colors.white : AppTheme.outline,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                            ),
                ),
                const SizedBox(width: 10),
                Text(e.value, style: AppTextStyles.bodyMd.copyWith(
                  color: e.key <= activeStep ? AppTheme.onSurface : AppTheme.outline,
                  fontWeight: e.key == activeStep ? FontWeight.w600 : FontWeight.w400,
                )),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFilePicker(String label, String? selected, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected != null ? AppTheme.secondaryContainer.withValues(alpha: 0.15) : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected != null ? AppTheme.secondary.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(selected != null ? Icons.check_circle_outline : icon,
                color: selected != null ? AppTheme.secondary : AppTheme.outline, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant)),
                Text(selected ?? 'Tap to select file',
                    style: AppTextStyles.bodyMd.copyWith(color: selected != null ? AppTheme.onSurface : AppTheme.outline)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }
}

enum ReportDraftStatus { draft, encrypted, uploaded }
