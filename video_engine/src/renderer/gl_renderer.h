// video_engine/src/renderer/gl_renderer.h
// OpenGL ES render loop — drives 60fps preview via Flutter Texture widget

#pragma once
#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <mutex>
#include <memory>

#ifdef __APPLE__
  #include <OpenGLES/ES3/gl.h>
  #include <OpenGLES/ES3/glext.h>
#else
  #include <GLES3/gl3.h>
  #include <EGL/egl.h>
#endif

#include "compositor/compositor.h"

namespace VideoEngine {

struct RenderFrame {
  double time_seconds;
  std::vector<Layer> layers;
};

using TextureAvailableCallback = std::function<void(int64_t texture_id)>;

class GLRenderer {
public:
  explicit GLRenderer(int width, int height);
  ~GLRenderer();

  // Initialize EGL/OpenGL context (call from render thread)
  bool init();

  // Set the Flutter texture callback (called when frame is ready)
  void setTextureCallback(TextureAvailableCallback cb) { texture_cb_ = std::move(cb); }

  // Start/stop the render loop
  void start();
  void stop();

  // Push a frame to be rendered (thread-safe)
  void pushFrame(RenderFrame frame);

  // Render a single frame synchronously (for export)
  bool renderSync(const RenderFrame& frame, GLuint output_fbo);

  // Resize viewport
  void resize(int width, int height);

  // Get the Flutter-registered texture ID
  int64_t textureId() const { return texture_id_; }

  bool isRunning() const { return running_.load(); }

private:
  int width_, height_;
  std::atomic<bool> running_{false};
  std::thread render_thread_;
  std::mutex  frame_mutex_;

  RenderFrame  pending_frame_;
  bool         has_pending_ = false;

  std::unique_ptr<Compositor> compositor_;
  TextureAvailableCallback texture_cb_;

  int64_t texture_id_ = -1;
  GLuint  fbo_         = 0;
  GLuint  color_tex_   = 0;

  // EGL (Android)
#ifndef __APPLE__
  EGLDisplay egl_display_ = EGL_NO_DISPLAY;
  EGLContext egl_context_ = EGL_NO_CONTEXT;
  EGLSurface egl_surface_ = EGL_NO_SURFACE;
  bool initEGL();
#endif

  void renderLoop();
  void renderFrame(const RenderFrame& frame);
  bool setupFBO();
};

// ── Engine FFI exports ─────────────────────────────────────────────────────────
// Called from Flutter via dart:ffi

extern "C" {

#ifdef _WIN32
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

EXPORT bool  engine_init(int width, int height);
EXPORT void  engine_set_playhead(double time_seconds);
EXPORT bool  engine_load_clip(const char* path, int track_idx, double start, double end, int z_index);
EXPORT void  engine_remove_clip(const char* clip_id);
EXPORT void  engine_set_clip_effect(const char* clip_id, const char* effect_type, float intensity);
EXPORT void  engine_set_clip_color_grade(const char* clip_id, float brightness, float contrast, float saturation, float temperature, float exposure);
EXPORT void  engine_set_clip_transform(const char* clip_id, float x, float y, float scale_x, float scale_y, float rotation);
EXPORT void  engine_render_frame(double time_seconds);
EXPORT int64_t engine_get_texture_id();
EXPORT void  engine_resize(int width, int height);
EXPORT void  engine_destroy();

// Export
EXPORT void* engine_export_start(const char* output_path, int width, int height, int fps, int bitrate_kbps, bool watermark);
EXPORT bool  engine_export_push_time(void* handle, double time_seconds);
EXPORT float engine_export_progress(void* handle);
EXPORT bool  engine_export_finish(void* handle);
EXPORT void  engine_export_cancel(void* handle);

} // extern "C"

} // namespace VideoEngine
