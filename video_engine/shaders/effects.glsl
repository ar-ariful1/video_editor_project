// video_engine/shaders/effects.glsl
// All visual effect GLSL fragment shaders
// Compiled at runtime and applied to video frames via OpenGL ES / Metal

// ─── GLITCH EFFECT ────────────────────────────────────────────────────────────
// Uniform: float u_intensity (0-1), float u_time
const char* GLITCH_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_time;
out vec4 fragColor;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453); }

void main() {
  vec2 uv = v_texCoord;
  float glitch = u_intensity;

  // Horizontal shift
  float shift = (rand(vec2(u_time * 0.1, uv.y)) - 0.5) * glitch * 0.1;
  uv.x += shift;

  // RGB channel shift
  float rs = glitch * 0.02;
  float r = texture(u_texture, uv + vec2(rs,  0.0)).r;
  float g = texture(u_texture, uv).g;
  float b = texture(u_texture, uv - vec2(rs, 0.0)).b;

  // Scan lines
  float scanline = sin(uv.y * 400.0 + u_time * 10.0) * 0.05 * glitch;

  fragColor = vec4(r + scanline, g + scanline, b + scanline, 1.0);
}
)";

// ─── VHS / RETRO EFFECT ───────────────────────────────────────────────────────
const char* VHS_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_time;
out vec4 fragColor;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453); }

void main() {
  vec2 uv = v_texCoord;

  // Tape wobble
  float wobble = sin(uv.y * 50.0 + u_time * 2.0) * 0.003 * u_intensity;
  uv.x += wobble;

  // Chromatic aberration
  float ca = u_intensity * 0.006;
  float r = texture(u_texture, uv + vec2( ca, 0.0)).r;
  float g = texture(u_texture, uv).g;
  float b = texture(u_texture, uv - vec2(ca, 0.0)).b;
  vec3 col = vec3(r, g, b);

  // Noise
  float noise = rand(uv + u_time * 0.01) * 0.1 * u_intensity;
  col += noise;

  // Vignette
  vec2 center = uv - 0.5;
  float vignette = 1.0 - dot(center, center) * 1.5 * u_intensity;
  col *= vignette;

  // Desaturate slightly (VHS color bleed)
  float lum = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(lum), col, 0.8);

  fragColor = vec4(col, 1.0);
}
)";

// ─── BLUR (GAUSSIAN) ─────────────────────────────────────────────────────────
const char* BLUR_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_intensity;  // blur radius in pixels
out vec4 fragColor;

void main() {
  float sigma = u_intensity * 10.0;
  float twoSigmaSq = 2.0 * sigma * sigma;
  vec2 texelSize = 1.0 / u_resolution;
  vec4 result = vec4(0.0);
  float totalWeight = 0.0;
  int radius = int(ceil(sigma * 3.0));

  for (int x = -radius; x <= radius; x++) {
    for (int y = -radius; y <= radius; y++) {
      float weight = exp(-(float(x*x + y*y)) / twoSigmaSq);
      result += texture(u_texture, v_texCoord + vec2(float(x), float(y)) * texelSize) * weight;
      totalWeight += weight;
    }
  }
  fragColor = result / totalWeight;
}
)";

// ─── FILM GRAIN ──────────────────────────────────────────────────────────────
const char* GRAIN_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_time;
out vec4 fragColor;

float rand(vec2 co) { return fract(sin(dot(co * u_time * 0.1, vec2(12.9898,78.233))) * 43758.5453); }

void main() {
  vec4 col = texture(u_texture, v_texCoord);
  float grain = (rand(v_texCoord) - 0.5) * u_intensity * 0.3;
  fragColor = vec4(col.rgb + grain, col.a);
}
)";

// ─── VIGNETTE ────────────────────────────────────────────────────────────────
const char* VIGNETTE_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  vec4 col = texture(u_texture, v_texCoord);
  vec2 center = v_texCoord - 0.5;
  float dist = dot(center, center);
  float vignette = 1.0 - dist * u_intensity * 3.0;
  vignette = clamp(vignette, 0.0, 1.0);
  vignette = pow(vignette, 1.5);
  fragColor = vec4(col.rgb * vignette, col.a);
}
)";

// ─── CHROMATIC ABERRATION ────────────────────────────────────────────────────
const char* CHROMATIC_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  vec2 uv = v_texCoord;
  float amount = u_intensity * 0.02;
  vec2 dir = uv - 0.5;
  float dist = length(dir);
  dir = normalize(dir) * dist * amount;

  float r = texture(u_texture, uv + dir).r;
  float g = texture(u_texture, uv).g;
  float b = texture(u_texture, uv - dir).b;
  fragColor = vec4(r, g, b, 1.0);
}
)";

// ─── PIXELATE ────────────────────────────────────────────────────────────────
const char* PIXELATE_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  float pixels = mix(200.0, 5.0, u_intensity);
  vec2 d = 1.0 / (vec2(pixels) * u_resolution / max(u_resolution.x, u_resolution.y));
  vec2 uv = floor(v_texCoord / d) * d;
  fragColor = texture(u_texture, uv);
}
)";

// ─── HALFTONE ────────────────────────────────────────────────────────────────
const char* HALFTONE_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  float dotSize = mix(1.0, 20.0, u_intensity);
  vec2 uv = v_texCoord * u_resolution / dotSize;
  vec2 tile = fract(uv) - 0.5;
  float d = length(tile);

  vec4 col = texture(u_texture, v_texCoord);
  float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
  float radius = sqrt(lum) * 0.5;
  float mask = step(d, radius);
  fragColor = vec4(vec3(mask), 1.0);
}
)";

// ─── SHARPEN ─────────────────────────────────────────────────────────────────
const char* SHARPEN_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  vec2 d = 1.0 / u_resolution;
  vec4 center = texture(u_texture, v_texCoord);
  vec4 top    = texture(u_texture, v_texCoord + vec2(0.0, d.y));
  vec4 bottom = texture(u_texture, v_texCoord - vec2(0.0, d.y));
  vec4 left   = texture(u_texture, v_texCoord - vec2(d.x, 0.0));
  vec4 right  = texture(u_texture, v_texCoord + vec2(d.x, 0.0));

  float amount = u_intensity * 2.0;
  fragColor = center * (1.0 + 4.0 * amount) - (top + bottom + left + right) * amount;
  fragColor.a = center.a;
}
)";

// ─── LENS DISTORTION (FISHEYE) ───────────────────────────────────────────────
const char* FISHEYE_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  vec2 uv = v_texCoord * 2.0 - 1.0;
  float r = length(uv);
  float theta = atan(r);
  float distortion = u_intensity * 0.5;
  vec2 distorted = uv * (1.0 + distortion * r * r);
  distorted = (distorted + 1.0) * 0.5;

  if (distorted.x < 0.0 || distorted.x > 1.0 || distorted.y < 0.0 || distorted.y > 1.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
  } else {
    fragColor = texture(u_texture, distorted);
  }
}
)";

// ─── SCREEN BLEND (for light leaks overlay) ───────────────────────────────────
const char* SCREEN_BLEND_FRAG = R"(
#version 300 es
precision mediump float;
in vec2 v_texCoord;
uniform sampler2D u_base;
uniform sampler2D u_overlay;
uniform float u_intensity;
out vec4 fragColor;

void main() {
  vec4 base    = texture(u_base, v_texCoord);
  vec4 overlay = texture(u_overlay, v_texCoord) * u_intensity;
  vec3 result  = 1.0 - (1.0 - base.rgb) * (1.0 - overlay.rgb);
  fragColor = vec4(result, base.a);
}
)";
