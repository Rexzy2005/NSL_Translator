import 'package:flutter/material.dart';

import '../../../core/models/sign_result.dart';
import '../../../shared/theme/app_theme.dart';

/// The persistent bottom-anchored translation card. Always visible while the
/// user is translating — the result stays on screen until a newer one
/// slides in to replace it (or the user taps Clear).
class LiveTranslationCard extends StatelessWidget {
  const LiveTranslationCard({
    super.key,
    required this.result,
    required this.threshold,
    required this.ttsEnabled,
    required this.isSpeaking,
    required this.onReplay,
    required this.onClear,
  });

  final SignResult? result;
  final double threshold;
  final bool ttsEnabled;
  final bool isSpeaking;
  final ValueChanged<String> onReplay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // Slide up + fade in, slide down + fade out — the new card slides
          // in from below while the old one slides out the same way.
          final offset = Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation);
          return ClipRect(
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            ),
          );
        },
        child: result == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : _Card(
                key: ValueKey(result!.timestamp),
                result: result!,
                threshold: threshold,
                ttsEnabled: ttsEnabled,
                isSpeaking: isSpeaking,
                onReplay: onReplay,
                onClear: onClear,
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.result,
    required this.threshold,
    required this.ttsEnabled,
    required this.isSpeaking,
    required this.onReplay,
    required this.onClear,
  });

  final SignResult result;
  final double threshold;
  final bool ttsEnabled;
  final bool isSpeaking;
  final ValueChanged<String> onReplay;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isHigh = result.confidence >= threshold;
    final confidenceColor = isHigh
        ? AppTheme.primary
        : result.confidence >= threshold - 0.20
            ? AppTheme.warning
            : AppTheme.error;
    return InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 36,
                  decoration: BoxDecoration(
                    color: confidenceColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _ConfidenceBar(
                        value: result.confidence,
                        color: confidenceColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ReplayButton(
                  isSpeaking: isSpeaking,
                  enabled: ttsEnabled,
                  onPressed: () => onReplay(result.label),
                ),
              ],
            ),
            if (result.alternativeLabels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Also seen as: ${result.alternativeLabels.take(2).join(' · ')}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isHigh
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 14,
                  color: isHigh
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppTheme.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isHigh
                        ? 'Saved to history${ttsEnabled ? '' : ' · speech off'}'
                        : 'Low confidence · keep signing for a clearer read',
                    style: TextStyle(
                      color: isHigh
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            FractionallySizedBox(
              widthFactor: animated.clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton({
    required this.isSpeaking,
    required this.enabled,
    required this.onPressed,
  });

  final bool isSpeaking;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: enabled ? onPressed : null,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isSpeaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
          key: ValueKey(isSpeaking),
          color: Colors.white,
        ),
      ),
      tooltip: enabled ? 'Replay speech' : 'Speech is off',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primary,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
      ),
    );
  }
}