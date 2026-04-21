package com.clipcut.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.io.ByteArrayOutputStream

class AudioClipDecoder(private val path: String) {

    private var extractor: MediaExtractor? = null
    private var decoder: MediaCodec? = null
    private var isEOS = false
    private val bufferInfo = MediaCodec.BufferInfo()

    private val pending = ByteArrayOutputStream()

    fun setup() {
        extractor = MediaExtractor()
        extractor?.setDataSource(path)

        val trackIndex = selectAudioTrack(extractor!!)
        if (trackIndex < 0) {
            throw RuntimeException("No audio track found in $path")
        }

        val format = extractor!!.getTrackFormat(trackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: throw RuntimeException("Missing audio mime")

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

    fun decodeNextPCM(requestedSize: Int): ByteArray {
        val codec = decoder ?: return ByteArray(requestedSize)
        val ex = extractor ?: return ByteArray(requestedSize)

        val output = ByteArray(requestedSize)
        var copied = 0

        // Consume pending bytes first.
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

        while (copied < requestedSize && !isEOS) {
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

            val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
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
                            copied = requestedSize
                            pending.write(chunk, remainingNeeded, chunk.size - remainingNeeded)
                        }
                    }

                    codec.releaseOutputBuffer(outIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        isEOS = true
                    }
                }

                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (isEOS) break
                }
            }
        }

        return output
    }

    fun seekTo(timeUs: Long) {
        extractor?.seekTo(timeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        decoder?.flush()
        pending.reset()
        isEOS = false
    }

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

        decoder = null
        extractor = null
    }
}