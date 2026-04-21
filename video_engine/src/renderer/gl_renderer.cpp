// video_engine/src/renderer/gl_renderer.cpp
// Full OpenGL ES / Metal 60fps render loop with frame-accurate timing

#include "gl_renderer.h"
#include <cstring>
#include <chrono>
#include <thread>

#ifndef __APPLE__
  #include <EGL/eglext.h>
#endif

namespace VideoEngine {

using Clock = std::chrono::steady_clock;
using Ms    = std::chrono::milliseconds;
using Us    = std::chrono::microseconds;

// ── Constructor / Destructor ──────────────────────────────────────────────────

GLRenderer::GLRenderer(int width, int height)
    : width_(width), height_(height) {}

GLRenderer::~GLRenderer() {
    stop();
#ifndef __APPLE__
    if (egl_surface_ != EGL_NO_SURFACE) eglDestroySurface(egl_display_, egl_surface_);
    if (egl_context_ != EGL_NO_CONTEXT) eglDestroyContext(egl_display_, egl_context_);
    if (egl_display_ != EGL_NO_DISPLAY) eglTerminate(egl_display_);
#endif
    if (fbo_)         { glDeleteFramebuffers(1, &fbo_);    fbo_       = 0; }
    if (color_tex_)   { glDeleteTextures(1, &color_tex_);  color_tex_ = 0; }
    compositor_.reset();
}

// ── Init ─────────────────────────────────────────────────────────────────────

bool GLRenderer::init() {
#ifndef __APPLE__
    if (!initEGL()) return false;
#endif
    if (!setupFBO()) return false;

    compositor_ = std::make_unique<Compositor>(width_, height_);
    if (!compositor_->init()) return false;

    // Register Flutter external texture
    // In production: call Flutter's texture registry API
    // texture_id_ = flutterTextureRegistry->registerTexture(color_tex_);

    return true;
}

#ifndef __APPLE__
bool GLRenderer::initEGL() {
    egl_display_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (egl_display_ == EGL_NO_DISPLAY) return false;

    EGLint major, minor;
    if (!eglInitialize(egl_display_, &major, &minor)) return false;

    // Config supporting GLES 3.0 + FBO
    const EGLint config_attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 0, EGL_NONE
    };
    EGLConfig config; EGLint num_config;
    if (!eglChooseConfig(egl_display_, config_attribs, &config, 1, &num_config)) return false;

    // Offscreen surface (pbuffer)
    const EGLint pb_attribs[] = { EGL_WIDTH, width_, EGL_HEIGHT, height_, EGL_NONE };
    egl_surface_ = eglCreatePbufferSurface(egl_display_, config, pb_attribs);
    if (egl_surface_ == EGL_NO_SURFACE) return false;

    const EGLint ctx_attribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    egl_context_ = eglCreateContext(egl_display_, config, EGL_NO_CONTEXT, ctx_attribs);
    if (egl_context_ == EGL_NO_CONTEXT) return false;

    return eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_);
}
#endif

bool GLRenderer::setupFBO() {
    glGenTextures(1, &color_tex_);
    glBindTexture(GL_TEXTURE_2D, color_tex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width_, height_, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenFramebuffers(1, &fbo_);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color_tex_, 0);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return status == GL_FRAMEBUFFER_COMPLETE;
}

// ── Render loop ───────────────────────────────────────────────────────────────

void GLRenderer::start() {
    if (running_) return;
    running_ = true;
    render_thread_ = std::thread(&GLRenderer::renderLoop, this);
}

void GLRenderer::stop() {
    running_ = false;
    if (render_thread_.joinable()) render_thread_.join();
}

void GLRenderer::pushFrame(RenderFrame frame) {
    std::lock_guard<std::mutex> lk(frame_mutex_);
    pending_frame_ = std::move(frame);
    has_pending_   = true;
}

void GLRenderer::renderLoop() {
    // Target: 60fps = 16.667ms per frame
    constexpr auto FRAME_INTERVAL = std::chrono::microseconds(16667);

#ifndef __APPLE__
    eglMakeCurrent(egl_display_, egl_surface_, egl_surface_, egl_context_);
#endif

    while (running_) {
        auto frame_start = Clock::now();

        RenderFrame frame;
        bool has_frame = false;
        {
            std::lock_guard<std::mutex> lk(frame_mutex_);
            if (has_pending_) {
                frame     = std::move(pending_frame_);
                has_frame = true;
                has_pending_ = false;
            }
        }

        if (has_frame) {
            renderFrame(frame);
            // Notify Flutter texture registry
            if (texture_cb_) texture_cb_(texture_id_);
        }

        // Precise frame timing — sleep remainder of 16.67ms
        auto elapsed = Clock::now() - frame_start;
        if (elapsed < FRAME_INTERVAL) {
            std::this_thread::sleep_for(FRAME_INTERVAL - elapsed);
        }
    }

#ifndef __APPLE__
    eglMakeCurrent(egl_display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
#endif
}

void GLRenderer::renderFrame(const RenderFrame& frame) {
    if (!compositor_) return;
    compositor_->renderFrame(frame.layers, frame.time_seconds, fbo_);
    glFlush();
}

// ── Synchronous render (for export) ──────────────────────────────────────────

bool GLRenderer::renderSync(const RenderFrame& frame, GLuint output_fbo) {
    if (!compositor_) return false;
    return compositor_->renderFrame(frame.layers, frame.time_seconds, output_fbo ?: fbo_);
}

void GLRenderer::resize(int w, int h) {
    width_ = w; height_ = h;
    if (compositor_) compositor_->resize(w, h);

    // Resize FBO texture
    if (color_tex_) {
        glBindTexture(GL_TEXTURE_2D, color_tex_);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
}

} // namespace VideoEngine
