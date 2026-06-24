import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/services/inference_service.dart';
import '../../shared/theme/app_theme.dart';
import 'widgets/camera_view_widget.dart';
import 'widgets/confidence_badge_widget.dart';
import 'widgets/result_overlay_widget.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen>
    with SingleTickerProviderStateMixin {
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  void _flipCamera() {
    setState(() {
      _lensDirection = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
  }

  @override
  Widget build(BuildContext context) {
    final translation = context.watch<TranslationProvider>();
    final settings = context.watch<SettingsProvider>();
    final result = translation.currentResult;
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.isActive)
              CameraViewWidget(
                key: ValueKey(_lensDirection),
                inferenceService: translation.inferenceService,
                isTranslating: translation.isTranslating,
                lensDirection: _lensDirection,
                onCameraReady: (_) {},
                onResult: (value) => translation.setResult(value),
              )
            else
              const ColoredBox(color: Colors.black),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (result != null)
                        ConfidenceBadgeWidget(confidence: result.confidence),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () =>
                            settings.setTtsEnabled(!settings.ttsEnabled),
                        icon: Icon(
                          settings.ttsEnabled
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                        ),
                        tooltip: settings.ttsEnabled
                            ? 'Disable speech'
                            : 'Enable speech',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _flipCamera,
                        icon: const Icon(Icons.cameraswitch_outlined),
                        tooltip: 'Flip camera',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (result == null)
              Center(
                child: _ReadyIndicator(
                  status: translation.inferenceService.status,
                  isTranslating: translation.isTranslating,
                ),
              ),
            ResultOverlayWidget(
              result: result,
              threshold: settings.confidenceThreshold,
              onSpeak: translation.speak,
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _TranslationControl(
                    isTranslating: translation.isTranslating,
                    onPressed: () {
                      if (translation.isTranslating) {
                        translation.stopTranslating();
                      } else {
                        translation.startTranslating();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyIndicator extends StatefulWidget {
  const _ReadyIndicator({
    required this.status,
    required this.isTranslating,
  });

  final InferenceStatus status;
  final bool isTranslating;

  @override
  State<_ReadyIndicator> createState() => _ReadyIndicatorState();
}

class _ReadyIndicatorState extends State<_ReadyIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.isTranslating
        ? switch (widget.status) {
            InferenceStatus.ready => 'Translating',
            InferenceStatus.modelMissing => 'Model not installed',
            InferenceStatus.failed => 'Model unavailable',
            InferenceStatus.idle => 'Preparing translator',
          }
        : 'Camera ready';
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 2),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TranslationControl extends StatelessWidget {
  const _TranslationControl({
    required this.isTranslating,
    required this.onPressed,
  });

  final bool isTranslating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(isTranslating ? Icons.stop : Icons.play_arrow),
      label: Text(isTranslating ? 'Stop translating' : 'Start translating'),
      style: FilledButton.styleFrom(
        backgroundColor: isTranslating ? AppTheme.error : AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );
  }
}
