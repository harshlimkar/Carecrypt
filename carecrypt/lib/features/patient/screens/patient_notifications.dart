import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../bloc/patient_bloc.dart';
import '../models/patient_models.dart';

class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<PatientBloc>().add(PatientLoadNotifications(userId: auth.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Notifications', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      ),
      body: BlocBuilder<PatientBloc, PatientState>(
        builder: (context, state) {
          if (state is PatientLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (state is PatientNotificationsLoaded) {
            return _buildNotificationList(state.notifications);
          }
          return const Center(child: Text('No notifications'));
        },
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    // Separate lab requests that need action
    final pendingRequests = notifications.where((n) => n.type == 'lab_request' && !n.read).toList();
    final others = notifications.where((n) => n.type != 'lab_request' || n.read).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Action Required', style: AppTextStyles.titleMd.copyWith(color: AppTheme.error)),
          ),
          ...pendingRequests.map((n) => _buildLabRequestCard(n)),
          const SizedBox(height: 20),
          Text('All Notifications', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 12),
        ],
        ...others.map((n) => _buildNotificationItem(n)),
      ],
    );
  }

  Widget _buildLabRequestCard(AppNotification notification) {
    final requestId = notification.metadata?['request_id'] as String?;
    final patientId = notification.metadata?['patient_id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppTheme.error.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.biotech_outlined, color: AppTheme.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lab Test Request', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                    Text(notification.message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: requestId == null ? null : () {
                    context.read<PatientBloc>().add(PatientRejectLabRequest(requestId: requestId));
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: requestId == null ? null : () {
                    context.read<PatientBloc>().add(PatientApproveLabRequest(
                      requestId: requestId,
                      patientId: patientId,
                    ));
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    final (icon, color) = _getNotificationStyle(notification.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: notification.read ? AppTheme.surfaceContainerLowest : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface)),
                Text(_formatTime(notification.createdAt), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
              ],
            ),
          ),
          if (!notification.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _getNotificationStyle(String type) => switch (type) {
    'lab_request' => (Icons.biotech_outlined, AppTheme.error),
    'lab_approved' => (Icons.check_circle_outline, AppTheme.secondary),
    'report_uploaded' => (Icons.description_outlined, AppTheme.primary),
    'prescription_generated' => (Icons.medication_outlined, AppTheme.secondary),
    'medicine_dispensed' => (Icons.local_pharmacy_outlined, AppTheme.secondary),
    'treatment_updated' => (Icons.medical_information_outlined, AppTheme.primary),
    'diagnosis_updated' => (Icons.monitor_heart_outlined, AppTheme.error),
    'security_alert' => (Icons.warning_amber_rounded, AppTheme.error),
    _ => (Icons.notifications_outlined, AppTheme.primary),
  };

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
