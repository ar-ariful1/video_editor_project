package com.clipcut.app

import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import android.view.Surface

class VideoClipDecoder(private val path: String) {

    private var extractor: MediaExtractor? = null
    private var decoder: MediaCodec? = null
    private var surfaceTexture: SurfaceTexture? = null
    private var surface: Surface? = null
    private var textureId: Int = -1

    private val bufferInfo = MediaCodec.BufferInfo()
    private var isEOS = false
    private var lastDecodedTimeUs = -1L

    fun setup(texId: Int) {
        textureId = texId
        surfaceTexture = SurfaceTexture(texId)
        surface = Surface(surfaceTexture)

        extractor = MediaExtractor()
        extractor?.setDataSource(path)

        val trackIndex = selectVideoTrack(extractor!!)
        if (trackIndex < 0) {
            throw RuntimeException("No video track found in $path")
        }

        val format = extractor!!.getTrackFormat(trackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: throw RuntimeException("Missing video mime")

        decoder = MediaCodec.createDecoderByType(mime).apply {
            configure(format, surface, null, 0)
            start()
        }

        extractor?.selectTrack(trackIndex)
        isEOS = false
        lastDecodedTimeUs = -1L
    }

    private fun selectVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("video/") == true) return i
        }
        return -1
    }

    fun decodeToFrame(targetTimeUs: Long): Boolean {
        val codec = decoder ?: return false
        val ex = extractor ?: return false

        if (targetTimeUs < lastDecodedTimeUs) {
            ex.seekTo(targetTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            codec.flush()
            isEOS = false
        }

        var attempts = 0
        while (attempts < 60) {
            if (!isEOS) {
                val inIndex = codec.dequeueInputBuffer(10_000)
                if (inIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inIndex)
                    val size = inputBuffer?.let { ex.readSampleData(it, 0) } ?: -1

                    if (size < 0) {
                        codec.queueInputBuffer(
                            inIndex,
                            0,
                            0,
                            0,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        isEOS = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, size, ex.sampleTime, 0)
                        ex.advance()
                    }
                }
            }

            val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outIndex >= 0 -> {
                    val render = bufferInfo.presentationTimeUs >= (targetTimeUs - 15_000)
                    codec.releaseOutputBuffer(outIndex, render)

                    if (render) {
                        try {
                            surfaceTexture?.updateTexImage()
                        } catch (e: Exception) {
                            Log.e("VideoClipDecoder", "updateTexImage failed: ${e.message}")
                        }
                        lastDecodedTimeUs = bufferInfo.presentationTimeUs
                        return true
                    }
                }

                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (isEOS) return false
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