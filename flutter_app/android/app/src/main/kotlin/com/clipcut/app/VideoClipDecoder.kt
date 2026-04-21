// VideoClipDecoder.kt
package com.clipcut.app

import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import android.view.Surface
import java.io.IOException

class VideoClipDecoder(private val path: String) {

    private var extractor: MediaExtractor? = null
    private var decoder: MediaCodec? = null
    private var surface: Surface? = null

    // SurfaceTexture and associated OpenGL texture ID
    private var surfaceTexture: SurfaceTexture? = null
    private var textureId: Int = -1

    private val bufferInfo = MediaCodec.BufferInfo()
    private var isEOS = false
    private var lastDecodedTimeUs = -1L

    // Video metadata
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var frameRate: Float = 30f
    private var durationUs: Long = 0L
    private var videoTrackIndex: Int = -1

    companion object {
        private const val TAG = "VideoClipDecoder"
        private const val TIMEOUT_US = 10000L
    }

    @Throws(IOException::class)
    fun setup(texId: Int) {
        textureId = texId
        surfaceTexture = SurfaceTexture(texId)
        surface = Surface(surfaceTexture)

        extractor = MediaExtractor()
        extractor?.setDataSource(path)

        videoTrackIndex = selectVideoTrack(extractor!!)
        if (videoTrackIndex < 0) {
            throw RuntimeException("No video track found in $path")
        }

        extractor?.selectTrack(videoTrackIndex)
        val format = extractor!!.getTrackFormat(videoTrackIndex)

        // Extract metadata
        videoWidth = format.getInteger(MediaFormat.KEY_WIDTH)
        videoHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
        durationUs = format.getLong(MediaFormat.KEY_DURATION)
        if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
            frameRate = format.getInteger(MediaFormat.KEY_FRAME_RATE).toFloat()
        } else {
            frameRate = 30f
        }

        val mime = format.getString(MediaFormat.KEY_MIME)
            ?: throw RuntimeException("Missing video mime")

        decoder = MediaCodec.createDecoderByType(mime)
        decoder?.configure(format, surface, null, 0)
        decoder?.start()

        // Set SurfaceTexture to default buffer size based on video dimensions
        surfaceTexture?.setDefaultBufferSize(videoWidth, videoHeight)

        isEOS = false
        lastDecodedTimeUs = -1L
    }

    private fun selectVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("video/") == true) {
                return i
            }
        }
        return -1
    }

    fun getVideoWidth(): Int = videoWidth
    fun getVideoHeight(): Int = videoHeight
    fun getDurationUs(): Long = durationUs
    fun getFrameRate(): Float = frameRate

    /**
     * Decode until we have a frame at or just after targetTimeUs.
     * Returns true if a frame was rendered to the texture.
     */
    fun decodeToFrame(targetTimeUs: Long): Boolean {
        val codec = decoder ?: return false
        val ex = extractor ?: return false

        // If seeking backward or to a different position, perform seek
        if (targetTimeUs < lastDecodedTimeUs) {
            ex.seekTo(targetTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            codec.flush()
            isEOS = false
        }

        var attempts = 0
        while (attempts < 60) {  // prevent infinite loop
            // Feed input buffer
            if (!isEOS) {
                val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inIndex)
                    val sampleSize = ex.readSampleData(inputBuffer!!, 0)
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(
                            inIndex,
                            0,
                            0,
                            0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        isEOS = true
                    } else {
                        codec.queueInputBuffer(
                            inIndex,
                            0,
                            sampleSize,
                            ex.sampleTime,
                            0
                        )
                        ex.advance()
                    }
                }
            }

            // Get output buffer
            val outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
            when {
                outIndex >= 0 -> {
                    // If this frame's timestamp is >= target time, render it
                    val render = bufferInfo.presentationTimeUs >= (targetTimeUs - 15000)  // 15ms tolerance
                    codec.releaseOutputBuffer(outIndex, render)

                    if (render) {
                        try {
                            surfaceTexture?.updateTexImage()
                        } catch (e: Exception) {
                            Log.e(TAG, "updateTexImage failed: ${e.message}")
                        }
                        lastDecodedTimeUs = bufferInfo.presentationTimeUs
                        return true
                    }
                }
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (isEOS) return false
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val newFormat = codec.outputFormat
                    val newWidth = newFormat.getInteger(MediaFormat.KEY_WIDTH)
                    val newHeight = newFormat.getInteger(MediaFormat.KEY_HEIGHT)
                    if (newWidth != videoWidth || newHeight != videoHeight) {
                        videoWidth = newWidth
                        videoHeight = newHeight
                        surfaceTexture?.setDefaultBufferSize(videoWidth, videoHeight)
                    }
                }
                outIndex == MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> {
                    // Deprecated but handled for older APIs
                }
            }
            attempts++
        }
        return false
    }

    fun getTextureId(): Int = textureId

    fun release() {
        try {
            decoder?.stop()
        } catch (_: Exception) {}
        try {
            decoder?.release()
        } catch (_: Exception) {}
        try {
            extractor?.release()
        } catch (_: Exception) {}
        try {
            surface?.release()
        } catch (_: Exception) {}
        try {
            surfaceTexture?.release()
        } catch (_: Exception) {}

        decoder = null
        extractor = null
        surface = null
        surfaceTexture = null
    }
}