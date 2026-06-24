import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/hive_service.dart';
import '../../shared/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.sign_language_outlined,
      title: 'Point the camera at a sign',
      body: 'Keep your hands visible and sign clearly inside the frame.',
    ),
    _OnboardingStep(
      icon: Icons.record_voice_over_outlined,
      title: 'Read and hear translations',
      body: 'High-confidence signs are spoken aloud and saved automatically.',
    ),
    _OnboardingStep(
      icon: Icons.video_call_outlined,
      title: 'Contribute new signs',
      body: 'Record labeled sign videos to help improve the NSL model.',
    ),
  ];

  Future<void> _finish() async {
    await context
        .read<HiveService>()
        .saveStringSetting('onboarding_done', 'true');
    if (mounted) context.go('/welcome');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child:
                    TextButton(onPressed: _finish, child: const Text('Skip')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) =>
                      _StepView(step: _steps[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _index == index ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == index
                          ? AppTheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_index == _steps.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child:
                    Text(_index == _steps.length - 1 ? 'Get started' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, size: 56, color: AppTheme.primary),
        ),
        const SizedBox(height: 32),
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          step.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
