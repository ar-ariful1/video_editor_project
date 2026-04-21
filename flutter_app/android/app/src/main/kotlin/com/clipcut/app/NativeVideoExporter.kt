// NativeVideoExporter.kt
package com.clipcut.app

import android.media.*
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer

class NativeVideoExporter(
    private val outputFile: File,
    private val videoWidth: Int,
    private val videoHeight: Int,
    private val frameRate: Int = 30,
    private val bitRate: Int = 8000000
) {
    private var muxer: MediaMuxer? = null
    private var videoEncoder: MediaCodec? = null
    private var audioEncoder: MediaCodec? = null
    private var audioExtractor: MediaExtractor? = null

    private var videoTrackIndex = -1
    private var audioTrackIndex = -1

    private var muxerStarted = false
    private val bufferInfo = MediaCodec.BufferInfo()

    private lateinit var handlerThread: HandlerThread
    private lateinit var handler: Handler

    private var exportCallback: ExportCallback? = null

    interface ExportCallback {
        fun onProgress(percent: Float)
        fun onCompleted()
        fun onError(error: String)
    }

    fun setCallback(callback: ExportCallback) {
        this.exportCallback = callback
    }

    fun startExport(videoInputSurface: Surface, audioSourcePath: String? = null) {
        handlerThread = HandlerThread("ExportThread")
        handlerThread.start()
        handler = Handler(handlerThread.looper)

        handler.post {
            try {
                setupMuxer()
                setupVideoEncoder(videoInputSurface)
                setupAudioEncoder(audioSourcePath)
                startEncodingLoop()
            } catch (e: Exception) {
                Log.e("NativeVideoExporter", "Export failed", e)
                exportCallback?.onError(e.message ?: "Unknown error")
                release()
            }
        }
    }

    private fun setupMuxer() {
        muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    private fun setupVideoEncoder(inputSurface: Surface) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, videoWidth, videoHeight)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)

        videoEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoEncoder?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        videoEncoder?.setInputSurface(inputSurface)
        videoEncoder?.start()
    }

    private fun setupAudioEncoder(audioSourcePath: String?) {
        if (audioSourcePath == null || !File(audioSourcePath).exists()) return

        audioExtractor = MediaExtractor()
        audioExtractor?.setDataSource(audioSourcePath)
        val audioTrack = selectAudioTrack(audioExtractor!!)
        if (audioTrack < 0) return
        audioExtractor?.selectTrack(audioTrack)

        val audioFormat = audioExtractor!!.getTrackFormat(audioTrack)
        val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: return

        audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        val encodeFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC,
            audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE),
            audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
        encodeFormat.setInteger(MediaFormat.KEY_BIT_RATE, 128000)
        encodeFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 4096)

        audioEncoder?.configure(encodeFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioEncoder?.start()
    }

    private fun selectAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) return i
        }
        return -1
    }

    private fun startEncodingLoop() {
        var videoEOS = false
        var audioEOS = (audioEncoder == null)

        val totalDurationUs = 0L // You'd compute from timeline, here we use unknown duration
        var lastProgress = 0f

        while (!videoEOS || !audioEOS) {
            // Drain video encoder
            videoEncoder?.let { encoder ->
                var outIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                while (outIndex >= 0 || outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (!muxerStarted) {
                            videoTrackIndex = muxer?.addTrack(encoder.outputFormat) ?: -1
                            if (audioTrackIndex != -1 || audioEncoder == null) {
                                muxer?.start()
                                muxerStarted = true
                            }
                        }
                    } else if (outIndex >= 0) {
                        val encodedData = encoder.getOutputBuffer(outIndex)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            encoder.releaseOutputBuffer(outIndex, false)
                        } else {
                            if (muxerStarted && videoTrackIndex != -1) {
                                muxer?.writeSampleData(videoTrackIndex, encodedData!!, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outIndex, false)
                            // Update progress based on timestamp
                            if (totalDurationUs > 0) {
                                val progress = bufferInfo.presentationTimeUs.toFloat() / totalDurationUs
                                if (progress - lastProgress > 0.01f) {
                                    lastProgress = progress
                                    exportCallback?.onProgress(progress)
                                }
                            }
                        }
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            videoEOS = true
                        }
                    }
                    outIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                }
            }

            // Feed audio encoder
            audioEncoder?.let { encoder ->
                if (!audioEOS) {
                    val inIndex = encoder.dequeueInputBuffer(10000)
                    if (inIndex >= 0) {
                        val inputBuffer = encoder.getInputBuffer(inIndex)
                        val sampleSize = audioExtractor?.readSampleData(inputBuffer!!, 0) ?: -1
                        if (sampleSize < 0) {
                            encoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            audioEOS = true
                        } else {
                            val pts = audioExtractor!!.sampleTime
                            encoder.queueInputBuffer(inIndex, 0, sampleSize, pts, 0)
                            audioExtractor!!.advance()
                        }
                    }
                }

                var outIndex = encoder.dequeueOutputBuffer(bufferInfo, 10000)
                while (outIndex >= 0 || outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (!muxerStarted) {
                            audioTrackIndex = muxer?.addTrack(encoder.outputFormat) ?: -1
                            if (videoTrackIndex != -1) {
                                muxer?.start()
                                muxerStarted = true
                            }
                        }
                    } else if (outIndex >= 0) {
                        val encodedData = encoder.getOutputBuffer(outIndex)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            if (muxerStarted && audioTrackIndex != -1) {
                                muxer?.writeSampleData(audioTrackIndex, encodedData!!, bufferInfo)
                            }
                        }
                        encoder.releaseOutputBuffer(outIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            audioEOS = true
                        }
                    }
                    outIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                }
            }
        }

        release()
        exportCallback?.onCompleted()
    }

    fun release() {
        try {
            muxer?.stop()
        } catch (_: Exception) {}
        try {
            muxer?.release()
        } catch (_: Exception) {}
        try {
            videoEncoder?.stop()
        } catch (_: Exception) {}
        try {
            videoEncoder?.release()
        } catch (_: Exception) {}
        try {
            audioEncoder?.stop()
        } catch (_: Exception) {}
        try {
            audioEncoder?.release()
        } catch (_: Exception) {}
        try {
            audioExtractor?.release()
        } catch (_: Exception) {}
        handlerThread.quitSafely()
    }
}