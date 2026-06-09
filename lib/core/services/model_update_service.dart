import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'hive_service.dart';

class ModelUpdateService {
  ModelUpdateService({required HiveService hiveService})
      : _hiveService = hiveService;

  static const String _localVersionKey = 'local_model_version';
  static const String _stagedVersionKey = 'staged_model_version';
  final HiveService _hiveService;
  String? _remoteVersion;

  Future<bool> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.modelVersionEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Version check failed with ${response.statusCode}.');
      }
      final payload = await compute(_decodeVersionPayload, response.body);
      final remote = payload['version'] as String?;
      if (remote == null || remote.isEmpty) return false;
      _remoteVersion = remote;
      return _compareVersions(remote, getLocalModelVersion()) > 0;
    } catch (error, stackTrace) {
      debugPrint('Model update check failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> downloadAndStageModel() async {
    try {
      final version = _remoteVersion;
      if (version == null || version.isEmpty) {
        throw StateError('No remote model version is available.');
      }
      final response = await http
          .get(Uri.parse(AppConstants.modelDownloadEndpoint))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Model download failed with ${response.statusCode}.');
      }
      final dir = await getApplicationDocumentsDirectory();
      final staged = File(p.join(dir.path, 'nsl_model_staged.tflite'));
      await staged.writeAsBytes(response.bodyBytes, flush: true);
      await _hiveService.saveStringSetting(_stagedVersionKey, version);
    } catch (error, stackTrace) {
      debugPrint('Model download failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> applyUpdate() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final staged = File(p.join(dir.path, 'nsl_model_staged.tflite'));
      if (!await staged.exists()) {
        throw StateError('No staged model file exists.');
      }
      final active = File(p.join(dir.path, 'nsl_model.tflite'));
      if (await active.exists()) {
        await active.delete();
      }
      await staged.rename(active.path);
      final stagedVersion = _hiveService.getStringSetting(_stagedVersionKey,
              defaultValue: '0.0.0') ??
          '0.0.0';
      await _hiveService.saveStringSetting(_localVersionKey, stagedVersion);
    } catch (error, stackTrace) {
      debugPrint('Applying model update failed: $error\n$stackTrace');
      rethrow;
    }
  }

  String getLocalModelVersion() {
    return _hiveService.getStringSetting(
          _localVersionKey,
          defaultValue: '0.0.0',
        ) ??
        '0.0.0';
  }

  int _compareVersions(String a, String b) {
    final left = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final right = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  void dispose() {}
}

Map<String, dynamic> _decodeVersionPayload(String body) {
  return jsonDecode(body) as Map<String, dynamic>;
}
