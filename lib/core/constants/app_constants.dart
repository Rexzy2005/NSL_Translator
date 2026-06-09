class AppConstants {
  static const String appName = 'NSL Translate';
  static const double confidenceThreshold = 0.80;
  static const int frameBufferSize = 30;
  static const int frameRate = 30;
  static const String hiveTranslationBox = 'translations';
  static const String hiveSettingsBox = 'settings';
  static const String modelVersionEndpoint =
      'https://your-supabase-project.supabase.co/storage/v1/object/public/models/version.json';
  static const String modelDownloadEndpoint =
      'https://your-supabase-project.supabase.co/storage/v1/object/public/models/nsl_model.tflite';
  static const List<String> nslVocabulary = [
    'Hello',
    'Thank you',
    'Help',
    'Yes',
    'No',
    'Please',
    'Sorry',
    'Hospital',
    'Doctor',
    'Pain',
    'Medicine',
    'Water',
    'Food',
    'Police',
    'School',
    'Money',
    'I/Me',
    'You',
    'Family',
    'Emergency',
  ];
}
