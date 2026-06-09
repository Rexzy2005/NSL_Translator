import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/providers/translation_provider.dart';
import '../../shared/theme/app_theme.dart';
import 'widgets/camera_view_widget.dart';
import 'widgets/confidence_badge_widget.dart';
import 'widgets/result_overlay_widget.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen>
    with SingleTickerProviderStateMixin {
  Future<void> _flipCamera() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Camera flip will be enabled in live mode.')),
    );
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
            CameraViewWidget(
              inferenceService: translation.inferenceService,
              onCameraReady: (_) {},
              onResult: (value) => translation.setResult(value),
            ),
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
                        onPressed: _flipCamera,
                        icon: const Icon(Icons.cameraswitch_outlined),
                        tooltip: 'Flip camera',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Open Settings from the bottom tab.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (result == null)
              const Center(
                child: _ReadyIndicator(),
              ),
            ResultOverlayWidget(
              result: result,
              threshold: settings.confidenceThreshold,
              onSpeak: translation.speak,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyIndicator extends StatefulWidget {
  const _ReadyIndicator();

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
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primary, width: 2),
        ),
        child: const Text(
          'Ready to translate',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
