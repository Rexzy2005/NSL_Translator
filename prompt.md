You are a senior Flutter developer. Build a complete, production-quality Flutter mobile application called "NSL Translate" — an offline-first Nigerian Sign Language translation app. 

The AI inference layer is intentionally stubbed. Every other feature must be fully implemented and functional. Follow every instruction exactly.

---

## TECH STACK

- Flutter (latest stable)
- Supabase Flutter (auth + cloud sync)
- Google Sign-In
- Hive Flutter (local NoSQL — translation history)
- sqflite (local SQLite — feedback queue)
- camera plugin (live camera feed)
- flutter_tts (offline text-to-speech)
- connectivity_plus (network monitoring)
- provider (state management)
- http (OTA model version check)
- path_provider, intl

---

## FOLDER STRUCTURE

Create exactly this structure:

lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── inference_service.dart
│   │   ├── hive_service.dart
│   │   ├── sqlite_service.dart
│   │   ├── sync_service.dart
│   │   ├── connectivity_service.dart
│   │   └── model_update_service.dart
│   ├── models/
│   │   ├── sign_result.dart
│   │   ├── translation_entry.dart
│   │   └── feedback_entry.dart
│   └── providers/
│       ├── auth_provider.dart
│       ├── translation_provider.dart
│       └── settings_provider.dart
├── features/
│   ├── auth/
│   │   ├── splash_screen.dart
│   │   └── welcome_screen.dart
│   ├── translation/
│   │   ├── translation_screen.dart
│   │   ├── widgets/
│   │   │   ├── camera_view_widget.dart
│   │   │   ├── result_overlay_widget.dart
│   │   │   └── confidence_badge_widget.dart
│   ├── history/
│   │   ├── history_screen.dart
│   │   └── widgets/
│   │       └── history_card_widget.dart
│   ├── feedback/
│   │   └── feedback_screen.dart
│   └── settings/
│       └── settings_screen.dart
└── shared/
    ├── theme/
    │   └── app_theme.dart
    └── widgets/
        ├── main_scaffold.dart
        └── loading_overlay.dart

---

## PUBSPEC.YAML

```yaml
name: nsl_translate
description: Offline-first Nigerian Sign Language translation mobile app.
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.3.0
  google_sign_in: ^6.2.0
  hive_flutter: ^1.1.0
  hive: ^2.2.3
  sqflite: ^2.3.0
  camera: ^0.10.5+9
  flutter_tts: ^4.0.2
  connectivity_plus: ^6.0.3
  provider: ^6.1.2
  http: ^1.2.0
  path_provider: ^2.1.2
  intl: ^0.19.0
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/models/
```

---

## DESIGN SYSTEM

Apply these rules to every screen:

- Primary color: #1D9E75 (teal green)
- Background: #F8F9FA (light) / #0F1117 (dark)
- Surface: #FFFFFF (light) / #1A1D27 (dark)
- Text primary: #1A1A2E
- Text secondary: #6B7280
- Error: #EF4444
- Warning: #F59E0B
- Font: system default (no custom font needed)
- Border radius: 12px for cards, 8px for buttons, 24px for bottom sheets
- Elevation: flat design, use borders not shadows
- All screens support dark mode via ThemeData
- Bottom navigation bar: 4 tabs — Translate, History, Feedback, Settings
- No AppBar on the Translate screen (full-screen camera)
- Every screen has proper SafeArea
- All loading states show a subtle shimmer or circular indicator
- All empty states have an icon + message + optional CTA button

---

## MODELS

### lib/core/models/sign_result.dart
```dart
class SignResult {
  final String label;
  final double confidence;
  final DateTime timestamp;

  const SignResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  bool get isHighConfidence => confidence >= 0.80;
}
```

### lib/core/models/translation_entry.dart
Create a Hive TypeAdapter for this model. Fields:
- String id (UUID)
- String signLabel
- double confidence
- DateTime timestamp
- bool syncedToCloud

### lib/core/models/feedback_entry.dart
Fields (for SQLite):
- int? id (autoincrement)
- String signLabel (user-provided label)
- String videoPath (path to recorded video, placeholder string for now)
- DateTime submittedAt
- bool synced

---

## CONSTANTS

### lib/core/constants/app_constants.dart
```dart
class AppConstants {
  static const String appName = 'NSL Translate';
  static const double confidenceThreshold = 0.80;
  static const int frameBufferSize = 30;
  static const int frameRate = 30;
  static const String hiveTranslationBox = 'translations';
  static const String hiveSettingsBox = 'settings';
  static const String modelVersionEndpoint = 'https://your-supabase-project.supabase.co/storage/v1/object/public/models/version.json';
  static const String modelDownloadEndpoint = 'https://your-supabase-project.supabase.co/storage/v1/object/public/models/nsl_model.tflite';
  static const List<String> nslVocabulary = [
    'Hello', 'Thank you', 'Help', 'Yes', 'No',
    'Please', 'Sorry', 'Hospital', 'Doctor', 'Pain',
    'Medicine', 'Water', 'Food', 'Police', 'School',
    'Money', 'I/Me', 'You', 'Family', 'Emergency',
  ];
}
```

---

## SERVICES

### lib/core/services/inference_service.dart

This is the AI integration slot. Implement it as a clean stub now.

```dart
// INFERENCE SERVICE — AI STUB
// 
// This service is intentionally stubbed. When the TFLite LSTM model
// is ready, replace the body of runInference() with:
//   1. Load nsl_model.tflite via tflite_flutter
//   2. Accept List<List<double>> frameBuffer (shape: [30, 1662])
//   3. Run interpreter.run(input, output)
//   4. Parse softmax output, return SignResult
//
// The rest of the app calls only this interface — zero changes needed elsewhere.

class InferenceService {
  bool _isInitialized = false;

  Future<void> initialize() async {
    // TODO: Load TFLite model from assets/models/nsl_model.tflite
    await Future.delayed(const Duration(milliseconds: 300));
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  Future<SignResult?> runInference(List<List<double>> frameBuffer) async {
    // STUB: returns a random result from the vocabulary for UI testing
    if (!_isInitialized) return null;
    if (frameBuffer.length < AppConstants.frameBufferSize) return null;

    await Future.delayed(const Duration(milliseconds: 80));

    final random = Random();
    final label = AppConstants.nslVocabulary[random.nextInt(AppConstants.nslVocabulary.length)];
    final confidence = 0.60 + random.nextDouble() * 0.39;

    return SignResult(
      label: label,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    // TODO: Dispose TFLite interpreter
    _isInitialized = false;
  }
}
```

### lib/core/services/auth_service.dart

Implement fully:
- signInWithGoogle() using Supabase + google_sign_in
- signOut()
- continueAsGuest() — sets a local flag, no Supabase call
- getCurrentUser() — returns Supabase User or null
- isGuest getter
- authStateStream — exposes Supabase onAuthStateChange
- On sign-in, upsert user profile into a Supabase `profiles` table (id, email, display_name, avatar_url, created_at)

### lib/core/services/hive_service.dart

Implement fully:
- initializeHive() — opens translation box and settings box
- saveTranslation(TranslationEntry entry)
- getAllTranslations() → List<TranslationEntry> sorted by timestamp descending
- deleteTranslation(String id)
- clearAll()
- getUnsyncedTranslations() → List<TranslationEntry> where syncedToCloud == false
- markAsSynced(String id)
- saveStringSetting(String key, String value)
- getStringSetting(String key, {String? defaultValue})
- saveDoubleSetting(String key, double value)
- getDoubleSetting(String key, {double? defaultValue})

### lib/core/services/sqlite_service.dart

Implement fully using sqflite:
- initializeDatabase() — creates feedback_queue table
- insertFeedback(FeedbackEntry entry)
- getUnsynced() → List<FeedbackEntry>
- markAsSynced(int id)
- deleteAll()

Table schema:
```sql
CREATE TABLE feedback_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sign_label TEXT NOT NULL,
  video_path TEXT NOT NULL,
  submitted_at TEXT NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0
)
```

### lib/core/services/sync_service.dart

Implement fully:
- syncTranslations() — push unsynced Hive entries to Supabase `translation_history` table (only if authenticated, not guest)
- syncFeedback() — push unsynced SQLite feedback entries to Supabase `sign_feedback` table
- performFullSync() — calls both in sequence, handles errors gracefully per item
- All sync operations must be non-blocking: catch per-item errors, continue with the rest, never crash the app on sync failure

Supabase table schemas to upsert into:
- translation_history: (id uuid, user_id uuid, sign_label text, confidence float, recorded_at timestamptz, created_at timestamptz)
- sign_feedback: (id serial, user_id uuid nullable, sign_label text, video_path text, submitted_at timestamptz, synced_at timestamptz)

### lib/core/services/connectivity_service.dart

Implement fully:
- Uses connectivity_plus
- Exposes isConnected getter (bool)
- Exposes connectionStream (Stream<bool>)
- On connection restored → automatically calls SyncService.performFullSync()
- Singleton pattern

### lib/core/services/model_update_service.dart

Implement fully:
- checkForUpdate() → Future<bool> — hits the modelVersionEndpoint, compares remote version with locally stored version (in Hive settings), returns true if update available
- downloadAndStageModel() — downloads the .tflite file to app's documents directory as nsl_model_staged.tflite, saves the new version string to Hive
- applyUpdate() — renames staged file to nsl_model.tflite, marks update as applied
- getLocalModelVersion() → String (default '0.0.0' if never updated)
- Version endpoint returns JSON: {"version": "1.0.1", "size_bytes": 4200000}
- All operations run in background isolate where possible
- Never block UI thread

---

## PROVIDERS

### lib/core/providers/auth_provider.dart
- Wraps AuthService
- Exposes: isAuthenticated, isGuest, currentUser, isLoading
- Listens to authStateStream and notifies listeners
- Handles sign-in / sign-out actions with loading state

### lib/core/providers/translation_provider.dart
- Manages translation session state
- Exposes: currentResult (SignResult?), sessionHistory (List<SignResult>), isProcessing, isCameraActive
- setResult(SignResult result) — saves to Hive, triggers TTS if confidence >= threshold
- clearSession()
- confidence threshold comes from SettingsProvider

### lib/core/providers/settings_provider.dart
- Loads/saves from Hive settings box
- Exposes: confidenceThreshold (double, default 0.80), ttsRate (double, default 0.5), ttsLanguage (String, default 'en-NG'), localModelVersion (String)
- All setters persist to Hive immediately

---

## SCREENS

### lib/features/auth/splash_screen.dart

Full implementation:
- Shows app logo (use a Text widget styled as a large green "NSL" with subtitle "Translate" below it — no image asset needed)
- Checks Supabase session on init
- If session exists → navigate to MainScaffold
- If no session → navigate to WelcomeScreen
- 2 second minimum display time
- Smooth fade transition

### lib/features/auth/welcome_screen.dart

Full implementation:
- App name + tagline: "Bridging the communication gap"
- Brief 3-point feature list with icons:
  - "Works offline, anywhere in Nigeria"
  - "Speaks NSL signs aloud"
  - "Learns from your feedback"
- "Sign in with Google" button (white button, Google-style, with Google G icon using a colored Text widget)
- "Continue as Guest" text button below
- Both buttons fully wired to AuthProvider
- Loading state on both buttons during auth
- Error snackbar on failure

### lib/features/translation/translation_screen.dart

Full implementation:
- Full-screen camera preview using CameraViewWidget
- Overlaid result display at the bottom 30% of screen using ResultOverlayWidget
- Top-right: small settings icon and camera flip button
- The camera widget calls InferenceService.runInference() with a simulated frameBuffer every 1 second (stub ticker — real MediaPipe replaces this later)
- On each result: update TranslationProvider, trigger TTS via flutter_tts if confidence >= threshold
- Show ConfidenceBadgeWidget reflecting current confidence
- Show "Low confidence — try again" message when below threshold
- When no result yet: show animated pulsing circle with "Ready to translate" text
- All camera permissions handled with graceful error screen if denied

### lib/features/translation/widgets/camera_view_widget.dart

Full implementation:
- Initializes CameraController with back camera, ResolutionPreset.high
- Renders CameraPreview filling the screen
- Exposes a simulation ticker (Timer.periodic every 1000ms) that generates a dummy frameBuffer (List.generate(30, (_) => List.generate(1662, (_) => 0.0))) and calls InferenceService.runInference()
- Clean dispose handling

### lib/features/translation/widgets/result_overlay_widget.dart

Full implementation:
- Semi-transparent dark panel at bottom of screen
- Large sign label text (32px, bold, white)
- Confidence percentage below it
- TTS play button (plays the label again on tap)
- "Save to history" is automatic — label in TranslationProvider handles this
- Animated: slides up when a result appears, fades out after 3 seconds of no new result

### lib/features/translation/widgets/confidence_badge_widget.dart

Shows a colored pill: green for >= 80%, amber for 60-79%, red for < 60%

### lib/features/history/history_screen.dart

Full implementation:
- Reads from HiveService.getAllTranslations()
- ListView of HistoryCardWidgets
- Pull-to-refresh triggers SyncService.syncTranslations()
- Empty state: icon + "No translations yet. Start signing."
- Each card is dismissible (swipe to delete) with confirmation
- Shows sync status badge per card (cloud icon if synced, clock icon if pending)
- Header shows total count

### lib/features/history/widgets/history_card_widget.dart

Full implementation:
- Sign label (bold)
- Confidence as percentage bar
- Formatted timestamp (e.g. "Today, 14:32" / "Yesterday" / "Jun 3")
- Sync status icon (top right)
- Tap to replay TTS for that sign

### lib/features/feedback/feedback_screen.dart

Full implementation:
- Explanation text: "Help improve NSL Translate by labeling signs the app didn't recognize."
- Text field: "What sign were you performing?"
- Dropdown: select from AppConstants.nslVocabulary or type custom
- "Submit" button: saves FeedbackEntry to SQLite queue with video_path as placeholder string "pending_video"
- Success message after submission
- Shows pending count badge: "X submissions pending sync"
- List of pending feedback entries below the form
- ConnectivityService triggers sync automatically when online — show "Synced X items" snackbar when it happens

### lib/features/settings/settings_screen.dart

Full implementation:
- User profile section at top:
  - Avatar circle with initials (from display name) or Google photo URL
  - Display name + email
  - "Guest User" if not authenticated
  - Sign out button (or Sign In button for guests)
- Recognition settings section:
  - Confidence threshold slider (0.5 to 0.95, step 0.05) — persists via SettingsProvider
  - Current value shown as percentage label
- Speech settings section:
  - TTS rate slider (0.1 to 1.0)
  - Language selector: ['en-NG', 'en-US', 'en-GB']
- About section:
  - App version from package_info or hardcoded "1.0.0"
  - Model version from SettingsProvider.localModelVersion
  - "Check for model update" button — calls ModelUpdateService.checkForUpdate(), shows result as snackbar

### lib/shared/widgets/main_scaffold.dart

Full implementation:
- Persistent bottom navigation bar with 4 tabs
- Tab 0: Translate (camera icon)
- Tab 1: History (history icon)
- Tab 2: Feedback (flag icon)
- Tab 3: Settings (settings icon)
- History tab shows badge with unsync count from HiveService
- PageView with IndexedStack for state preservation
- No AppBar

---

## THEME

### lib/shared/theme/app_theme.dart

Implement full light and dark ThemeData:
- Primary: Color(0xFF1D9E75)
- Light background: Color(0xFFF8F9FA)
- Dark background: Color(0xFF0F1117)
- Light surface: Colors.white
- Dark surface: Color(0xFF1A1D27)
- BottomNavigationBar matches surface color
- InputDecoration theme: outlined, rounded, teal focus border
- ElevatedButton theme: teal background, white text, 8px radius, no elevation
- TextButton theme: teal text
- SnackBar theme: dark background, white text, rounded

---

## MAIN ENTRY

### lib/main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  await Hive.initFlutter();
  // Register all adapters
  
  final hiveService = HiveService();
  await hiveService.initializeHive();
  
  final sqliteService = SqliteService();
  await sqliteService.initializeDatabase();
  
  final inferenceService = InferenceService();
  await inferenceService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider(hiveService)),
        ChangeNotifierProvider(
          create: (ctx) => TranslationProvider(
            hiveService: hiveService,
            inferenceService: inferenceService,
            settings: ctx.read<SettingsProvider>(),
          ),
        ),
        Provider.value(value: hiveService),
        Provider.value(value: sqliteService),
        Provider.value(value: ConnectivityService()),
        Provider.value(value: SyncService()),
        Provider.value(value: ModelUpdateService()),
      ],
      child: const NSLTranslateApp(),
    ),
  );
}
```

### lib/app.dart

MaterialApp.router with GoRouter (add go_router: ^13.0.0 to pubspec):
- Routes: /splash, /welcome, /home (MainScaffold)
- Redirect logic: if no session and trying to access /home → redirect to /welcome
- Theme: light and dark from AppTheme
- App name: 'NSL Translate'

---

## SUPABASE SCHEMA

Include this as a comment block at the top of sync_service.dart:

```sql
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
```

---

## ANDROID SETUP

In android/app/src/main/AndroidManifest.xml add:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

In android/app/build.gradle set minSdkVersion to 21.

---

## IOS SETUP

In ios/Runner/Info.plist add:
```xml
<key>NSCameraUsageDescription</key>
<string>NSL Translate needs camera access to recognize sign language gestures.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Required by the camera plugin.</string>
```

---

## QUALITY REQUIREMENTS

- Zero hardcoded strings in UI — all user-facing text defined as constants or inline constants per screen
- Every async operation wrapped in try/catch with meaningful error messages
- No print() statements — use debugPrint() only
- Every service has a dispose() method called appropriately
- Camera controller always disposed on screen exit
- Hive boxes never double-opened
- All nullable types handled — no null dereferences
- All lists checked for empty before accessing index
- ConnectivityService listener cancelled in dispose
- App must run cleanly on both Android and iOS with no hot-reload errors
- The InferenceService stub must produce realistic-looking output so all UI states (high confidence, low confidence, no result) are testable without the real model

---


## DELIVERABLE

A complete, runnable Flutter project. Every file listed in the folder structure must exist and be fully implemented. The app must:

1. Launch to splash → auto-route to welcome or home based on session
2. Support Google sign-in and guest mode
3. Show live camera feed on translate screen
4. Simulate recognition results every second via the stub
5. Display results with TTS playback
6. Save and display translation history with offline-first sync
7. Accept and queue feedback submissions
8. Check for model updates in the background
9. Expose all settings with persistence
10. Run without any API keys or credentials hardcoded (use placeholder strings with TODO comments)

Do not leave any file as a skeleton or placeholder. Every screen, widget, service, and model must be fully implemented.