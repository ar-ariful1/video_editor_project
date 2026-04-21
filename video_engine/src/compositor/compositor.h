// video_engine/src/compositor/compositor.h
// GPU-accelerated video compositor using OpenGL ES / Metal
// Used via Flutter FFI / Platform Channel

#pragma once
#include <vector>
#include <functional>
#include <string>

#ifdef __APPLE__
  #include <OpenGLES/ES3/gl.h>
#else
  #include <GLES3/gl3.h>
#endif

namespace VideoEngine {

// ─── Structs ──────────────────────────────────────────────────────────────────

struct Transform {
  float x = 0.0f, y = 0.0f;
  float scaleX = 1.0f, scaleY = 1.0f;
  float rotation = 0.0f;   // degrees
  float skewX = 0.0f, skewY = 0.0f;
};

struct ColorGrade {
  float brightness = 0.0f;
  float contrast   = 0.0f;
  float saturation = 0.0f;
  float temperature = 0.0f;
  float exposure   = 0.0f;
};

enum class BlendMode {
  Normal, Multiply, Screen, Overlay,
  Darken, Lighten, ColorDodge, ColorBurn,
  HardLight, SoftLight, Difference, Exclusion
};

struct Layer {
  GLuint texture_id;
  Transform transform;
  ColorGrade color_grade;
  BlendMode blend_mode = BlendMode::Normal;
  float opacity = 1.0f;
  int z_index = 0;
};

// ─── Compositor ───────────────────────────────────────────────────────────────

class Compositor {
public:
  Compositor(int width, int height);
  ~Compositor();

  // Initialize OpenGL shaders and FBOs
  bool init();

  // Render all layers to output framebuffer
  bool renderFrame(
    const std::vector<Layer>& layers,
    double time_seconds,
    GLuint output_fbo
  );

  // Upload raw pixel data to GL texture (thread-safe)
  GLuint uploadTexture(const uint8_t* rgba_data, int width, int height);

  // Release a texture
  void releaseTexture(GLuint texture_id);

  // Mark output texture available to Flutter Texture widget
  void markFrameAvailable();

  // Resize output
  void resize(int width, int height);

  int width()  const { return width_;  }
  int height() const { return height_; }

private:
  int width_, height_;
  GLuint program_normal_;
  GLuint program_blend_;
  GLuint fbo_;
  GLuint output_texture_;
  GLuint quad_vao_, quad_vbo_;
  int64_t flutter_texture_id_ = -1;
  bool setupFBO();
  void cleanup();


  bool compileShaders();
  void setupQuad();
  void applyTransform(const Transform& t, float* matrix);
  void applyColorGrade(const ColorGrade& cg);
  GLuint compileShader(const char* src, GLenum type);
  GLuint linkProgram(GLuint vert, GLuint frag);
};

// ─── GLSL Shaders ─────────────────────────────────────────────────────────────

static const char* VERT_SHADER = R"(
#version 300 es
in vec2 a_position;
in vec2 a_texCoord;
uniform mat4 u_transform;
out vec2 v_texCoord;
void main() {
  gl_Position = u_transform * vec4(a_position, 0.0, 1.0);
  v_texCoord = a_texCoord;
}
)";

static const char* FRAG_NORMAL = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_opacity;
// Color grade uniforms
uniform float u_brightness;
uniform float u_contrast;
uniform float u_saturation;
uniform float u_temperature;
uniform float u_exposure;
out vec4 fragColor;

vec3 adjustColor(vec3 color) {
  // Exposure
  color *= pow(2.0, u_exposure);
  // Brightness
  color += u_brightness * 0.01;
  // Contrast
  color = (color - 0.5) * (1.0 + u_contrast * 0.02) + 0.5;
  // Saturation
  float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(lum), color, 1.0 + u_saturation * 0.01);
  // Temperature (warm = +r-b, cool = -r+b)
  color.r += u_temperature * 0.005;
  color.b -= u_temperature * 0.005;
  return clamp(color, 0.0, 1.0);
}

void main() {
  vec4 texColor = texture(u_texture, v_texCoord);
  texColor.rgb = adjustColor(texColor.rgb);
  fragColor = texColor * u_opacity;
}
)";

static const char* FRAG_BLEND = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;    // top layer
uniform sampler2D u_base;       // bottom layer (current FBO)
uniform float u_opacity;
uniform int u_blend_mode;
out vec4 fragColor;

vec3 blendScreen(vec3 a, vec3 b)    { return 1.0 - (1.0-a)*(1.0-b); }
vec3 blendMultiply(vec3 a, vec3 b) { return a * b; }
vec3 blendOverlay(vec3 a, vec3 b)  { return mix(2.0*a*b, 1.0-2.0*(1.0-a)*(1.0-b), step(0.5, b)); }

void main() {
  vec4 top  = texture(u_texture, v_texCoord) * u_opacity;
  vec4 base = texture(u_base, v_texCoord);
  vec3 blended;
  if      (u_blend_mode == 1) blended = blendMultiply(base.rgb, top.rgb);
  else if (u_blend_mode == 2) blended = blendScreen(base.rgb, top.rgb);
  else if (u_blend_mode == 3) blended = blendOverlay(base.rgb, top.rgb);
  else                        blended = mix(base.rgb, top.rgb, top.a);  // Normal
  fragColor = vec4(blended, max(base.a, top.a));
}
)";

} // namespace VideoEngine
