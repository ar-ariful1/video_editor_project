package com.clipcut.app

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class AudioMixer {

    companion object {
        const val SAMPLE_RATE = 44100
        const val CHANNELS = 2
        const val BYTES_PER_SAMPLE = 2
        const val FRAME_BYTES = CHANNELS * BYTES_PER_SAMPLE // 4 bytes per stereo frame
    }

    data class AudioStream(
        val data: ByteArray,
        val volume: Float,
        val startTimeUs: Long,
        val sampleRate: Int = SAMPLE_RATE,
        val channels: Int = CHANNELS
    )

    fun mix(
        streams: List<AudioStream>,
        windowStartUs: Long,
        windowDurationUs: Long
    ): ByteArray {

        val outSamples = maxOf(1, ((windowDurationUs * SAMPLE_RATE) / 1_000_000L).toInt())
        val outBytes = ByteArray(outSamples * FRAME_BYTES)

        val mixL = FloatArray(outSamples)
        val mixR = FloatArray(outSamples)

        val windowEndUs = windowStartUs + windowDurationUs

        for (stream in streams) {
            val bytesPerFrame = stream.channels * BYTES_PER_SAMPLE
            if (bytesPerFrame <= 0 || stream.data.isEmpty()) continue

            val streamSamples = stream.data.size / bytesPerFrame
            val streamDurationUs = (streamSamples.toLong() * 1_000_000L) / maxOf(1, stream.sampleRate)
            val streamEndUs = stream.startTimeUs + streamDurationUs

            if (streamEndUs <= windowStartUs || stream.startTimeUs >= windowEndUs) continue

            val overlapStartUs = max(windowStartUs, stream.startTimeUs)
            val overlapEndUs = min(windowEndUs, streamEndUs)

            val outStartSample = (((overlapStartUs - windowStartUs) * SAMPLE_RATE) / 1_000_000L).toInt()
            val overlapSamples = (((overlapEndUs - overlapStartUs) * SAMPLE_RATE) / 1_000_000L).toInt()

            val sourceStartSample = (((overlapStartUs - stream.startTimeUs) * stream.sampleRate) / 1_000_000L).toDouble()

            for (i in 0 until overlapSamples) {
                val outIndex = outStartSample + i
                if (outIndex >= outSamples) break

                val srcPos = sourceStartSample + (i.toDouble() * stream.sampleRate.toDouble() / SAMPLE_RATE.toDouble())
                val idx1 = srcPos.toInt()
                val idx2 = idx1 + 1
                val frac = (srcPos - idx1).toFloat()

                val s1L = readSample(stream.data, idx1, stream.channels, 0)
                val s1R = if (stream.channels == 2) readSample(stream.data, idx1, stream.channels, 1) else s1L
                val s2L = readSample(stream.data, idx2, stream.channels, 0)
                val s2R = if (stream.channels == 2) readSample(stream.data, idx2, stream.channels, 1) else s2L

                mixL[outIndex] += (s1L + (s2L - s1L) * frac) * stream.volume
                mixR[outIndex] += (s1R + (s2R - s1R) * frac) * stream.volume
            }
        }

        var peak = 0f
        for (i in 0 until outSamples) {
            peak = max(peak, abs(mixL[i]))
            peak = max(peak, abs(mixR[i]))
        }

        val scale = if (peak > 32767f) 32767f / peak else 1.0f

        val outBuffer = ByteBuffer.wrap(outBytes).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until outSamples) {
            val l = (mixL[i] * scale).coerceIn(-32768f, 32767f).toInt().toShort()
            val r = (mixR[i] * scale).coerceIn(-32768f, 32767f).toInt().toShort()
            outBuffer.putShort(i * 4, l)
            outBuffer.putShort(i * 4 + 2, r)
        }

        return outBytes
    }

    private fun readSample(data: ByteArray, sampleIndex: Int, channels: Int, channel: Int): Float {
        if (sampleIndex < 0) return 0f

        val byteIndex = when (channels) {
            2 -> sampleIndex * 4 + channel * 2
            else -> sampleIndex * 2
        }

        if (byteIndex < 0 || byteIndex + 1 >= data.size) return 0f

        val lo = data[byteIndex].toInt() and 0xFF
        val hi = data[byteIndex + 1].toInt()
        val value = (hi shl 8) or lo
        return value.toShort().toFloat()
    }
}