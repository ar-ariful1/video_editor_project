package com.clipcut.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.opengl.GLES30
import android.opengl.Matrix
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val NATIVE_ENGINE_CHANNEL = "com.clipcut.app/native_engine"
    private val PROGRESS_CHANNEL = "com.clipcut.app/export_progress"

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var progressSink: EventChannel.EventSink? = null
    private var exportJob: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    progressSink = sink
                }

                override fun onCancel(args: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_ENGINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startExport" -> {
                        val outputPath = call.argument<String>("outputPath").orEmpty()
                        val width = call.argument<Int>("width") ?: 1080
                        val height = call.argument<Int>("height") ?: 1920
                        val project = rawMap(call.argument<Any?>("project"))

                        if (outputPath.isBlank() || project.isEmpty()) {
                            result.error("INVALID_DATA", "Output path or project is missing", null)
                            return@setMethodCallHandler
                        }

                        exportJob?.cancel()
                        exportJob = scope.launch(Dispatchers.IO) {
                            runExportPipeline(outputPath, width, height, project, result)
                        }
                    }

                    "cancelExport" -> {
                        exportJob?.cancel()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private suspend fun runExportPipeline(
        outputPath: String,
        width: Int,
        height: Int,
        project: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        val exporter = NativeVideoExporter()
        val renderer = GLRenderEngine()
        val videoDecoders = mutableMapOf<String, VideoClipDecoder>()
        val audioDecoders = mutableMapOf<String, AudioClipDecoder>()
        val textureCache = mutableMapOf<String, Int>()
        val mixer = AudioMixer()

        try {
            val fps = (project["fps"] as? Number)?.toInt() ?: 30
            val qualityName = (project["quality"] as? String) ?: "STANDARD"
            val quality = runCatching {
                NativeVideoExporter.QualityPreset.valueOf(qualityName)
            }.getOrElse { NativeVideoExporter.QualityPreset.STANDARD }

            // Serialize project map to JSON for the C++ Engine
            val projectJson = JSONObject(project as Map<*, *>).toString()
            exporter.setup(outputPath, width, height, fps, quality, projectJson)
            renderer.initGL(exporter.getInputSurface() ?: throw RuntimeException("Encoder surface missing"))

            val tracks = toMapList(project["tracks"])
                .sortedBy { (it["zIndex"] as? Number)?.toInt() ?: 0 }

            val durationSec = (project["duration"] as? Number)?.toDouble() ?: 0.0
            val totalFrames = maxOf(1, (durationSec * fps).toInt())
            val frameDurationUs = (1_000_000L / maxOf(1, fps))

            for (frameIndex in 0 until totalFrames) {
                if (!isActive(exportJob)) break

                val currentTimeUs = (frameIndex.toLong() * 1_000_000L) / fps
                val currentTimeSec = currentTimeUs / 1_000_000.0

                renderer.clear()
                
                // 1. Render through C++ Engine (Z-index, Keyframes, and GPU Effects)
                exporter.renderFrame(currentTimeUs)

                // 2. Fallback / Mixed Kotlin Render for additional overlays (like Text)
                for (track in tracks) {
                    val clips = toMapList(track["clips"])
                    for (index in clips.indices) {
                        val clip = clips[index]
                        val start = (clip["startTime"] as? Number)?.toDouble() ?: continue
                        val end = (clip["endTime"] as? Number)?.toDouble() ?: continue

                        if (currentTimeSec in start..end) {
                            try {
                                renderClip(
                                    clip = clip,
                                    timeSec = currentTimeSec,
                                    startSec = start,
                                    endSec = end,
                                    index = index,
                                    clips = clips,
                                    renderer = renderer,
                                    videoDecoders = videoDecoders,
                                    textureCache = textureCache,
                                    width = width,
                                    height = height
                                )
                            } catch (e: Exception) {
                                Log.e("NativeEngine", "Clip render failed: ${e.message}", e)
                            }
                        }
                    }
                }

                renderer.swapBuffers()
                exporter.drainVideo(false)

                val pcmStreams = mutableListOf<AudioMixer.AudioStream>()

                for (track in tracks) {
                    val clips = toMapList(track["clips"])
                    for (clip in clips) {
                        val start = (clip["startTime"] as? Number)?.toDouble() ?: continue
                        val end = (clip["endTime"] as? Number)?.toDouble() ?: continue
                        val mute = clip["mute"] as? Boolean ?: false
                        if (mute) continue

                        if (currentTimeSec in start..end) {
                            val path = clip["mediaPath"] as? String ?: continue
                            val decoder = audioDecoders.getOrPut(path) {
                                AudioClipDecoder(path).apply { setup() }
                            }

                            val requestedSize = maxOf(4, ((frameDurationUs * 44100L) / 1_000_000L).toInt() * 4)
                            val pcm = decoder.decodeNextPCM(requestedSize)

                            pcmStreams.add(
                                AudioMixer.AudioStream(
                                    data = pcm,
                                    volume = (clip["volume"] as? Number)?.toFloat() ?: 1.0f,
                                    startTimeUs = (start * 1_000_000L).toLong()
                                )
                            )
                        }
                    }
                }

                if (pcmStreams.isNotEmpty()) {
                    val mixedPcm = mixer.mix(pcmStreams, currentTimeUs, frameDurationUs)
                    exporter.drainAudio(mixedPcm)
                }

                if (frameIndex % 15 == 0) {
                    withContext(Dispatchers.Main) {
                        progressSink?.success(((frameIndex.toFloat() / totalFrames.toFloat()) * 100f).toInt())
                    }
                }
            }

            exporter.drainVideo(true)

            withContext(Dispatchers.Main) {
                progressSink?.success(100)
                result.success(outputPath)
            }
        } catch (e: CancellationException) {
            withContext(Dispatchers.Main) {
                result.error("EXPORT_CANCELLED", "Export cancelled", null)
            }
        } catch (e: Exception) {
            Log.e("NativeEngine", "Export failed", e)
            withContext(Dispatchers.Main) {
                result.error("EXPORT_FAILED", e.message, null)
            }
        } finally {
            try {
                renderer.deleteTextures(textureCache.values)
            } catch (_: Exception) {}

            videoDecoders.values.forEach { runCatching { it.release() } }
            audioDecoders.values.forEach { runCatching { it.release() } }

            runCatching { exporter.release() }
            runCatching { renderer.release() }
        }
    }

    private fun renderClip(
        clip: Map<String, Any?>,
        timeSec: Double,
        startSec: Double,
        endSec: Double,
        index: Int,
        clips: List<Map<String, Any?>>,
        renderer: GLRenderEngine,
        videoDecoders: MutableMap<String, VideoClipDecoder>,
        textureCache: MutableMap<String, Int>,
        width: Int,
        height: Int
    ) {
        val type = ((clip["mediaType"] ?: clip["type"]) as? String ?: "video").lowercase()
        val opacity = (clip["opacity"] as? Number)?.toFloat() ?: 1.0f
        val brightness = (clip["brightness"] as? Number)?.toFloat() ?: 0f
        val contrast = (clip["contrast"] as? Number)?.toFloat() ?: 1f
        val saturation = (clip["saturation"] as? Number)?.toFloat() ?: 1f
        val scale = (clip["scale"] as? Number)?.toFloat() ?: 1f
        val rotation = (clip["rotation"] as? Number)?.toFloat() ?: 0f
        val x = (clip["x"] as? Number)?.toFloat() ?: 0f
        val y = (clip["y"] as? Number)?.toFloat() ?: 0f

        val matrix = FloatArray(16)
        Matrix.setIdentityM(matrix, 0)
        Matrix.translateM(matrix, 0, x, y, 0f)
        Matrix.rotateM(matrix, 0, rotation, 0f, 0f, 1f)
        Matrix.scaleM(matrix, 0, scale, scale, 1f)

        if (type == "video" || type == "audio" || type == "clip") {
            val path = clip["mediaPath"] as? String ?: return
            val decoder = videoDecoders.getOrPut(path) {
                VideoClipDecoder(path).apply {
                    setup(renderer.generateExternalTexture())
                }
            }

            val localTimeUs = ((timeSec - startSec) * 1_000_000L).toLong()

            var nextTexId = -1
            var transitionType = 0
            var transitionProgress = 0f

            val transition = rawMap(clip["transition"])
            if (transition.isNotEmpty()) {
                val transitionDuration = (transition["duration"] as? Number)?.toDouble() ?: 0.0
                if (transitionDuration > 0.0 && timeSec > (endSec - transitionDuration)) {
                    transitionType = (transition["type"] as? Number)?.toInt() ?: 1
                    transitionProgress = ((timeSec - (endSec - transitionDuration)) / transitionDuration).toFloat().coerceIn(0f, 1f)

                    if (index + 1 < clips.size) {
                        val nextPath = clips[index + 1]["mediaPath"] as? String
                        if (!nextPath.isNullOrBlank()) {
                            val nextDecoder = videoDecoders.getOrPut(nextPath) {
                                VideoClipDecoder(nextPath).apply {
                                    setup(renderer.generateExternalTexture())
                                }
                            }
                            nextDecoder.decodeToFrame(0L)
                            nextTexId = nextDecoder.getTextureId()
                        }
                    }
                }
            }

            if (decoder.decodeToFrame(localTimeUs)) {
                renderer.renderVideoLayer(
                    textureId = decoder.getTextureId(),
                    matrix = matrix,
                    opacity = opacity,
                    brightness = brightness,
                    contrast = contrast,
                    saturation = saturation,
                    nextTextureId = nextTexId,
                    transitionType = transitionType,
                    transitionProgress = transitionProgress
                )
            }
        } else if (type == "text") {
            val text = (clip["text"] as? String)
                ?: (clip["textContent"] as? String)
                ?: ""

            val cacheKey = "TXT_${text}_${clip.hashCode()}"
            val texId = textureCache.getOrPut(cacheKey) {
                val bmp = createTextBitmap(text, width, height, clip)
                renderer.generate2DTexture(bmp)
            }

            renderer.renderOverlayLayer(texId, matrix, opacity)
        }
    }

    private fun createTextBitmap(
        text: String,
        width: Int,
        height: Int,
        clip: Map<String, Any?>
    ): Bitmap {
        val fontSize = (clip["fontSize"] as? Number)?.toFloat() ?: 64f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = fontSize
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }

        val textWidth = maxOf(1, paint.measureText(text).toInt() + 40)
        val textHeight = maxOf(1, (paint.descent() - paint.ascent()).toInt() + 40)
        val bitmap = Bitmap.createBitmap(textWidth, textHeight, Bitmap.Config.ARGB_8888)

        val canvas = Canvas(bitmap)
        val x = textWidth / 2f
        val y = (textHeight / 2f) - ((paint.descent() + paint.ascent()) / 2f)
        canvas.drawText(text, x, y, paint)

        return bitmap
    }

    private fun rawMap(value: Any?): Map<String, Any?> {
        val map = value as? Map<*, *> ?: return emptyMap()
        return map.entries.associate { (k, v) -> k.toString() to v }
    }

    private fun toMapList(value: Any?): List<Map<String, Any?>> {
        val list = value as? List<*> ?: return emptyList()
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            map.entries.associate { (k, v) -> k.toString() to v }
        }
    }

    private fun isActive(job: Job?): Boolean = job?.isActive == true

    override fun onDestroy() {
        super.onDestroy()
        exportJob?.cancel()
        scope.cancel()
    }
}