import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../services/hive_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._hiveService) {
    load();
  }

  final HiveService _hiveService;
  double _confidenceThreshold = AppConstants.confidenceThreshold;
  double _ttsRate = 0.5;
  bool _ttsEnabled = true;
  String _ttsLanguage = 'en-NG';
  String _localModelVersion = '0.0.0';

  double get confidenceThreshold => _confidenceThreshold;
  double get ttsRate => _ttsRate;
  bool get ttsEnabled => _ttsEnabled;
  String get ttsLanguage => _ttsLanguage;
  String get localModelVersion => _localModelVersion;

  void load() {
    _confidenceThreshold = _hiveService.getDoubleSetting(
          'confidence_threshold',
          defaultValue: AppConstants.confidenceThreshold,
        ) ??
        AppConstants.confidenceThreshold;
    _ttsRate =
        _hiveService.getDoubleSetting('tts_rate', defaultValue: 0.5) ?? 0.5;
    _ttsEnabled =
        _hiveService.getBoolSetting('tts_enabled', defaultValue: true) ?? true;
    _ttsLanguage =
        _hiveService.getStringSetting('tts_language', defaultValue: 'en-NG') ??
            'en-NG';
    _localModelVersion = _hiveService.getStringSetting('local_model_version',
            defaultValue: '0.0.0') ??
        '0.0.0';
    notifyListeners();
  }

  Future<void> setConfidenceThreshold(double value) async {
    _confidenceThreshold = value;
    notifyListeners();
    await _hiveService.saveDoubleSetting('confidence_threshold', value);
  }

  Future<void> setTtsRate(double value) async {
    _ttsRate = value;
    notifyListeners();
    await _hiveService.saveDoubleSetting('tts_rate', value);
  }

  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    notifyListeners();
    await _hiveService.saveBoolSetting('tts_enabled', value);
  }

  Future<void> setTtsLanguage(String value) async {
    _ttsLanguage = value;
    notifyListeners();
    await _hiveService.saveStringSetting('tts_language', value);
  }

  Future<void> refreshLocalModelVersion() async {
    _localModelVersion = _hiveService.getStringSetting('local_model_version',
            defaultValue: '0.0.0') ??
        '0.0.0';
    notifyListeners();
  }
}
