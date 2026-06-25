import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_error.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/auth_error_dialog.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/loading_overlay.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _tagline = 'Bridging the communication gap';
  static const String _offline = 'Works offline, anywhere in Nigeria';
  static const String _speech = 'Speaks NSL signs aloud';
  static const String _feedback = 'Learns from your feedback';
  static const String _google = 'Sign in with Google';
  static const String _guest = 'Continue as Guest';

  late final AnimationController _stagger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  Future<void> _signInWithGoogle(BuildContext context) async {
    final provider = context.read<AuthProvider>();
    try {
      await provider.signInWithGoogle();
      if (!context.mounted) return;
      context.go('/permissions');
    } catch (error) {
      if (!context.mounted) return;
      await AuthErrorDialog.show(
        context,
        error: AuthError.fromException(error),
        onRetry: () => _signInWithGoogle(context),
        onUseBrowser: () => _signInWithGoogleViaBrowser(context),
        onContinueAsGuest: () => _continueAsGuest(context),
      );
    }
  }

  Future<void> _signInWithGoogleViaBrowser(BuildContext context) async {
    final provider = context.read<AuthProvider>();
    try {
      await provider.signInWithGoogleViaBrowser();
      // Browser OAuth resolves asynchronously via deep link → auth state
      // stream. Don't navigate here; the listener will move the user once
      // the session arrives. We do pop back to /welcome so the redirect
      // doesn't trap them on /permissions.
      if (!context.mounted) return;
      context.go('/welcome');
    } catch (error) {
      if (!context.mounted) return;
      await AuthErrorDialog.show(
        context,
        error: AuthError.fromException(error),
        onRetry: () => _signInWithGoogleViaBrowser(context),
        onUseBrowser: () => _signInWithGoogleViaBrowser(context),
        onContinueAsGuest: () => _continueAsGuest(context),
      );
    }
  }

  Future<void> _continueAsGuest(BuildContext context) async {
    final provider = context.read<AuthProvider>();
    try {
      await provider.continueAsGuest();
      if (!context.mounted) return;
      context.go('/permissions');
    } catch (error) {
      if (!context.mounted) return;
      await AuthErrorDialog.show(
        context,
        error: AuthError.fromException(error),
        onRetry: () => _continueAsGuest(context),
        onUseBrowser: () => _signInWithGoogleViaBrowser(context),
        onContinueAsGuest: () => _continueAsGuest(context),
      );
    }
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F9FA), Color(0xFFE8F8F1)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Staggered(
                    controller: _stagger,
                    index: 0,
                    child: const Center(child: BrandLogo(revealed: true)),
                  ),
                  const SizedBox(height: 16),
                  _Staggered(
                    controller: _stagger,
                    index: 1,
                    child: Text(
                      _tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Spacer(),
                  _Staggered(
                    controller: _stagger,
                    index: 2,
                    child: const _Feature(
                      icon: Icons.offline_bolt_outlined,
                      text: _offline,
                    ),
                  ),
                  _Staggered(
                    controller: _stagger,
                    index: 3,
                    child: const _Feature(
                      icon: Icons.volume_up_outlined,
                      text: _speech,
                    ),
                  ),
                  _Staggered(
                    controller: _stagger,
                    index: 4,
                    child: const _Feature(
                      icon: Icons.school_outlined,
                      text: _feedback,
                    ),
                  ),
                  const Spacer(),
                  _Staggered(
                    controller: _stagger,
                    index: 5,
                    child: _PrimaryButton(
                      label: _google,
                      icon: SvgPicture.asset(
                        'assets/images/google_g.svg',
                        width: 22,
                        height: 22,
                      ),
                      enabled: !auth.isLoading,
                      onPressed: () => _signInWithGoogle(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Staggered(
                    controller: _stagger,
                    index: 6,
                    child: Center(
                      child: TextButton(
                        onPressed:
                            auth.isLoading ? null : () => _continueAsGuest(context),
                        child: Text(
                          _guest,
                          style: TextStyle(
                            color: AppTheme.textPrimary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades + slides up a child at a specific stagger index. The controller runs
/// once; each item's delay is `index * step`.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  static const Duration _step = Duration(milliseconds: 110);

  @override
  Widget build(BuildContext context) {
    final start =
        index * _step.inMilliseconds / controller.duration!.inMilliseconds;
    final end = (start + 0.55).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 24),
            child: child,
          ),
        );
      },
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}