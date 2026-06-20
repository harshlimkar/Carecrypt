import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CcTimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isFirst;
  final Color color;
  final IconData icon;

  const CcTimelineItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.color = AppTheme.primary,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3), width: 3),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMd.copyWith(color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
