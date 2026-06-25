import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// Friendly empty state for the history tab. Loops a gentle animated
/// hand-wave so the screen never feels dead.
class HistoryEmptyState extends StatefulWidget {
  const HistoryEmptyState({super.key, this.message});

  final String? message;

  @override
  State<HistoryEmptyState> createState() => _HistoryEmptyStateState();
}

class _HistoryEmptyStateState extends State<HistoryEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _EmptyStatePainter(_controller.value),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No translations yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              widget.message ??
                  'Start signing on the Translate tab. Anything that meets the '
                      'confidence threshold is saved here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStatePainter extends CustomPainter {
  _EmptyStatePainter(this.t);

  final double t; // 0..1 looped

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.32;

    // Soft halo that pulses
    final pulse = math.sin(t * math.pi * 2) * 0.5 + 0.5;
    final halo = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.10 + pulse * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * (1.05 + pulse * 0.10), halo);

    // Outer ring
    final ring = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ring);

    // Dashed rotating ring
    final dashPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final dashRadius = radius * 1.18;
    const dashes = 12;
    for (var i = 0; i < dashes; i++) {
      final angle = (i / dashes) * math.pi * 2 + t * math.pi * 2;
      final start = center +
          Offset(math.cos(angle), math.sin(angle)) * (dashRadius - 4);
      final end = center +
          Offset(math.cos(angle), math.sin(angle)) * (dashRadius + 4);
      canvas.drawLine(start, end, dashPaint);
    }

    // Hand icon center
    final iconPaint = Paint()..color = AppTheme.primary;
    final iconOffset = center + const Offset(0, -6);
    final iconSize = radius * 0.85;
    // Palm
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: iconOffset,
        width: iconSize * 0.7,
        height: iconSize * 0.85,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, iconPaint);
    // Fingers — four small bumps at the top
    final fingerPaint = Paint()..color = AppTheme.primary;
    for (var i = 0; i < 4; i++) {
      final x = iconOffset.dx - iconSize * 0.25 + (i * iconSize * 0.17);
      final y = iconOffset.dy - iconSize * 0.4;
      canvas.drawCircle(Offset(x, y), iconSize * 0.08, fingerPaint);
    }
    // Thumb — a small arc on the right
    final thumb = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(iconOffset.dx + iconSize * 0.32, iconOffset.dy - iconSize * 0.1),
      iconSize * 0.10,
      thumb,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyStatePainter oldDelegate) =>
      oldDelegate.t != t;
}