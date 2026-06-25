import 'package:flutter/material.dart';

import '../../core/services/auth_error.dart';
import '../theme/app_theme.dart';

/// Modal sheet shown when Google sign-in fails. Replaces the raw
/// `SnackBar(error.toString())` that used to flash and disappear.
///
/// Picks an icon and copy based on the error [kind], offers:
///   - a "Try again" primary action (when the error is recoverable)
///   - a "Sign in via browser" secondary action for network / config errors
///   - a "Continue as guest" escape hatch so the user is never stuck
class AuthErrorDialog extends StatelessWidget {
  const AuthErrorDialog({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onUseBrowser,
    required this.onContinueAsGuest,
  });

  final AuthError error;
  final VoidCallback onRetry;
  final VoidCallback onUseBrowser;
  final VoidCallback onContinueAsGuest;

  /// Convenience launcher. Returns `true` if the user picked a path that
  /// navigates them away from the welcome screen (browser sign-in or
  /// guest), `false` if they just closed the dialog.
  static Future<bool> show(
    BuildContext context, {
    required AuthError error,
    required VoidCallback onRetry,
    required VoidCallback onUseBrowser,
    required VoidCallback onContinueAsGuest,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthErrorDialog(
        error: error,
        onRetry: onRetry,
        onUseBrowser: onUseBrowser,
        onContinueAsGuest: onContinueAsGuest,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _iconBackground(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon(), color: _iconForeground(context), size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                error.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
              ),
              if (error.tip != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error.tip!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (error.canRetry)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onRetry();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              if (_offerBrowserFallback) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onUseBrowser();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppTheme.primary, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text(
                    'Sign in via browser',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onContinueAsGuest();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(
                  'Continue as guest instead',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _offerBrowserFallback =>
      error.kind == AuthErrorKind.network ||
      error.kind == AuthErrorKind.configuration ||
      error.kind == AuthErrorKind.unknown;

  IconData _icon() {
    switch (error.kind) {
      case AuthErrorKind.network:
        return Icons.wifi_off_rounded;
      case AuthErrorKind.cancelled:
        return Icons.cancel_outlined;
      case AuthErrorKind.configuration:
        return Icons.build_circle_outlined;
      case AuthErrorKind.server:
        return Icons.cloud_off_rounded;
      case AuthErrorKind.unknown:
        return Icons.error_outline_rounded;
    }
  }

  Color _iconBackground(BuildContext context) {
    switch (error.kind) {
      case AuthErrorKind.network:
      case AuthErrorKind.configuration:
      case AuthErrorKind.server:
      case AuthErrorKind.unknown:
        return AppTheme.error.withValues(alpha: 0.10);
      case AuthErrorKind.cancelled:
        return AppTheme.textSecondary.withValues(alpha: 0.14);
    }
  }

  Color _iconForeground(BuildContext context) {
    switch (error.kind) {
      case AuthErrorKind.network:
      case AuthErrorKind.configuration:
      case AuthErrorKind.server:
      case AuthErrorKind.unknown:
        return AppTheme.error;
      case AuthErrorKind.cancelled:
        return AppTheme.textSecondary;
    }
  }
}
