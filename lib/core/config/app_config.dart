/// Runtime configuration injected through `--dart-define` at build/run time.
///
/// Where to get the values:
/// - `SUPABASE_URL` & `SUPABASE_PUBLISHABLE_KEY` — Supabase project
///   dashboard → Settings → API. The publishable key is the new anon JWT
///   (it is safe to ship in the app).
/// - `MODEL_VERSION_ENDPOINT` — full URL to a JSON file in a public Supabase
///   Storage bucket, e.g.
///   `https://<project>.supabase.co/storage/v1/object/public/models/version.json`.
/// - `MODEL_DOWNLOAD_ENDPOINT` — full URL to the TFLite model file in the
///   same bucket, e.g.
///   `https://<project>.supabase.co/storage/v1/object/public/models/nsl_model_fp16.tflite`.
///
/// If any of these are left at the placeholder defaults, [hasSupabaseConfig]
/// returns false and the auth / sync / model-update services will fail loudly
/// the first time they are used.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-supabase-project.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static const String modelVersionEndpoint = String.fromEnvironment(
    'MODEL_VERSION_ENDPOINT',
    defaultValue: '$supabaseUrl/storage/v1/object/public/models/version.json',
  );

  static const String modelDownloadEndpoint = String.fromEnvironment(
    'MODEL_DOWNLOAD_ENDPOINT',
    defaultValue:
        '$supabaseUrl/storage/v1/object/public/models/nsl_model_fp16.tflite',
  );

  static bool get hasSupabaseConfig {
    return supabaseUrl != 'https://your-supabase-project.supabase.co' &&
        supabasePublishableKey != 'YOUR_SUPABASE_ANON_KEY';
  }
}
