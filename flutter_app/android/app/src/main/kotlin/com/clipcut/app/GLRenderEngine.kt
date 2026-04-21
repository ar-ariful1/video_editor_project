package com.clipcut.app

import android.graphics.Bitmap
import android.opengl.*
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

class GLRenderEngine {

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    private var programVideo = 0
    private var programOverlay = 0

    private var uMatrixVideo = -1
    private var uOpacityVideo = -1
    private var uBrightnessVideo = -1
    private var uContrastVideo = -1
    private var uSaturationVideo = -1
    private var uUseNextVideo = -1
    private var uTransitionTypeVideo = -1
    private var uTransitionProgressVideo = -1

    private var uMatrixOverlay = -1
    private var uOpacityOverlay = -1

    private val vertexData = floatArrayOf(
        -1f, -1f, 0f, 0f,
        1f, -1f, 1f, 0f,
        -1f,  1f, 0f, 1f,
        1f,  1f, 1f, 1f
    )

    private val vertexBuffer: FloatBuffer =
        ByteBuffer.allocateDirect(vertexData.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(vertexData)
                position(0)
            }

    fun initGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            throw RuntimeException("EGL init failed")
        }

        val configAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )

        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)) {
            throw RuntimeException("EGL config failed")
        }

        val contextAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 3,
            EGL14.EGL_NONE
        )

        eglContext = EGL14.eglCreateContext(
            eglDisplay,
            configs[0],
            EGL14.EGL_NO_CONTEXT,
            contextAttribs,
            0
        )

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay,
            configs[0],
            surface,
            surfaceAttribs,
            0
        )

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            throw RuntimeException("EGL makeCurrent failed")
        }

        setupShaders()
        GLES30.glDisable(GLES30.GL_DEPTH_TEST)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
    }

    private fun setupShaders() {
        programVideo = createProgram(VERTEX_SHADER, FRAGMENT_VIDEO_SHADER)
        programOverlay = createProgram(VERTEX_SHADER, FRAGMENT_OVERLAY_SHADER)

        uMatrixVideo = GLES30.glGetUniformLocation(programVideo, "uMatrix")
        uOpacityVideo = GLES30.glGetUniformLocation(programVideo, "uOpacity")
        uBrightnessVideo = GLES30.glGetUniformLocation(programVideo, "uBrightness")
        uContrastVideo = GLES30.glGetUniformLocation(programVideo, "uContrast")
        uSaturationVideo = GLES30.glGetUniformLocation(programVideo, "uSaturation")
        uUseNextVideo = GLES30.glGetUniformLocation(programVideo, "uUseNext")
        uTransitionTypeVideo = GLES30.glGetUniformLocation(programVideo, "uTransitionType")
        uTransitionProgressVideo = GLES30.glGetUniformLocation(programVideo, "uTransitionProgress")

        uMatrixOverlay = GLES30.glGetUniformLocation(programOverlay, "uMatrix")
        uOpacityOverlay = GLES30.glGetUniformLocation(programOverlay, "uOpacity")
    }

    fun clear() {
        GLES30.glViewport(0, 0, 1, 1)
        GLES30.glClearColor(0f, 0f, 0f, 1f)
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
    }

    fun renderVideoLayer(
        textureId: Int,
        matrix: FloatArray,
        opacity: Float = 1f,
        brightness: Float = 0f,
        contrast: Float = 1f,
        saturation: Float = 1f,
        nextTextureId: Int = -1,
        transitionType: Int = 0,
        transitionProgress: Float = 0f
    ) {
        GLES30.glUseProgram(programVideo)

        GLES30.glUniformMatrix4fv(uMatrixVideo, 1, false, matrix, 0)
        GLES30.glUniform1f(uOpacityVideo, opacity)
        GLES30.glUniform1f(uBrightnessVideo, brightness)
        GLES30.glUniform1f(uContrastVideo, contrast)
        GLES30.glUniform1f(uSaturationVideo, saturation)
        GLES30.glUniform1i(uUseNextVideo, if (nextTextureId != -1) 1 else 0)
        GLES30.glUniform1i(uTransitionTypeVideo, transitionType)
        GLES30.glUniform1f(uTransitionProgressVideo, transitionProgress)

        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES30.glUniform1i(GLES30.glGetUniformLocation(programVideo, "uTexture"), 0)

        if (nextTextureId != -1) {
            GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
            GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, nextTextureId)
            GLES30.glUniform1i(GLES30.glGetUniformLocation(programVideo, "uNextTexture"), 1)
        }

        bindVertexData()
        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
    }

    fun renderOverlayLayer(textureId: Int, matrix: FloatArray, opacity: Float = 1f) {
        GLES30.glUseProgram(programOverlay)

        GLES30.glUniformMatrix4fv(uMatrixOverlay, 1, false, matrix, 0)
        GLES30.glUniform1f(uOpacityOverlay, opacity)

        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLES30.glUniform1i(GLES30.glGetUniformLocation(programOverlay, "uTexture"), 0)

        bindVertexData()
        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
    }

    fun generateExternalTexture(): Int {
        val tex = IntArray(1)
        GLES30.glGenTextures(1, tex, 0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex[0])
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
        return tex[0]
    }

    fun generate2DTexture(bitmap: Bitmap): Int {
        val tex = IntArray(1)
        GLES30.glGenTextures(1, tex, 0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, tex[0])
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
        return tex[0]
    }

    fun deleteTextures(ids: Collection<Int>) {
        if (ids.isEmpty()) return
        val arr = ids.toIntArray()
        GLES30.glDeleteTextures(arr.size, arr, 0)
    }

    fun swapBuffers() {
        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
    }

    fun release() {
        try {
            GLES30.glDeleteProgram(programVideo)
        } catch (_: Exception) {}
        try {
            GLES30.glDeleteProgram(programOverlay)
        } catch (_: Exception) {}

        try {
            EGL14.eglMakeCurrent(
                eglDisplay,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT
            )
        } catch (_: Exception) {}

        try {
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
        } catch (_: Exception) {}
        try {
            EGL14.eglDestroyContext(eglDisplay, eglContext)
        } catch (_: Exception) {}
        try {
            EGL14.eglTerminate(eglDisplay)
        } catch (_: Exception) {}

        eglSurface = EGL14.EGL_NO_SURFACE
        eglContext = EGL14.EGL_NO_CONTEXT
        eglDisplay = EGL14.EGL_NO_DISPLAY
    }

    private fun bindVertexData() {
        vertexBuffer.position(0)
        GLES30.glEnableVertexAttribArray(0)
        GLES30.glVertexAttribPointer(0, 2, GLES30.GL_FLOAT, false, 16, vertexBuffer)

        vertexBuffer.position(2)
        GLES30.glEnableVertexAttribArray(1)
        GLES30.glVertexAttribPointer(1, 2, GLES30.GL_FLOAT, false, 16, vertexBuffer)
    }

    private fun createProgram(vertexShader: String, fragmentShader: String): Int {
        val vs = loadShader(GLES30.GL_VERTEX_SHADER, vertexShader)
        val fs = loadShader(GLES30.GL_FRAGMENT_SHADER, fragmentShader)
        val program = GLES30.glCreateProgram()
        GLES30.glAttachShader(program, vs)
        GLES30.glAttachShader(program, fs)
        GLES30.glLinkProgram(program)
        return program
    }

    private fun loadShader(type: Int, code: String): Int {
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, code)
        GLES30.glCompileShader(shader)
        return shader
    }

    companion object {
        private const val VERTEX_SHADER = """
            #version 300 es
            layout(location = 0) in vec2 aPosition;
            layout(location = 1) in vec2 aTexCoord;
            uniform mat4 uMatrix;
            out vec2 vTexCoord;
            void main() {
                gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
                vTexCoord = aTexCoord;
            }
        """

        private const val FRAGMENT_VIDEO_SHADER = """
            #version 300 es
            #extension GL_OES_EGL_image_external_essl3 : require
            precision mediump float;

            uniform samplerExternalOES uTexture;
            uniform samplerExternalOES uNextTexture;
            uniform int uUseNext;
            uniform int uTransitionType;
            uniform float uTransitionProgress;
            uniform float uOpacity;
            uniform float uBrightness;
            uniform float uContrast;
            uniform float uSaturation;

            in vec2 vTexCoord;
            out vec4 fragColor;

            vec3 adjustColor(vec3 c) {
                c += uBrightness;
                c = (c - 0.5) * uContrast + 0.5;
                float l = dot(c, vec3(0.299, 0.587, 0.114));
                c = mix(vec3(l), c, uSaturation);
                return clamp(c, 0.0, 1.0);
            }

            void main() {
                vec4 a = texture(uTexture, vTexCoord);
                vec4 color = a;

                if (uUseNext == 1) {
                    vec4 b = texture(uNextTexture, vTexCoord);
                    if (uTransitionType == 1) {
                        color = mix(a, b, uTransitionProgress);
                    } else {
                        color = mix(a, b, uTransitionProgress);
                    }
                }

                color.rgb = adjustColor(color.rgb);
                fragColor = vec4(color.rgb, color.a * uOpacity);
            }
        """

        private const val FRAGMENT_OVERLAY_SHADER = """
            #version 300 es
            precision mediump float;

            uniform sampler2D uTexture;
            uniform float uOpacity;

            in vec2 vTexCoord;
            out vec4 fragColor;

            void main() {
                vec4 c = texture(uTexture, vTexCoord);
                fragColor = vec4(c.rgb, c.a * uOpacity);
            }
        """
    }
}