import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ai_service.dart';

class CcSafetyScoreChip extends StatelessWidget {
  final AiSafetyScore score;

  const CcSafetyScoreChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (score.riskLevel) {
      'safe' => (AppTheme.safeGreen, AppTheme.safeGreenContainer),
      'warning' => (AppTheme.warningAmber, AppTheme.warningContainer),
      'danger' => (AppTheme.dangerRed, AppTheme.dangerContainer),
      _ => (AppTheme.outline, AppTheme.surfaceContainerLow),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            score.riskLevel == 'safe' ? Icons.check_circle : score.riskLevel == 'warning' ? Icons.warning_amber : Icons.dangerous_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${score.safetyPercent.toStringAsFixed(0)}% ${score.riskLevel == 'safe' ? 'Safe' : score.riskLevel == 'warning' ? 'Caution' : 'Risk'}',
            style: AppTextStyles.codeSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
