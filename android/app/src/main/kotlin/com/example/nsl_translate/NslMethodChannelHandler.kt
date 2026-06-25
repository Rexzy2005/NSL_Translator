package com.example.nsl_translate

import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Method channel handler for the `nsl_translate/mediapipe` channel.
 *
 * Bridges the Dart `MediaPipeLandmarkExtractor` to the native
 * [MediaPipeHolistic] pipeline. Accepts a YUV420 [CameraImage] shape from
 * Dart (width, height, format, sensorOrientation, three planes of bytes),
 * converts it to a rotation-correct RGB bitmap, runs the three MediaPipe
 * landmarkers, and returns the 1662-float feature vector.
 */
class NslMethodChannelHandler(private val context: android.content.Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "nsl_translate/mediapipe"
    }

    private val holistic: MediaPipeHolistic by lazy { MediaPipeHolistic(context) }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "extractHolisticLandmarks" -> handleExtract(call, result)
            "dispose" -> {
                holistic.close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleExtract(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val format = call.argument<String>("format")
        val sensorOrientation = call.argument<Int>("sensorOrientation") ?: 0
        @Suppress("UNCHECKED_CAST")
        val planes = call.argument<List<Map<String, Any>>>("planes")

        if (width == null || height == null || planes == null || planes.size < 3) {
            result.error(
                "BAD_ARGS",
                "extractHolisticLandmarks requires width, height, and three planes.",
                null
            )
            return
        }

        try {
            val bitmap = yuv420ToBitmap(planes, width, height, sensorOrientation)
                ?: run {
                    result.error(
                        "MEDIAPIPE_FRAME_DECODE_FAILED",
                        "Could not decode camera frame to bitmap.",
                        null
                    )
                    return
                }
            val features = holistic.extract(bitmap)
            result.success(features.toList())
        } catch (t: Throwable) {
            android.util.Log.e("NslMethodChannelHandler", "extract failed", t)
            result.error("MEDIAPIPE_FAILED", t.message ?: "unknown", null)
        }
    }

    /**
     * Converts three YUV420 planes (Y, U, V) plus a sensor orientation into
     * an upright RGB bitmap. This is the standard NV21-ish flow used by
     * CameraX / camera plugins.
     */
    private fun yuv420ToBitmap(
        planes: List<Map<String, Any>>,
        width: Int,
        height: Int,
        sensorOrientation: Int
    ): Bitmap? {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val yBytes = yPlane["bytes"] as? ByteArray ?: return null
        val uBytes = uPlane["bytes"] as? ByteArray ?: return null
        val vBytes = vPlane["bytes"] as? ByteArray ?: return null
        val yRowStride = (yPlane["bytesPerRow"] as? Int) ?: width
        val uRowStride = (uPlane["bytesPerRow"] as? Int) ?: width / 2
        val vRowStride = (vPlane["bytesPerRow"] as? Int) ?: width / 2
        val uPixelStride = (uPlane["bytesPerPixel"] as? Int) ?: 1
        val vPixelStride = (vPlane["bytesPerPixel"] as? Int) ?: 1

        // Pack NV21: Y plane followed by interleaved VU at half resolution.
        val frameSize = width * height
        val nv21 = ByteArray(frameSize + frameSize / 2)
        System.arraycopy(yBytes, 0, nv21, 0, frameSize)

        // YUV_420_888 → NV21 conversion (handles arbitrary row/pixel strides).
        var yIndex = frameSize
        val chromaHeight = height / 2
        val chromaWidth = width / 2
        for (j in 0 until chromaHeight) {
            for (i in 0 until chromaWidth) {
                val uRowStart = j * uRowStride
                val vRowStart = j * vRowStride
                val uIndex = uRowStart + i * uPixelStride
                val vIndex = vRowStart + i * vPixelStride
                nv21[yIndex++] = vBytes[vIndex]
                nv21[yIndex++] = uBytes[uIndex]
            }
        }

        val yuvImage = android.graphics.YuvImage(
            nv21,
            android.graphics.ImageFormat.NV21,
            width,
            height,
            null
        )
        val out = java.io.ByteArrayOutputStream()
        yuvImage.compressToJpeg(android.graphics.Rect(0, 0, width, height), 90, out)
        val jpegBytes = out.toByteArray()
        val raw = android.graphics.BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            ?: return null

        // Apply the sensor rotation so the bitmap matches what the user sees.
        return rotate(raw, sensorOrientation.toFloat())
    }

    private fun rotate(bitmap: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return bitmap
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
