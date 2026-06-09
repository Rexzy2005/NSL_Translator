import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'sync_service.dart';

class ConnectivityService {
  factory ConnectivityService({SyncService? syncService}) {
    if (syncService != null) _instance._syncService = syncService;
    return _instance;
  }

  ConnectivityService._() {
    _subscription = Connectivity().onConnectivityChanged.listen(_handleChange);
    _refreshInitialStatus();
  }

  static final ConnectivityService _instance = ConnectivityService._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  SyncService? _syncService;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _controller.stream;

  Future<void> _refreshInitialStatus() async {
    try {
      _handleChange(await Connectivity().checkConnectivity());
    } catch (error, stackTrace) {
      debugPrint('Initial connectivity check failed: $error\n$stackTrace');
    }
  }

  void _handleChange(List<ConnectivityResult> results) {
    final connected =
        results.any((result) => result != ConnectivityResult.none);
    final restored = connected && !_isConnected;
    _isConnected = connected;
    if (!_controller.isClosed) _controller.add(connected);
    if (restored) {
      _syncService?.performFullSync();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
