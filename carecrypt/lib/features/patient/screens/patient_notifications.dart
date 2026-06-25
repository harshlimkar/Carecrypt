import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<AppNotification>? _cachedNotifications;

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
      body: BlocListener<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.secondary),
            );
            final auth = context.read<AuthBloc>().state;
            if (auth is AuthAuthenticated) {
              context.read<PatientBloc>().add(PatientLoadNotifications(userId: auth.user.id));
            }
          }
          if (state is PatientError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.error),
            );
            final auth = context.read<AuthBloc>().state;
            if (auth is AuthAuthenticated) {
              context.read<PatientBloc>().add(PatientLoadNotifications(userId: auth.user.id));
            }
          }
        },
        child: BlocBuilder<PatientBloc, PatientState>(
          builder: (context, state) {
            if (state is PatientNotificationsLoaded) {
              _cachedNotifications = state.notifications;
            }

            final isLoading = state is PatientLoading || state is PatientActionSuccess;

            if (_cachedNotifications == null) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              return const Center(child: Text('No notifications'));
            }

            return Stack(
              children: [
                _buildNotificationList(_cachedNotifications!),
                if (isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.15),
                    child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
              ],
            );
          },
        ),
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
    final testType = notification.metadata?['test_type'] as String?;

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
                    if (testType != null)
                      Text('Test: $testType', style: AppTextStyles.labelMd.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    Text(notification.message, style: AppTextStyles.bodyMd.copyWith(color: AppTheme.outline), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Approve to allow the lab to process your sample. This grants read-only access to your test result.',
            style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final authState = context.read<AuthBloc>().state;
                    final currentPatientId = patientId.isNotEmpty
                        ? patientId
                        : (authState is AuthAuthenticated ? (authState.user.patientId ?? '') : '');
                    
                    String? targetRequestId = requestId;
                    if (targetRequestId == null || targetRequestId.isEmpty || targetRequestId == 'placeholder') {
                      try {
                        final supabase = Supabase.instance.client;
                        var query = supabase
                            .from('lab_requests')
                            .select('id')
                            .eq('patient_id', currentPatientId)
                            .eq('status', 'pending');
                        if (testType != null) {
                          query = query.eq('test_type', testType);
                        }
                        final pending = await query
                            .order('created_at', ascending: false)
                            .limit(1)
                            .maybeSingle();
                        if (pending != null) {
                          targetRequestId = pending['id'] as String?;
                        } else {
                          final fallbackPending = await supabase
                              .from('lab_requests')
                              .select('id')
                              .eq('patient_id', currentPatientId)
                              .eq('status', 'pending')
                              .order('created_at', ascending: false)
                              .limit(1)
                              .maybeSingle();
                          if (fallbackPending != null) {
                            targetRequestId = fallbackPending['id'] as String?;
                          }
                        }
                      } catch (_) {}
                    }
                    
                    if (targetRequestId != null && targetRequestId.isNotEmpty && targetRequestId != 'placeholder') {
                      try {
                        final supabase = Supabase.instance.client;
                        await supabase
                            .from('notifications')
                            .update({'read': true})
                            .eq('id', notification.id);
                      } catch (_) {}
                      if (!mounted) return;
                      context.read<PatientBloc>().add(PatientRejectLabRequest(requestId: targetRequestId));
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: No pending request found to reject.'), backgroundColor: AppTheme.error),
                      );
                    }
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
                  onPressed: () async {
                    final authState = context.read<AuthBloc>().state;
                    final currentPatientId = patientId.isNotEmpty
                        ? patientId
                        : (authState is AuthAuthenticated ? (authState.user.patientId ?? '') : '');
                    
                    String? targetRequestId = requestId;
                    if (targetRequestId == null || targetRequestId.isEmpty || targetRequestId == 'placeholder') {
                      try {
                        final supabase = Supabase.instance.client;
                        var query = supabase
                            .from('lab_requests')
                            .select('id')
                            .eq('patient_id', currentPatientId)
                            .eq('status', 'pending');
                        if (testType != null) {
                          query = query.eq('test_type', testType);
                        }
                        final pending = await query
                            .order('created_at', ascending: false)
                            .limit(1)
                            .maybeSingle();
                        if (pending != null) {
                          targetRequestId = pending['id'] as String?;
                        } else {
                          final fallbackPending = await supabase
                              .from('lab_requests')
                              .select('id')
                              .eq('patient_id', currentPatientId)
                              .eq('status', 'pending')
                              .order('created_at', ascending: false)
                              .limit(1)
                              .maybeSingle();
                          if (fallbackPending != null) {
                            targetRequestId = fallbackPending['id'] as String?;
                          }
                        }
                      } catch (_) {}
                    }
                    
                    if (targetRequestId != null && targetRequestId.isNotEmpty && targetRequestId != 'placeholder') {
                      try {
                        final supabase = Supabase.instance.client;
                        await supabase
                            .from('notifications')
                            .update({'read': true})
                            .eq('id', notification.id);
                      } catch (_) {}
                      if (!mounted) return;
                      context.read<PatientBloc>().add(PatientApproveLabRequest(
                        requestId: targetRequestId,
                        patientId: currentPatientId,
                      ));
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: No pending request found to approve.'), backgroundColor: AppTheme.error),
                      );
                    }
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
