import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _currentUser = _authService.getCurrentUser();
    _subscription = _authService.authStateStream.listen((state) {
      _currentUser = state.session?.user;
      notifyListeners();
    });
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;
  User? _currentUser;
  bool _isLoading = false;

  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => _authService.isGuest;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> signInWithGoogle() async {
    await _runAuthAction(() async {
      _currentUser = await _authService.signInWithGoogle();
    });
  }

  /// Browser-based fallback path. Opens a Chrome custom tab / system browser
  /// to Supabase's hosted Google OAuth page. Use this when the native
  /// account-picker fails (e.g. SHA-1 not registered).
  Future<void> signInWithGoogleViaBrowser() async {
    await _runAuthAction(() async {
      await _authService.signInWithGoogleViaBrowser();
    });
  }

  Future<void> continueAsGuest() async {
    await _runAuthAction(() async {
      await _authService.continueAsGuest();
      _currentUser = null;
    });
  }

  Future<void> signOut() async {
    await _runAuthAction(() async {
      await _authService.signOut();
      _currentUser = null;
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
