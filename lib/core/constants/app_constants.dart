import '../config/app_config.dart';

class AppConstants {
  static const String appName = 'NSL Translate';
  static const double confidenceThreshold = 0.80;
  static const int frameBufferSize = 30;
  static const int featureVectorSize = 1662;
  static const int frameRate = 30;
  static const String modelAssetPath = 'assets/models/nsl_model_fp16.tflite';
  static const String labelsAssetPath = 'assets/models/labels.json';
  static const String hiveTranslationBox = 'translations';
  static const String hiveSettingsBox = 'settings';
  static String get modelVersionEndpoint => AppConfig.modelVersionEndpoint;
  static String get modelDownloadEndpoint => AppConfig.modelDownloadEndpoint;
  /// The 12 signs the model was trained on (must match labels.json).
  static const List<String> nslVocabulary = [
    'good_afternoon',
    'good_evening',
    'good_morning',
    'good_night',
    'greetings',
    'how',
    'what',
    'whatever',
    'when',
    'where',
    'which',
    'who',
  ];
}
