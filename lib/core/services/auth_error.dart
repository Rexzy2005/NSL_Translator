import 'package:flutter/services.dart' show PlatformException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Categorises sign-in failures so the UI can show a specific, helpful
/// message instead of dumping a raw exception string on the user.
enum AuthErrorKind {
  /// The device couldn't reach Google's servers — no connection, or Google
  /// rejected the request because the app's signing key (SHA-1) isn't
  /// registered against the OAuth client. The native `google_sign_in`
  /// plugin surfaces both as `network_error`, so we treat them together and
  /// give troubleshooting steps that cover each.
  network,

  /// The user dismissed the account picker.
  cancelled,

  /// OAuth client / signing key misconfiguration.
  configuration,

  /// Supabase rejected the token (expired session, server-side issue).
  server,

  /// Anything we don't recognise.
  unknown,
}

/// A friendly, user-facing auth failure. Always carries a short title, a
/// readable message, and — where useful — a troubleshooting tip. The UI uses
/// [kind] to pick an icon and decide whether to offer a retry.
class AuthError implements Exception {
  const AuthError({
    required this.kind,
    required this.title,
    required this.message,
    this.tip,
    this.canRetry = true,
  });

  final AuthErrorKind kind;
  final String title;
  final String message;
  final String? tip;
  final bool canRetry;

  /// Map any thrown object to a friendly, actionable error.
  factory AuthError.fromException(Object error) {
    // Already-friendly — pass through.
    if (error is AuthError) return error;

    // Google Sign-In native failures surface as PlatformException.
    if (error is PlatformException) {
      switch (error.code) {
        case 'network_error':
          return const AuthError(
            kind: AuthErrorKind.network,
            title: "Couldn't reach Google",
            message:
                'We could not connect to Google to finish sign-in. This is '
                'usually caused by a weak or missing internet connection, or '
                'the app\'s signing key is not registered with Google yet.',
            tip: 'Check your connection and try again. If it keeps failing, '
                'use "Sign in via browser" below.',
          );
        case 'sign_in_canceled':
          return const AuthError(
            kind: AuthErrorKind.cancelled,
            title: 'Sign-in cancelled',
            message: 'You closed the Google sign-in prompt.',
            canRetry: false,
          );
        case 'sign_in_failed':
        case 'invalid_account':
          return const AuthError(
            kind: AuthErrorKind.configuration,
            title: 'Sign-in not available',
            message:
                'Google blocked this sign-in. This almost always means the '
                'app\'s signing certificate (SHA-1) is not registered in '
                'Google Cloud Console for this device.',
            tip: 'You can still sign in via the browser, or the developer can '
                'register this device\'s SHA-1 fingerprint with Google.',
          );
        default:
          return AuthError(
            kind: AuthErrorKind.unknown,
            title: 'Sign-in failed',
            message: (error.message != null && error.message!.isNotEmpty)
                ? error.message!
                : 'Something went wrong talking to Google (${error.code}).',
          );
      }
    }

    // Our own guard throws AuthException for cancellation / token issues.
    if (error is AuthException) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('cancel')) {
        return AuthError(
          kind: AuthErrorKind.cancelled,
          title: 'Sign-in cancelled',
          message: msg,
          canRetry: false,
        );
      }
      if (lower.contains('network') ||
          lower.contains('timeout') ||
          lower.contains('fetch')) {
        return AuthError(
          kind: AuthErrorKind.network,
          title: "Couldn't reach Google",
          message: msg,
        );
      }
      return AuthError(
        kind: AuthErrorKind.server,
        title: 'Sign-in failed',
        message: msg,
      );
    }

    return AuthError(
      kind: AuthErrorKind.unknown,
      title: 'Something went wrong',
      message: error.toString(),
    );
  }

  @override
  String toString() => message;
}
