import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand mark used on splash and welcome screens. The two halves slide apart
/// to reveal the full wordmark; can also be rendered statically.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.revealed = false,
    this.fontSize = 64,
    this.gapFactor = 0.78,
    this.color = AppTheme.primary,
  });

  /// When true, the two halves slide apart to reveal the wordmark.
  /// When false, they're stacked at center.
  final bool revealed;

  final double fontSize;

  /// How far apart the two halves move when revealed. 0 = stacked,
  /// 1 = at the edge of the bounding box.
  final double gapFactor;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.0,
      color: color,
      height: 1.0,
    );
    const logo = 'NSL';
    const subtitle = 'Translate';
    return SizedBox(
      height: fontSize * 1.3,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedSlide(
            offset: revealed ? Offset(-gapFactor, 0) : Offset.zero,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary,
                    Color(0xFF38BDF8),
                  ],
                ).createShader(rect);
              },
              child: Text(
                logo,
                style: baseStyle.copyWith(color: Colors.white),
              ),
            ),
          ),
          AnimatedSlide(
            offset: revealed
                ? Offset(gapFactor * 1.05, 0.12)
                : const Offset(1.5, 0.12),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: revealed ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: fontSize * 0.42,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}