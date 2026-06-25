import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'hive_service.dart';
import 'sqlite_service.dart';

class SyncService {
  SyncService({
    required HiveService hiveService,
    required SqliteService sqliteService,
    AuthService? authService,
  })  : _hiveService = hiveService,
        _sqliteService = sqliteService,
        _authService = authService ?? AuthService();

  final HiveService _hiveService;
  final SqliteService _sqliteService;
  final AuthService _authService;
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> syncTranslations() async {
    final user = _authService.getCurrentUser();
    if (user == null || _authService.isGuest) return 0;
    var synced = 0;
    for (final entry in _hiveService.getUnsyncedTranslations()) {
      try {
        await _client.from('translation_history').upsert({
          'id': entry.id,
          'user_id': user.id,
          'sign_label': entry.signLabel,
          'confidence': entry.confidence,
          'session_id': entry.sessionId,
          'recorded_at': entry.timestamp.toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await _hiveService.markAsSynced(entry.id);
        synced++;
      } catch (error, stackTrace) {
        debugPrint(
            'Translation sync failed for ${entry.id}: $error\n$stackTrace');
      }
    }
    return synced;
  }

  Future<int> syncFeedback() async {
    final user = _authService.getCurrentUser();
    if (user == null || _authService.isGuest) return 0;
    var synced = 0;
    for (final entry in await _sqliteService.getUnsynced()) {
      try {
        final videoPath = await _uploadContributionVideo(entry.videoPath);
        await _client.from('sign_feedback').insert({
          'user_id': user.id,
          'sign_label': entry.signLabel,
          'video_path': videoPath,
          'submitted_at': entry.submittedAt.toUtc().toIso8601String(),
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        });
        final id = entry.id;
        if (id != null) {
          await _sqliteService.markAsSynced(id);
          synced++;
        }
      } catch (error, stackTrace) {
        debugPrint('Feedback sync failed for ${entry.id}: $error\n$stackTrace');
      }
    }
    return synced;
  }

  Future<String> _uploadContributionVideo(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) return localPath;
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath)}';
    final storagePath = 'contributions/$name';
    await _client.storage.from('sign-feedback-videos').uploadBinary(
          storagePath,
          await file.readAsBytes(),
          fileOptions:
              const FileOptions(contentType: 'video/mp4', upsert: true),
        );
    return storagePath;
  }

  Future<int> performFullSync() async {
    var total = 0;
    try {
      total += await syncTranslations();
    } catch (error, stackTrace) {
      debugPrint('Translation sync batch failed: $error\n$stackTrace');
    }
    try {
      total += await syncFeedback();
    } catch (error, stackTrace) {
      debugPrint('Feedback sync batch failed: $error\n$stackTrace');
    }
    return total;
  }

  void dispose() {}
}
