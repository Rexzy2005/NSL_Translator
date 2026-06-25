import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/services/inference_service.dart';
import '../../core/services/tts_service.dart';
import '../../shared/theme/app_theme.dart';
import 'widgets/camera_view_widget.dart';
import 'widgets/live_translation_card.dart';
import 'widgets/translation_status_bar.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  int _framesCollected = 0;
  bool _usingSimulatedLandmarks = false;

  void _flipCamera() {
    setState(() {
      _lensDirection = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      _framesCollected = 0;
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
                onFrameCountChanged: (count) {
                  if (count != _framesCollected && mounted) {
                    setState(() => _framesCollected = count);
                  }
                },
                onSimulatedModeChanged: (value) {
                  if (value != _usingSimulatedLandmarks && mounted) {
                    setState(() => _usingSimulatedLandmarks = value);
                  }
                },
              )
            else
              const ColoredBox(color: Colors.black),
            // Status bar at the top
            TranslationStatusBar(
              modelStatus: translation.inferenceService.status,
              ttsState: translation.ttsState,
              framesCollected: _framesCollected,
              framesRequired: 30,
              onFlipCamera: _flipCamera,
            ),
            // Floating "Demo mode" chip — only shown when the native pipeline
            // isn't connected and we're using the simulated extractor.
            if (_usingSimulatedLandmarks)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 12,
                child: _DemoModeChip(
                  onTap: () => _showDemoModeInfo(context),
                ),
              ),
            // Center hint before any translation result
            if (result == null)
              Center(
                child: _ReadyIndicator(
                  status: translation.inferenceService.status,
                  isTranslating: translation.isTranslating,
                ),
              ),
            // Bottom-anchored translation card
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 84),
                  child: LiveTranslationCard(
                    result: result,
                    threshold: settings.confidenceThreshold,
                    ttsEnabled: settings.ttsEnabled,
                    isSpeaking: translation.ttsState == TtsState.speaking,
                    onReplay: translation.speak,
                    onClear: translation.clearSession,
                  ),
                ),
              ),
            ),
            // Bottom-anchored start/stop control
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: _TranslationControl(
                    isTranslating: translation.isTranslating,
                    onPressed: () {
                      if (translation.isTranslating) {
                        translation.stopTranslating();
                      } else {
                        translation.startTranslating();
                        setState(() => _framesCollected = 0);
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

  void _showDemoModeInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Demo mode',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The native MediaPipe Holistic pipeline isn\'t connected on this '
              'build, so the app is generating simulated landmark motion for '
              'each of the 12 trained signs. The full pipeline (camera → '
              'landmarks → TFLite → text → TTS) still runs end-to-end so you '
              'can preview the experience.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'For real on-device inference, implement the Kotlin / Swift '
              'handler for the nsl_translate/mediapipe channel. See '
              'MEDIAPIPE_NATIVE.md for the full protocol.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeChip extends StatelessWidget {
  const _DemoModeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.warning),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined, color: AppTheme.warning, size: 14),
              SizedBox(width: 6),
              Text(
                'Demo mode',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
            InferenceStatus.loading => 'Loading model...',
            InferenceStatus.modelMissing =>
              'Add assets/models/nsl_model_fp16.tflite to enable translation.',
            InferenceStatus.failed =>
              widget.status.name == 'failed' ? 'Model failed to load' : null,
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
          message ?? 'Ready',
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: (isTranslating ? AppTheme.error : AppTheme.primary)
                .withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            isTranslating ? Icons.stop_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isTranslating),
          ),
        ),
        label: Text(isTranslating ? 'Stop translating' : 'Start translating'),
        style: FilledButton.styleFrom(
          backgroundColor:
              isTranslating ? AppTheme.error : AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}