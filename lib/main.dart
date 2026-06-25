import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/translation_provider.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/inference_service.dart';
import 'core/services/model_update_service.dart';
import 'core/services/sqlite_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  await Hive.initFlutter();

  final hiveService = HiveService();
  await hiveService.initializeHive();

  final sqliteService = SqliteService();
  await sqliteService.initializeDatabase();

  final inferenceService = InferenceService();
  await inferenceService.initialize();

  final settingsProvider = SettingsProvider(hiveService);
  // Pre-warm TTS with the user's last-used language + rate so the first
  // translation is heard immediately. Fire-and-forget — if it fails the
  // service handles the en-NG → en-US fallback internally.
  final ttsService = TtsService();
  unawaited(ttsService.warmUp(
    language: settingsProvider.ttsLanguage,
    rate: settingsProvider.ttsRate,
  ));

  final syncService = SyncService(
    hiveService: hiveService,
    sqliteService: sqliteService,
  );
  final connectivityService = ConnectivityService(syncService: syncService);
  final modelUpdateService = ModelUpdateService(hiveService: hiveService)
    ..onModelApplied = inferenceService.reloadModel;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => ttsService),
        ChangeNotifierProvider(
          create: (context) => TranslationProvider(
            hiveService: hiveService,
            inferenceService: inferenceService,
            settings: context.read<SettingsProvider>(),
            ttsService: ttsService,
          ),
        ),
        Provider<HiveService>(
          create: (_) => hiveService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<SqliteService>(
          create: (_) => sqliteService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<ConnectivityService>(
          create: (_) => connectivityService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<SyncService>(
          create: (_) => syncService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<ModelUpdateService>(
          create: (_) => modelUpdateService,
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: const NSLTranslateApp(),
    ),
  );
}

void unawaited(Future<void> future) {
  // Intentionally not awaited; errors are logged inside TtsService.
}
