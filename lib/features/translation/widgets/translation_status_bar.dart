import 'package:flutter/material.dart';

import '../../../core/services/inference_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/theme/app_theme.dart';

/// Compact status bar pinned to the top of the camera view. Surfaces what
/// the user actually needs to know mid-translation: model readiness, TTS
/// state, frame progress, and a flip-camera affordance.
class TranslationStatusBar extends StatelessWidget {
  const TranslationStatusBar({
    super.key,
    required this.modelStatus,
    required this.ttsState,
    required this.framesCollected,
    required this.framesRequired,
    required this.onFlipCamera,
  });

  final InferenceStatus modelStatus;
  final TtsState ttsState;
  final int framesCollected;
  final int framesRequired;
  final VoidCallback onFlipCamera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _ModelChip(status: modelStatus),
            const SizedBox(width: 8),
            _TtsChip(state: ttsState),
            const SizedBox(width: 8),
            _FrameProgressChip(
              collected: framesCollected,
              required: framesRequired,
            ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: onFlipCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              tooltip: 'Flip camera',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.status});

  final InferenceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      InferenceStatus.ready => (
        'Model ready',
        AppTheme.primary,
        Icons.bolt_outlined,
      ),
      InferenceStatus.loading => (
        'Loading model',
        AppTheme.warning,
        Icons.hourglass_top_outlined,
      ),
      InferenceStatus.modelMissing => (
        'Model missing',
        AppTheme.error,
        Icons.error_outline,
      ),
      InferenceStatus.failed => (
        'Model failed',
        AppTheme.error,
        Icons.error_outline,
      ),
      InferenceStatus.idle => (
        'Idle',
        Colors.white70,
        Icons.power_settings_new,
      ),
    };
    return _Pill(
      label: label,
      color: color,
      icon: icon,
    );
  }
}

class _TtsChip extends StatelessWidget {
  const _TtsChip({required this.state});

  final TtsState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      TtsState.idle => ('Speech', Colors.white70, Icons.volume_up_outlined),
      TtsState.speaking => (
        'Speaking',
        AppTheme.primary,
        Icons.graphic_eq_rounded,
      ),
      TtsState.error => (
        'Speech error',
        AppTheme.error,
        Icons.volume_off_outlined,
      ),
    };
    return _Pill(
      label: label,
      color: color,
      icon: icon,
      pulse: state == TtsState.speaking,
    );
  }
}

class _FrameProgressChip extends StatelessWidget {
  const _FrameProgressChip({
    required this.collected,
    required this.required,
  });

  final int collected;
  final int required;

  @override
  Widget build(BuildContext context) {
    final isReady = collected >= required;
    final color = isReady ? AppTheme.primary : Colors.white70;
    return _Pill(
      label: isReady ? 'Analyzing' : '$collected/$required',
      color: color,
      icon: isReady
          ? Icons.auto_awesome_outlined
          : Icons.timelapse_outlined,
    );
  }
}

class _Pill extends StatefulWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.icon,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool pulse;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Pill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.pulse
          ? Tween<double>(begin: 0.6, end: 1.0).animate(_controller)
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: widget.color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 14),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}