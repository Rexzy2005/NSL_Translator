# NSL Translate Mobile Guide

## Environment

Run the app with Supabase and model endpoints supplied through Dart defines:

```powershell
C:\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key `
  --dart-define=MODEL_VERSION_ENDPOINT=https://your-project.supabase.co/storage/v1/object/public/models/version.json `
  --dart-define=MODEL_DOWNLOAD_ENDPOINT=https://your-project.supabase.co/storage/v1/object/public/models/nsl_model_fp16.tflite
```

For a debug APK:

```powershell
C:\flutter\bin\flutter.bat build apk --debug `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key `
  --dart-define=MODEL_VERSION_ENDPOINT=https://your-project.supabase.co/storage/v1/object/public/models/version.json `
  --dart-define=MODEL_DOWNLOAD_ENDPOINT=https://your-project.supabase.co/storage/v1/object/public/models/nsl_model_fp16.tflite
```

The `SUPABASE_PUBLISHABLE_KEY` is the new anon JWT (safe to embed in the app). Do **not** commit `.env` files or hard-code these into the repo.

## Supabase setup (one-time)

Perform these steps once before the first run:

1. **Create a Supabase project** at <https://supabase.com>.
2. **Run the schema.** Open the SQL editor for the new project and execute
   [supabase_schema.sql](supabase_schema.sql) end-to-end. This creates
   `profiles`, `translation_history`, `sign_feedback`, the
   `sign-feedback-videos` storage bucket, and the row-level security policies.
3. **Enable Google auth.** Go to Authentication → Providers → Google. Toggle
   it on and paste the OAuth client ID and secret from your Google Cloud
   Console project (see the Google section below).
4. **Create the public `models` storage bucket** (Storage → New bucket →
   name `models`, public = on). The app fetches `version.json` and the
   `nsl_model_fp16.tflite` file from this bucket anonymously.
5. **Upload `version.json`** to `models/version.json`:
   ```json
   {
     "version": "1.0.0",
     "size_bytes": 2027472,
     "model_file": "nsl_model_fp16.tflite"
   }
   ```
   Bump `version` (semver) each time you ship a new model. The compare is
   numeric, so `1.0.1` is detected as newer than `1.0.0`.
6. **Upload `nsl_model_fp16.tflite`** to `models/nsl_model_fp16.tflite` in
   the same bucket. The file currently in
   `assets/models/nsl_model_fp16.tflite` is the canonical one.
7. **(Already done by the schema)** The `sign-feedback-videos` bucket is
   created with policies that allow anyone to insert and read.

## Google Sign-In (one-time)

1. Go to <https://console.cloud.google.com> and create (or select) a project.
2. APIs & Services → OAuth consent screen → fill in app name, support email,
   scopes (`email`, `profile`, `openid`). Add the Supabase auth callback
   `https://<project>.supabase.co/auth/v1/callback` to the authorised list.
3. APIs & Services → Credentials → Create credentials → OAuth client ID →
   type **Web application**. The Supabase docs will use this client's ID
   and secret; copy the **Web client ID** and **Web client secret**.
4. Paste both into Supabase → Authentication → Providers → Google and save.
5. For native Android, also create an **Android** OAuth client ID:
   - Package name: your app's application ID (e.g. `com.example.nsl_translate`).
   - SHA-1: the signing certificate fingerprint of the APK you are about to
     build. Get it with `keytool -list -v -keystore ~/.android/debug.keystore`.
6. For native iOS, also create an **iOS** OAuth client ID:
   - Bundle ID: your iOS bundle identifier.
   - Copy the iOS client ID and the auto-generated **iOS URL scheme** (the
     reversed client ID). Add the URL scheme to `ios/Runner/Info.plist`
     under `CFBundleURLTypes` if it is not already there.
7. Build the Android APK with the `google-services.json` or the OAuth
   client IDs injected at build time. `google_sign_in: ^6.2.0` reads
   `default_web_client_id` from `android/app/google-services.json`; if you
   prefer to keep things minimal, also acceptable is to inject the Web
   client ID as a `--dart-define=GOOGLE_WEB_CLIENT_ID=...` and reference
   it in `AuthService`.

## Model Assets

When the model pipeline exports the first usable model, copy:

```text
nsl_model_fp16.tflite -> assets/models/nsl_model_fp16.tflite
labels.json -> assets/models/labels.json
```

The app expects the model input shape to be `[1, 30, 1662]` using the same
MediaPipe Holistic landmark order used during training:

```text
pose:       33 landmarks x 4 values = 132
face:      468 landmarks x 3 values = 1404
left hand:  21 landmarks x 3 values = 63
right hand: 21 landmarks x 3 values = 63
total: 1662 float32 values per frame
```

`assets/models/labels.json` must map output indexes (as strings) to display
labels. The shipped file maps to the 12 trained signs:

```text
0:good_afternoon  1:good_evening  2:good_morning  3:good_night
4:greetings       5:how           6:what          7:whatever
8:when            9:where         10:which        11:who
```

## OTA model updates

The Settings screen has a **Check for model update** button. The flow:

1. App fetches `MODEL_VERSION_ENDPOINT` (defaults to
   `…/storage/v1/object/public/models/version.json`).
2. If the remote `version` is greater than the locally stored one, a
   confirmation dialog offers to download.
3. Downloaded file is staged at
   `<documents>/nsl_model_fp16_staged.tflite` and a confirmation dialog
   offers to apply it.
4. On apply, the staged file is renamed to `<documents>/nsl_model_fp16.tflite`
   and the local version is updated.
5. The user is prompted to **restart the app** for the new model to load
   (`InferenceService` re-reads from disk on next launch).

## MediaPipe Runtime

The Flutter translation pipeline is:

```text
camera stream -> native MediaPipe channel -> 30-frame buffer -> TFLite -> result
```

The native channel name is:

```text
nsl_translate/mediapipe
```

It must implement:

```text
extractHolisticLandmarks(cameraFrame) -> 1662 float values
dispose()
```

Until the native MediaPipe Holistic extractor is added to Android/iOS, the
app surfaces a clear runtime message instead of fake translations.

## Video contributions

The Feedback screen includes a **Sign video (optional)** card. The user
can:

1. Tap **Set up camera** to grant camera and microphone permissions and
   initialize the front camera.
2. Tap **Start recording**, perform the sign, then **Stop recording**.
3. The clip is saved to `<documents>/contributions/sign_<timestamp>.mp4`
   and the path is queued in SQLite (`feedback_queue` table).
4. Submitting a label along with the recording creates a single
   `sign_feedback` row pointing at the local file.
5. When the device is online, `SyncService.syncFeedback()` uploads the
   video to the `sign-feedback-videos` bucket and inserts a row in the
   `sign_feedback` table. The local file is left in place for now so the
   user can re-share if needed.

If the user prefers to submit a label only, the **Skip video** path
(simple label + dropdown + Submit) still works — `video_path` will be
the literal `pending_video` and `sign_feedback.video_path` will be NULL
on sync.

## Permissions already configured

- **Android** — `CAMERA`, `RECORD_AUDIO`, `INTERNET`,
  `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`. The `RECORD_AUDIO`
  permission is required for video recording with audio on Android 9+.
- **iOS** — `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`.
  The photo-library entries are only used if a future feature exports
  recorded clips to the device gallery.
