package com.clipcut.app

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import android.view.Surface

class NativeVideoExporter {

    enum class QualityPreset(val bitrateMultiplier: Float, val useHEVC: Boolean) {
        FAST(0.7f, false),
        STANDARD(1.0f, false),
        HIGH(1.5f, true),
        PRO_HEVC(2.2f, true)
    }

    private var videoEncoder: MediaCodec? = null
    private var audioEncoder: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null

    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var isMuxerStarted = false

    private val videoBufferInfo = MediaCodec.BufferInfo()
    private val audioBufferInfo = MediaCodec.BufferInfo()

    private var videoPtsUs = 0L
    private var audioPtsUs = 0L
    private var fps = 30

    companion object {
        init {
            try {
                System.loadLibrary("video_engine")
            } catch (e: Exception) {
                Log.e("NativeVideoExporter", "Failed to load video_engine: ${e.message}")
            }
        }
    }

    private external fun nInitEngine()
    private external fun nReleaseEngine()
    private external fun nUpdateTimeline(json: String)
    private external fun nProcessTimelineFrame(timeUs: Long)
    private external fun nSetOutputResolution(width: Int, height: Int)
    private external fun nApplyAISegmentation(textureId: Int)

    fun setup(path: String, width: Int, height: Int, fps: Int, quality: QualityPreset, projectJson: String) {
        this.fps = fps
        
        nInitEngine()
        nSetOutputResolution(width, height)
        nUpdateTimeline(projectJson)

        val videoMime = if (quality.useHEVC) {
            MediaFormat.MIMETYPE_VIDEO_HEVC
        } else {
            MediaFormat.MIMETYPE_VIDEO_AVC
        }

        val videoFormat = MediaFormat.createVideoFormat(videoMime, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, (width * height * fps * 0.12f * quality.bitrateMultiplier).toInt())
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        videoEncoder = MediaCodec.createEncoderByType(videoMime).apply {
            configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = createInputSurface()
            start()
        }

        val audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, 44100, 2).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, 192000)
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        }

        audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
            configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }

        muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        videoTrackIndex = -1
        audioTrackIndex = -1
        isMuxerStarted = false
        videoPtsUs = 0L
        audioPtsUs = 0L
    }

    fun getInputSurface(): Surface? = inputSurface

    fun renderFrame(timeUs: Long) {
        nProcessTimelineFrame(timeUs)
    }

    private fun tryStartMuxer() {
        if (!isMuxerStarted && videoTrackIndex != -1 && audioTrackIndex != -1) {
            muxer?.start()
            isMuxerStarted = true
        }
    }

    fun drainVideo(endOfStream: Boolean) {
        if (endOfStream) {
            try {
                videoEncoder?.signalEndOfInputStream()
            } catch (e: Exception) {
                Log.e("NativeVideoExporter", "signalEndOfInputStream failed: ${e.message}")
            }
        }

        while (true) {
            val index = videoEncoder?.dequeueOutputBuffer(videoBufferInfo, 10_000) ?: break

            when {
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    videoTrackIndex = muxer?.addTrack(videoEncoder!!.outputFormat) ?: -1
                    tryStartMuxer()
                }

                index >= 0 -> {
                    val outputBuffer = videoEncoder?.getOutputBuffer(index)
                    if (outputBuffer != null &&
                        videoBufferInfo.size > 0 &&
                        isMuxerStarted &&
                        (videoBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0)
                    ) {
                        outputBuffer.position(videoBufferInfo.offset)
                        outputBuffer.limit(videoBufferInfo.offset + videoBufferInfo.size)

                        val pts = videoPtsUs
                        videoPtsUs += 1_000_000L / maxOf(1, fps)
                        videoBufferInfo.presentationTimeUs = pts

                        muxer?.writeSampleData(videoTrackIndex, outputBuffer, videoBufferInfo)
                    }
                    videoEncoder?.releaseOutputBuffer(index, false)

                    if (videoBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }

                index == MediaCodec.INFO_TRY_AGAIN_LATER -> break
                else -> break
            }
        }
    }

    fun drainAudio(pcmData: ByteArray) {
        val encoder = audioEncoder ?: return

        val inputIndex = encoder.dequeueInputBuffer(10_000)
        if (inputIndex >= 0) {
            val inputBuffer = encoder.getInputBuffer(inputIndex)
            if (inputBuffer != null) {
                inputBuffer.clear()
                inputBuffer.put(pcmData)

                val pts = audioPtsUs
                val durationUs = ((pcmData.size / 4).toLong() * 1_000_000L) / 44100L
                audioPtsUs += durationUs

                encoder.queueInputBuffer(inputIndex, 0, pcmData.size, pts, 0)
            }
        }

        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(audioBufferInfo, 10_000)

            when {
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    audioTrackIndex = muxer?.addTrack(encoder.outputFormat) ?: -1
                    tryStartMuxer()
                }

                outputIndex >= 0 -> {
                    val outputBuffer = encoder.getOutputBuffer(outputIndex)
                    if (outputBuffer != null &&
                        audioBufferInfo.size > 0 &&
                        isMuxerStarted &&
                        (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0)
                    ) {
                        outputBuffer.position(audioBufferInfo.offset)
                        outputBuffer.limit(audioBufferInfo.offset + audioBufferInfo.size)
                        muxer?.writeSampleData(audioTrackIndex, outputBuffer, audioBufferInfo)
                    }
                    encoder.releaseOutputBuffer(outputIndex, false)
                }

                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> break
                else -> break
            }
        }
    }

    fun release() {
        nReleaseEngine()
        try {
            inputSurface?.release()
        } catch (_: Exception) {}

        try {
            videoEncoder?.stop()
        } catch (_: Exception) {}
        try {
            audioEncoder?.stop()
        } catch (_: Exception) {}

        try {
            videoEncoder?.release()
        } catch (_: Exception) {}
        try {
            audioEncoder?.release()
        } catch (_: Exception) {}

        try {
            if (isMuxerStarted) muxer?.stop()
        } catch (_: Exception) {}
        try {
            muxer?.release()
        } catch (_: Exception) {}

        videoEncoder = null
        audioEncoder = null
        muxer = null
        inputSurface = null
        videoTrackIndex = -1
        audioTrackIndex = -1
        isMuxerStarted = false
    }
}