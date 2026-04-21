// android/app/src/main/kotlin/com/clipcut/app/MainActivity.kt
package com.clipcut.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.SurfaceTexture
import android.graphics.Typeface
import android.opengl.Matrix
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val ENGINE_CHANNEL = "com.clipcut.app/native_engine"
        private const val PROGRESS_CHANNEL = "com.clipcut.app/export_progress"
    }

    // ==================== Flutter Engine Binding ====================
    private lateinit var textureRegistry: TextureRegistry

    // ==================== Preview Engine Components ====================
    private var previewTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var previewRenderEngine: GLRenderEngine? = null
    private var previewDecoder: VideoClipDecoder? = null
    private var previewVideoTextureId: Int = -1
    private var previewVideoPath: String? = null
    private var previewMetadata: VideoMetadata? = null

    // ==================== Playback State ====================
    private var isPlaying = false
    private var currentPlayTimeUs = 0L
    private val mainHandler = Handler(Looper.getMainLooper())
    private var playbackRunnable: Runnable? = null

    // ==================== Export Components ====================
    private val exportScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var exportJob: Job? = null
    private var progressSink: EventChannel.EventSink? = null

    // ==================== Lifecycle ====================
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        textureRegistry = flutterEngine!!.renderer
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ------------- Export Progress Event Channel -------------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    progressSink = sink
                }
                override fun onCancel(args: Any?) {
                    progressSink = null
                }
            })

        // ------------- Main Engine Method Channel -------------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENGINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        // -------- Lifecycle --------
                        "initialize" -> initializeEngine(result)
                        "release" -> releaseEngine(result)

                        // -------- Preview & Playback --------
                        "loadVideo" -> loadVideo(call, result)
                        "createVideoTexture" -> createVideoTexture(result)
                        "renderFrameAt" -> renderFrameAt(call, result)
                        "seekTo" -> seekTo(call, result)
                        "play" -> play(result)
                        "pause" -> pause(result)
                        "isPlaying" -> result.success(isPlaying)
                        "getVideoMetadata" -> getVideoMetadata(result)

                        // -------- Effects --------
                        "setBrightness" -> setBrightness(call, result)
                        "setContrast" -> setContrast(call, result)
                        "setSaturation" -> setSaturation(call, result)
                        "setOpacity" -> setOpacity(call, result)

                        // -------- Export --------
                        "startExport" -> startExport(call, result)
                        "cancelExport" -> cancelExport(result)

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Method call failed: ${call.method}", e)
                    result.error("ENGINE_ERROR", e.message, null)
                }
            }
    }

    // ==================== Engine Lifecycle ====================
    private fun initializeEngine(result: MethodChannel.Result) {
        // Lazy initialization; most components created on demand
        result.success(null)
    }

    private fun releaseEngine(result: MethodChannel.Result) {
        releasePreviewResources()
        exportJob?.cancel()
        exportScope.cancel()
        result.success(null)
    }

    private fun releasePreviewResources() {
        pause(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })

        runCatching { previewDecoder?.release() }
        runCatching { previewRenderEngine?.release() }
        runCatching { previewSurface?.release() }
        runCatching { previewTextureEntry?.release() }

        previewDecoder = null
        previewRenderEngine = null
        previewSurface = null
        previewTextureEntry = null
        previewVideoTextureId = -1
        previewVideoPath = null
        previewMetadata = null
    }

    // ==================== Preview Setup ====================
    private fun createVideoTexture(result: MethodChannel.Result) {
        try {
            // Release any existing preview resources
            releasePreviewResources()

            // Create new texture entry
            val entry = textureRegistry.createSurfaceTexture()
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(1920, 1080) // default, will be updated on video load
            val surface = Surface(surfaceTexture)

            // Initialize render engine
            val renderEngine = GLRenderEngine()
            renderEngine.initGL(surface)
            renderEngine.clear()
            renderEngine.swapBuffers()

            // Store references
            previewTextureEntry = entry
            previewSurface = surface
            previewRenderEngine = renderEngine

            result.success(entry.id())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create video texture", e)
            result.error("TEXTURE_ERROR", e.message, null)
        }
    }

    private fun loadVideo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path.isNullOrEmpty()) {
                result.error("INVALID_PATH", "Video path is required", null)
                return
            }

            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Video file not found: $path", null)
                return
            }

            // Ensure we have a render engine (if not, create a temporary one? Usually createVideoTexture called first)
            if (previewRenderEngine == null) {
                result.error("NO_RENDERER", "Call createVideoTexture first", null)
                return
            }

            // Release previous decoder
            previewDecoder?.release()

            // Create decoder and setup
            val decoder = VideoClipDecoder(path)
            val texId = previewRenderEngine!!.generateExternalTexture()
            decoder.setup(texId)

            // Get metadata
            val metadata = VideoMetadata(
                width = decoder.getVideoWidth(),
                height = decoder.getVideoHeight(),
                durationUs = decoder.getDurationUs(),
                frameRate = decoder.getFrameRate()
            )

            // Adjust surface texture buffer size to match video
            previewTextureEntry?.surfaceTexture()?.setDefaultBufferSize(metadata.width, metadata.height)
            previewRenderEngine?.setViewport(metadata.width, metadata.height)

            // Decode first frame
            decoder.decodeToFrame(0)
            previewTextureEntry?.surfaceTexture()?.updateTexImage()

            // Render first frame
            previewRenderEngine?.clear()
            previewRenderEngine?.renderVideoLayer(texId, previewRenderEngine!!.createIdentityMatrix())
            previewRenderEngine?.swapBuffers()

            // Store state
            previewDecoder = decoder
            previewVideoTextureId = texId
            previewVideoPath = path
            previewMetadata = metadata
            currentPlayTimeUs = 0L

            // Return metadata
            result.success(
                mapOf(
                    "width" to metadata.width,
                    "height" to metadata.height,
                    "durationUs" to metadata.durationUs,
                    "frameRate" to metadata.frameRate
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load video", e)
            result.error("LOAD_ERROR", e.message, null)
        }
    }

    private fun getVideoMetadata(result: MethodChannel.Result) {
        previewMetadata?.let {
            result.success(
                mapOf(
                    "width" to it.width,
                    "height" to it.height,
                    "durationUs" to it.durationUs,
                    "frameRate" to it.frameRate
                )
            )
        } ?: result.error("NO_VIDEO", "No video loaded", null)
    }

    // ==================== Frame Rendering ====================
    private fun renderFrameAt(call: MethodCall, result: MethodChannel.Result) {
        val timeUs = call.argument<Int>("timeUs")?.toLong() ?: 0L
        renderFrameInternal(timeUs)
        result.success(null)
    }

    private fun seekTo(call: MethodCall, result: MethodChannel.Result) {
        val timeUs = call.argument<Int>("timeUs")?.toLong() ?: 0L
        currentPlayTimeUs = timeUs
        renderFrameInternal(timeUs)
        result.success(null)
    }

    private fun renderFrameInternal(timeUs: Long) {
        val decoder = previewDecoder ?: return
        val renderEngine = previewRenderEngine ?: return
        val texId = previewVideoTextureId

        if (decoder.decodeToFrame(timeUs)) {
            previewTextureEntry?.surfaceTexture()?.updateTexImage()
            renderEngine.clear()
            // Apply current effect settings (stored in renderEngine or separate variables)
            renderEngine.renderVideoLayer(texId, renderEngine.createIdentityMatrix())
            renderEngine.swapBuffers()
            currentPlayTimeUs = timeUs
        }
    }

    // ==================== Playback Control ====================
    private fun play(result: MethodChannel.Result) {
        if (previewDecoder == null || previewMetadata == null) {
            result.error("NO_VIDEO", "No video loaded", null)
            return
        }
        isPlaying = true
        startPlaybackLoop()
        result.success(null)
    }

    private fun pause(result: MethodChannel.Result) {
        isPlaying = false
        playbackRunnable?.let { mainHandler.removeCallbacks(it) }
        playbackRunnable = null
        result.success(null)
    }

    private fun startPlaybackLoop() {
        if (!isPlaying) return
        val decoder = previewDecoder ?: return
        val metadata = previewMetadata ?: return

        val frameIntervalUs = (1_000_000 / metadata.frameRate).toLong()
        val nextTime = currentPlayTimeUs + frameIntervalUs

        // Loop if reached end
        val targetTime = if (nextTime >= metadata.durationUs) {
            0L
        } else {
            nextTime
        }

        if (decoder.decodeToFrame(targetTime)) {
            previewTextureEntry?.surfaceTexture()?.updateTexImage()
            previewRenderEngine?.clear()
            previewRenderEngine?.renderVideoLayer(previewVideoTextureId, previewRenderEngine!!.createIdentityMatrix())
            previewRenderEngine?.swapBuffers()
            currentPlayTimeUs = targetTime
        }

        // Schedule next frame
        playbackRunnable = Runnable { startPlaybackLoop() }
        mainHandler.postDelayed(playbackRunnable, (frameIntervalUs / 1000).toLong())
    }

    // ==================== Effects (Stubs - extend as needed) ====================
    // These can be implemented by storing values and passing to renderVideoLayer
    private var currentBrightness = 0f
    private var currentContrast = 1f
    private var currentSaturation = 1f
    private var currentOpacity = 1f

    private fun setBrightness(call: MethodCall, result: MethodChannel.Result) {
        currentBrightness = (call.argument<Double>("value") ?: 0.0).toFloat()
        // Re-render current frame with new setting
        renderFrameInternal(currentPlayTimeUs)
        result.success(null)
    }

    private fun setContrast(call: MethodCall, result: MethodChannel.Result) {
        currentContrast = (call.argument<Double>("value") ?: 1.0).toFloat()
        renderFrameInternal(currentPlayTimeUs)
        result.success(null)
    }

    private fun setSaturation(call: MethodCall, result: MethodChannel.Result) {
        currentSaturation = (call.argument<Double>("value") ?: 1.0).toFloat()
        renderFrameInternal(currentPlayTimeUs)
        result.success(null)
    }

    private fun setOpacity(call: MethodCall, result: MethodChannel.Result) {
        currentOpacity = (call.argument<Double>("value") ?: 1.0).toFloat()
        renderFrameInternal(currentPlayTimeUs)
        result.success(null)
    }

    // ==================== Export Pipeline ====================
    private fun startExport(call: MethodCall, result: MethodChannel.Result) {
        val outputPath = call.argument<String>("outputPath")
        val width = call.argument<Int>("width") ?: 1080
        val height = call.argument<Int>("height") ?: 1920
        val project = rawMap(call.argument<Any?>("project"))

        if (outputPath.isNullOrBlank() || project.isEmpty()) {
            result.error("INVALID_DATA", "Output path or project is missing", null)
            return
        }

        exportJob?.cancel()
        exportJob = exportScope.launch(Dispatchers.IO) {
            runExportPipeline(outputPath, width, height, project, result)
        }
    }

    private fun cancelExport(result: MethodChannel.Result) {
        exportJob?.cancel()
        result.success(true)
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
                exporter.renderFrame(currentTimeUs)

                // Render clips
                for (track in tracks) {
                    val clips = toMapList(track["clips"])
                    for (index in clips.indices) {
                        val clip = clips[index]
                        val start = (clip["startTime"] as? Number)?.toDouble() ?: continue
                        val end = (clip["endTime"] as? Number)?.toDouble() ?: continue

                        if (currentTimeSec in start..end) {
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
                        }
                    }
                }

                renderer.swapBuffers()
                exporter.drainVideo(false)

                // Audio processing
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
            Log.e(TAG, "Export failed", e)
            withContext(Dispatchers.Main) {
                result.error("EXPORT_FAILED", e.message, null)
            }
        } finally {
            runCatching { renderer.deleteTextures(textureCache.values) }
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
            val text = (clip["text"] as? String) ?: (clip["textContent"] as? String) ?: ""
            val cacheKey = "TXT_${text}_${clip.hashCode()}"
            val texId = textureCache.getOrPut(cacheKey) {
                val bmp = createTextBitmap(text, width, height, clip)
                renderer.generate2DTexture(bmp)
            }
            renderer.renderOverlayLayer(texId, matrix, opacity)
        }
    }

    private fun createTextBitmap(text: String, width: Int, height: Int, clip: Map<String, Any?>): Bitmap {
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

    // ==================== Utilities ====================
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

    // ==================== Cleanup ====================
    override fun onDestroy() {
        releasePreviewResources()
        exportJob?.cancel()
        exportScope.cancel()
        super.onDestroy()
    }
}

// Simple data class for video metadata
data class VideoMetadata(
    val width: Int,
    val height: Int,
    val durationUs: Long,
    val frameRate: Float
)