import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'hive_service.dart';
import 'sqlite_service.dart';

/*
-- Run these in Supabase SQL editor

create table profiles (
  id uuid references auth.users primary key,
  email text,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

create table translation_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users,
  sign_label text not null,
  confidence float not null,
  recorded_at timestamptz not null,
  created_at timestamptz default now()
);

create table sign_feedback (
  id serial primary key,
  user_id uuid references auth.users,
  sign_label text not null,
  video_path text not null,
  submitted_at timestamptz not null,
  synced_at timestamptz default now()
);

-- RLS policies
alter table profiles enable row level security;
alter table translation_history enable row level security;
alter table sign_feedback enable row level security;

create policy "Users can manage own profile" on profiles for all using (auth.uid() = id);
create policy "Users can manage own translations" on translation_history for all using (auth.uid() = user_id);
create policy "Users can insert feedback" on sign_feedback for insert with check (true);
create policy "Users can view own feedback" on sign_feedback for select using (auth.uid() = user_id or user_id is null);
*/

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
    if (_authService.isGuest) return 0;
    var synced = 0;
    for (final entry in await _sqliteService.getUnsynced()) {
      try {
        await _client.from('sign_feedback').insert({
          'user_id': user?.id,
          'sign_label': entry.signLabel,
          'video_path': entry.videoPath,
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
