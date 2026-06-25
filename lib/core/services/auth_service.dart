import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._();
  static final AuthService _instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  // Passing `serverClientId` forces the native Android account picker instead
  // of a web-based fallback. This is the Web OAuth Client ID from Google Cloud
  // Console (the same one configured in Supabase Authentication -> Providers
  // -> Google -> "Client ID (for OAuth)").
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '527745842570-g7gsms10aaksoakfsbtdudvph1hf82ua.apps.googleusercontent.com',
  );
  bool _isGuest = false;

  bool get isGuest => _isGuest;
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  User? getCurrentUser() => _client.auth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthError(
          kind: AuthErrorKind.cancelled,
          title: 'Sign-in cancelled',
          message: 'You closed the Google sign-in prompt.',
          canRetry: false,
        );
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null || accessToken == null) {
        throw const AuthError(
          kind: AuthErrorKind.configuration,
          title: 'Google did not return tokens',
          message:
              'Google signed you in but did not return the tokens the app '
              'needs. This is usually caused by a misconfigured OAuth client.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthError(
          kind: AuthErrorKind.server,
          title: 'Sign-in failed',
          message: 'Supabase did not return a signed-in user.',
        );
      }
      _isGuest = false;
      await _upsertProfile(user);
      return user;
    } on AuthError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Google sign-in failed: $error\n$stackTrace');
      throw AuthError.fromException(error);
    }
  }

  /// Browser-based fallback. Opens the system browser / Chrome custom tab to
  /// Supabase's hosted Google OAuth page and back to the app via a deep
  /// link. Use this when the native account-picker path fails — e.g. when
  /// the app's SHA-1 fingerprint isn't registered with Google yet.
  ///
  /// Returns once the browser launch is initiated; the actual session is
  /// created when the deep-link callback fires and the Supabase auth state
  /// stream emits a new session.
  Future<void> signInWithGoogleViaBrowser() async {
    try {
      _isGuest = false;
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'nsltranslate://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Browser Google sign-in failed: $error\n$stackTrace');
      throw AuthError.fromException(error);
    }
  }

  Future<void> _upsertProfile(User user) async {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'display_name': metadata['full_name'] ?? metadata['name'] ?? user.email,
      'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> signOut() async {
    try {
      _isGuest = false;
      // Google Sign-In's signOut() throws if the user never authenticated with
      // Google (typical for guest sessions). Swallow that case so guests can
      // cleanly return to the welcome screen.
      try {
        await _googleSignIn.signOut();
      } on Exception catch (error, stackTrace) {
        debugPrint('Google sign-out skipped: $error\n$stackTrace');
      }
      if (_client.auth.currentUser != null) {
        await _client.auth.signOut();
      }
    } on AuthError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Sign out failed: $error\n$stackTrace');
      throw AuthError.fromException(error);
    }
  }

  Future<void> continueAsGuest() async {
    try {
      _isGuest = true;
      if (_client.auth.currentUser != null) {
        await _client.auth.signOut();
      }
    } on AuthError {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Guest mode failed: $error\n$stackTrace');
      throw AuthError.fromException(error);
    }
  }

  void dispose() {}
}
