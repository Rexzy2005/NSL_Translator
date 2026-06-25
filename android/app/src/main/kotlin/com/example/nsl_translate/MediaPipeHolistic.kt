package com.example.nsl_translate

import android.content.Context
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.framework.image.BitmapImageBuilder

/**
 * Wraps the three MediaPipe Tasks landmarkers (pose, hand, face) and assembles
 * the 1662-float holistic feature vector expected by the NSL TFLite model:
 *
 *   pose      : 33 landmarks x (x, y, z, visibility) = 132
 *   face      : 468 landmarks x (x, y, z)           = 1404
 *   left hand : 21 landmarks x (x, y, z)            = 63
 *   right hand: 21 landmarks x (x, y, z)            = 63
 *
 * The order matches [nsl-translator/training/notebooks/02_model_training.ipynb].
 */
class MediaPipeHolistic(private val context: Context) {

    companion object {
        const val FEATURE_LENGTH = 1662
        const val POSE_LENGTH = 132       // 33 * 4
        const val FACE_LENGTH = 1404      // 468 * 3
        const val HAND_LENGTH = 63        // 21 * 3
    }

    private val poseLandmarker: PoseLandmarker? by lazy {
        try {
            val baseOptions = com.google.mediapipe.tasks.core.BaseOptions.builder()
                .setModelAssetPath("pose_landmarker.task")
                .build()
            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .build()
            PoseLandmarker.createFromOptions(context, options)
        } catch (t: Throwable) {
            android.util.Log.e("MediaPipeHolistic", "Failed to init PoseLandmarker", t)
            null
        }
    }

    private val handLandmarker: HandLandmarker? by lazy {
        try {
            val baseOptions = com.google.mediapipe.tasks.core.BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumHands(2)
                .build()
            HandLandmarker.createFromOptions(context, options)
        } catch (t: Throwable) {
            android.util.Log.e("MediaPipeHolistic", "Failed to init HandLandmarker", t)
            null
        }
    }

    private val faceLandmarker: FaceLandmarker? by lazy {
        try {
            val baseOptions = com.google.mediapipe.tasks.core.BaseOptions.builder()
                .setModelAssetPath("face_landmarker.task")
                .build()
            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumFaces(1)
                .build()
            FaceLandmarker.createFromOptions(context, options)
        } catch (t: Throwable) {
            android.util.Log.e("MediaPipeHolistic", "Failed to init FaceLandmarker", t)
            null
        }
    }

    /**
     * Runs all three landmarkers on [bitmap] and returns a FloatArray of
     * length 1662. Missing landmarks are zero-filled so the feature vector
     * stays consistent with the training data.
     */
    fun extract(bitmap: android.graphics.Bitmap): FloatArray {
        val out = FloatArray(FEATURE_LENGTH)
        val mpImage: MPImage = BitmapImageBuilder(bitmap).build()

        // Pose (132 floats: x, y, z, visibility)
        val pose = poseLandmarker?.detect(mpImage)
        val poseLandmarks = pose?.landmarks()?.firstOrNull()
        if (poseLandmarks != null) {
            for (i in 0 until minOf(33, poseLandmarks.size)) {
                val lm = poseLandmarks[i]
                val base = i * 4
                out[base] = lm.x()
                out[base + 1] = lm.y()
                out[base + 2] = lm.z()
                out[base + 3] = lm.visibility().orElse(0f)
            }
        }

        // Face (1404 floats: x, y, z)
        val face = faceLandmarker?.detect(mpImage)
        val faceLandmarks = face?.faceLandmarks()?.firstOrNull()
        if (faceLandmarks != null) {
            for (i in 0 until minOf(468, faceLandmarks.size)) {
                val lm = faceLandmarks[i]
                val base = POSE_LENGTH + i * 3
                out[base] = lm.x()
                out[base + 1] = lm.y()
                out[base + 2] = lm.z()
            }
        }

        // Hands (2 hands x 63 floats: x, y, z). Sort by wrist x to assign
        // left/right, matching the training convention.
        val hands = handLandmarker?.detect(mpImage)
        val handLandmarks = hands?.landmarks() ?: emptyList()
        val sorted = handLandmarks.sortedBy { it.firstOrNull()?.x() ?: Float.MAX_VALUE }
        // sorted[0] is the leftmost hand (smallest x); sorted[1] is the right.
        val leftHand = sorted.getOrNull(0)
        val rightHand = sorted.getOrNull(1)
        val leftBase = POSE_LENGTH + FACE_LENGTH
        val rightBase = leftBase + HAND_LENGTH
        if (leftHand != null) {
            for (i in 0 until minOf(21, leftHand.size)) {
                val lm = leftHand[i]
                val base = leftBase + i * 3
                out[base] = lm.x()
                out[base + 1] = lm.y()
                out[base + 2] = lm.z()
            }
        }
        if (rightHand != null) {
            for (i in 0 until minOf(21, rightHand.size)) {
                val lm = rightHand[i]
                val base = rightBase + i * 3
                out[base] = lm.x()
                out[base + 1] = lm.y()
                out[base + 2] = lm.z()
            }
        }

        return out
    }

    fun close() {
        try { poseLandmarker?.close() } catch (_: Throwable) {}
        try { handLandmarker?.close() } catch (_: Throwable) {}
        try { faceLandmarker?.close() } catch (_: Throwable) {}
    }
}
