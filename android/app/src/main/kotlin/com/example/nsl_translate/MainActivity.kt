package com.example.nsl_translate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nsl_translate/mediapipe"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractHolisticLandmarks" -> result.error(
                    "MEDIAPIPE_NOT_CONFIGURED",
                    "Native MediaPipe Holistic landmark extraction is not configured yet.",
                    null
                )
                "dispose" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}
