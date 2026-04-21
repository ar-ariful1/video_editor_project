// android/app/src/main/kotlin/com/clipcut/app/AudioClipDecoder.kt
package com.clipcut.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.ByteArrayOutputStream

class AudioClipDecoder(private val path: String) {

    companion object {
        private const val TAG = "AudioClipDecoder"
        private const val TIMEOUT_US = 10000L
    }

    private var extractor: MediaExtractor? = null
    private var decoder: MediaCodec? = null
    private var isEOS = false
    private val bufferInfo = MediaCodec.BufferInfo()

    private val pending = ByteArrayOutputStream()
    private var audioSampleRate = 44100
    private var audioChannels = 2

    @Throws(RuntimeException::class)
    fun setup() {
        extractor = MediaExtractor().apply {
            setDataSource(path)
        }

        val trackIndex = selectAudioTrack(extractor!!)
        if (trackIndex < 0) {
            throw RuntimeException("No audio track found in $path")
        }

        val format = extractor!!.getTrackFormat(trackIndex)
        audioSampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        audioChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val mime = format.getString(MediaFormat.KEY_MIME)
            ?: throw RuntimeException("Missing audio mime")

        decoder = MediaCodec.createDecoderByType(mime).apply {
            configure(format, null, null, 0)
            start()
        }

        extractor?.selectTrack(trackIndex)
        isEOS = false
        pending.reset()
    }

    private fun selectAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) return i
        }
        return -1
    }

    fun getSampleRate(): Int = audioSampleRate
    fun getChannelCount(): Int = audioChannels

    /**
     * Decode and return the requested amount of PCM bytes.
     * If EOF is reached, the returned array will be filled with zeros for the remaining space.
     */
    fun decodeNextPCM(requestedSize: Int): ByteArray {
        val codec = decoder ?: return ByteArray(requestedSize)
        val ex = extractor ?: return ByteArray(requestedSize)

        val output = ByteArray(requestedSize)
        var copied = 0

        // First, consume pending bytes from previous decode
        if (pending.size() > 0) {
            val pendingBytes = pending.toByteArray()
            val toCopy = minOf(requestedSize, pendingBytes.size)
            System.arraycopy(pendingBytes, 0, output, 0, toCopy)
            copied = toCopy

            pending.reset()
            if (toCopy < pendingBytes.size) {
                pending.write(pendingBytes, toCopy, pendingBytes.size - toCopy)
            }
        }

        // Keep decoding until we have enough data or EOS
        while (copied < requestedSize && !isEOS) {
            // Feed input buffer if we can
            val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inIndex)
                val sampleSize = inputBuffer?.let { ex.readSampleData(it, 0) } ?: -1

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

            // Get decoded output
            val outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
            when {
                outIndex >= 0 -> {
                    val outputBuffer = codec.getOutputBuffer(outIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        outputBuffer.get(chunk)

                        val remainingNeeded = requestedSize - copied
                        if (chunk.size <= remainingNeeded) {
                            System.arraycopy(chunk, 0, output, copied, chunk.size)
                            copied += chunk.size
                        } else {
                            System.arraycopy(chunk, 0, output, copied, remainingNeeded)
                            copied += remainingNeeded
                            pending.write(chunk, remainingNeeded, chunk.size - remainingNeeded)
                        }
                    }

                    codec.releaseOutputBuffer(outIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        isEOS = true
                    }
                }

                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    // No output ready yet, loop again
                    if (isEOS) break
                }

                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // Format changed, but we don't need to handle for PCM output
                }
            }
        }

        // If we didn't get enough data (EOS reached), the remainder stays zero
        return output
    }

    fun seekTo(timeUs: Long) {
        extractor?.seekTo(timeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        decoder?.flush()
        pending.reset()
        isEOS = false
    }

    fun release() {
        runCatching { decoder?.stop() }
        runCatching { decoder?.release() }
        runCatching { extractor?.release() }

        decoder = null
        extractor = null
    }
}