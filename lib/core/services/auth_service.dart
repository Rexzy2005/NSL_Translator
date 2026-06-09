import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._();
  static final AuthService _instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  bool _isGuest = false;

  bool get isGuest => _isGuest;
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  User? getCurrentUser() => _client.auth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null || accessToken == null) {
        throw const AuthException('Google did not return auth tokens.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Supabase did not return a signed-in user.');
      }
      _isGuest = false;
      await _upsertProfile(user);
      return user;
    } catch (error, stackTrace) {
      debugPrint('Google sign-in failed: $error\n$stackTrace');
      rethrow;
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
      await Future.wait([
        _googleSignIn.signOut(),
        _client.auth.signOut(),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Sign out failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> continueAsGuest() async {
    try {
      _isGuest = true;
      if (_client.auth.currentUser != null) {
        await _client.auth.signOut();
      }
    } catch (error, stackTrace) {
      debugPrint('Guest mode failed: $error\n$stackTrace');
      rethrow;
    }
  }

  void dispose() {}
}
