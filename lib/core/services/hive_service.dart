import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../models/translation_entry.dart';

class HiveService {
  Box<TranslationEntry>? _translationBox;
  Box<dynamic>? _settingsBox;

  Future<void> initializeHive() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TranslationEntryAdapter());
    }
    _translationBox ??= Hive.isBoxOpen(AppConstants.hiveTranslationBox)
        ? Hive.box<TranslationEntry>(AppConstants.hiveTranslationBox)
        : await Hive.openBox<TranslationEntry>(AppConstants.hiveTranslationBox);
    _settingsBox ??= Hive.isBoxOpen(AppConstants.hiveSettingsBox)
        ? Hive.box<dynamic>(AppConstants.hiveSettingsBox)
        : await Hive.openBox<dynamic>(AppConstants.hiveSettingsBox);
  }

  Box<TranslationEntry> get translations {
    final box = _translationBox;
    if (box == null) {
      throw StateError('Hive translations box is not initialized.');
    }
    return box;
  }

  Box<dynamic> get settings {
    final box = _settingsBox;
    if (box == null) {
      throw StateError('Hive settings box is not initialized.');
    }
    return box;
  }

  Future<void> saveTranslation(TranslationEntry entry) async {
    await translations.put(entry.id, entry);
  }

  List<TranslationEntry> getAllTranslations() {
    final items = translations.values.toList();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<void> deleteTranslation(String id) => translations.delete(id);

  Future<void> clearAll() => translations.clear();

  List<TranslationEntry> getUnsyncedTranslations() {
    return translations.values.where((entry) => !entry.syncedToCloud).toList();
  }

  Future<void> markAsSynced(String id) async {
    final entry = translations.get(id);
    if (entry == null) return;
    await translations.put(id, entry.copyWith(syncedToCloud: true));
  }

  Future<void> saveStringSetting(String key, String value) =>
      settings.put(key, value);

  String? getStringSetting(String key, {String? defaultValue}) {
    final value = settings.get(key, defaultValue: defaultValue);
    return value is String ? value : defaultValue;
  }

  Future<void> saveDoubleSetting(String key, double value) =>
      settings.put(key, value);

  double? getDoubleSetting(String key, {double? defaultValue}) {
    final value = settings.get(key, defaultValue: defaultValue);
    return value is double ? value : defaultValue;
  }

  Future<void> saveBoolSetting(String key, bool value) =>
      settings.put(key, value);

  bool? getBoolSetting(String key, {bool? defaultValue}) {
    final value = settings.get(key, defaultValue: defaultValue);
    return value is bool ? value : defaultValue;
  }

  Future<void> dispose() async {
    await _translationBox?.close();
    await _settingsBox?.close();
    _translationBox = null;
    _settingsBox = null;
  }
}
