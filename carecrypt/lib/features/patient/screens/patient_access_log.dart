import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/patient_bloc.dart';

class PatientAccessLogScreen extends StatelessWidget {
  const PatientAccessLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
        title: Text('Access Log', style: AppTextStyles.titleLg.copyWith(color: AppTheme.onSurface)),
      ),
      body: BlocBuilder<PatientBloc, PatientState>(
        builder: (context, state) {
          if (state is! PatientDashboardLoaded) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          final logs = state.accessLogs;
          final honeypotLogs = logs.where((l) => l.isHoneypot).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (honeypotLogs.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '⚠️ ${honeypotLogs.length} suspicious access attempt${honeypotLogs.length > 1 ? 's' : ''} detected. Security team notified.',
                          style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('${logs.length} access events', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
              const SizedBox(height: 12),
              ...logs.map((log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: log.isHoneypot ? AppTheme.errorContainer.withValues(alpha: 0.3) : AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: log.isHoneypot ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      log.isHoneypot ? Icons.warning_amber_rounded : Icons.lock_outlined,
                      color: log.isHoneypot ? AppTheme.error : AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.action.replaceAll('_', ' '), style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface)),
                          Text('User: ${log.accessorId.substring(0, 8)}...', style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                          if (log.isHoneypot) Text('🚨 HONEYPOT ACCESS', style: AppTextStyles.codeSm.copyWith(color: AppTheme.error)),
                        ],
                      ),
                    ),
                    Text(_formatDate(log.timestamp), style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline)),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
