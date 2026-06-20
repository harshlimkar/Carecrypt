import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CcEncryptedBadge extends StatelessWidget {
  const CcEncryptedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.secondary),
          const SizedBox(width: 4),
          Text(
            'AES-256',
            style: AppTextStyles.codeSm.copyWith(
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
