import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class ConfidenceBadgeWidget extends StatelessWidget {
  const ConfidenceBadgeWidget({super.key, required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.80
        ? AppTheme.primary
        : confidence >= 0.60
            ? AppTheme.warning
            : AppTheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '${(confidence * 100).round()}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
