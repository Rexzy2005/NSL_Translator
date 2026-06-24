import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/loading_overlay.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String _title = 'NSL Translate';
  static const String _tagline = 'Bridging the communication gap';
  static const String _offline = 'Works offline, anywhere in Nigeria';
  static const String _speech = 'Speaks NSL signs aloud';
  static const String _feedback = 'Learns from your feedback';
  static const String _google = 'Sign in with Google';
  static const String _guest = 'Continue as Guest';

  Future<void> _run(
    BuildContext context,
    Future<void> Function(AuthProvider provider) action,
  ) async {
    try {
      await action(context.read<AuthProvider>());
      if (context.mounted) context.go('/permissions');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 48),
                const _Feature(
                    icon: Icons.offline_bolt_outlined, text: _offline),
                const _Feature(icon: Icons.volume_up_outlined, text: _speech),
                const _Feature(icon: Icons.school_outlined, text: _feedback),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: auth.isLoading
                      ? null
                      : () => _run(
                            context,
                            (provider) => provider.signInWithGoogle(),
                          ),
                  icon: SvgPicture.asset(
                    'assets/images/google_g.svg',
                    width: 22,
                    height: 22,
                  ),
                  label: const Text(_google),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => _run(
                            context,
                            (provider) => provider.continueAsGuest(),
                          ),
                  child: const Text(_guest),
                ),
              ],
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
