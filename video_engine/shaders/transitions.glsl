// video_engine/shaders/transitions.glsl
// All transition GLSL fragment shaders
// Uniform: sampler2D texA, texB; float progress (0.0 → 1.0)

// ─── FADE (Cross-Dissolve) ────────────────────────────────────────────────────
const char* TRANS_FADE = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() { fragColor = mix(texture(texA, v_uv), texture(texB, v_uv), progress); }
)";

// ─── SLIDE LEFT ──────────────────────────────────────────────────────────────
const char* TRANS_SLIDE_LEFT = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  vec2 uvA = v_uv + vec2(progress, 0.0);
  vec2 uvB = v_uv + vec2(progress - 1.0, 0.0);
  if (uvA.x >= 0.0 && uvA.x <= 1.0) fragColor = texture(texA, uvA);
  else fragColor = texture(texB, uvB);
}
)";

// ─── ZOOM IN ─────────────────────────────────────────────────────────────────
const char* TRANS_ZOOM_IN = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float scale = 1.0 + progress * 0.3;
  vec2 uvA = (v_uv - 0.5) / scale + 0.5;
  vec4 colA = texture(texA, uvA);
  vec4 colB = texture(texB, v_uv);
  fragColor = mix(colA, colB, progress);
}
)";

// ─── SPIN (Rotation) ─────────────────────────────────────────────────────────
const char* TRANS_SPIN = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float angle = progress * 6.28318; // full rotation
  float c = cos(angle), s = sin(angle);
  vec2 center = v_uv - 0.5;
  vec2 rotated = vec2(c*center.x - s*center.y, s*center.x + c*center.y) + 0.5;
  fragColor = mix(texture(texA, v_uv), texture(texB, rotated), progress);
}
)";

// ─── WIPE (Left to Right) ────────────────────────────────────────────────────
const char* TRANS_WIPE = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float edge = smoothstep(progress - 0.05, progress + 0.05, v_uv.x);
  fragColor = mix(texture(texA, v_uv), texture(texB, v_uv), edge);
}
)";

// ─── CIRCLE OPEN ─────────────────────────────────────────────────────────────
const char* TRANS_CIRCLE = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float radius = progress * 1.5;
  vec2 center = v_uv - 0.5;
  float dist = length(center);
  float mask = step(dist, radius);
  fragColor = mix(texture(texA, v_uv), texture(texB, v_uv), mask);
}
)";

// ─── DIP TO BLACK ────────────────────────────────────────────────────────────
const char* TRANS_DIP_BLACK = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float p1 = progress * 2.0;
  float p2 = (progress - 0.5) * 2.0;
  if (progress < 0.5) {
    fragColor = mix(texture(texA, v_uv), vec4(0.0, 0.0, 0.0, 1.0), p1);
  } else {
    fragColor = mix(vec4(0.0, 0.0, 0.0, 1.0), texture(texB, v_uv), p2);
  }
}
)";

// ─── FLASH (White Flash) ─────────────────────────────────────────────────────
const char* TRANS_FLASH = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float flash = 1.0 - abs(progress - 0.5) * 2.0;
  flash = pow(flash, 3.0) * 4.0;
  vec4 blended = mix(texture(texA, v_uv), texture(texB, v_uv), progress);
  fragColor = mix(blended, vec4(1.0), clamp(flash, 0.0, 1.0));
}
)";

// ─── GLITCH SMEAR ────────────────────────────────────────────────────────────
const char* TRANS_GLITCH = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
float rand(float x) { return fract(sin(x * 127.1) * 43758.5); }
void main() {
  float strips = 20.0;
  float stripY = floor(v_uv.y * strips) / strips;
  float offset = (rand(stripY + floor(progress * 10.0)) - 0.5) * progress * 0.2;
  vec2 uvA = vec2(v_uv.x + offset, v_uv.y);
  vec2 uvB = vec2(v_uv.x - offset, v_uv.y);
  float mask = step(rand(v_uv.y + progress), progress);
  fragColor = mix(texture(texA, uvA), texture(texB, uvB), mask);
}
)";

// ─── PAGE FLIP ───────────────────────────────────────────────────────────────
const char* TRANS_PAGE_FLIP = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float flip = progress;
  float fold = 1.0 - flip;
  if (v_uv.x > fold) {
    vec2 uv2 = vec2(1.0 - (v_uv.x - fold) / flip, v_uv.y);
    vec4 colB = texture(texB, uv2);
    float shadow = (v_uv.x - fold) / flip * 0.3;
    fragColor = vec4(colB.rgb * (1.0 - shadow), 1.0);
  } else {
    fragColor = texture(texA, v_uv);
  }
}
)";

// ─── BARN DOOR ───────────────────────────────────────────────────────────────
const char* TRANS_BARN_DOOR = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float half_open = progress * 0.5;
  bool in_door = v_uv.x < half_open || v_uv.x > (1.0 - half_open);
  fragColor = in_door ? texture(texB, v_uv) : texture(texA, v_uv);
}
)";

// ─── WHIP PAN ────────────────────────────────────────────────────────────────
const char* TRANS_WHIP = R"(
#version 300 es
precision mediump float;
in vec2 v_uv;
uniform sampler2D texA, texB;
uniform float progress;
out vec4 fragColor;
void main() {
  float speed = 0.15;
  float blurA = texture(texA, vec2(fract(v_uv.x + progress * speed * 10.0), v_uv.y)).r;
  vec4 a = texture(texA, vec2(v_uv.x + progress * 0.5, v_uv.y));
  vec4 b = texture(texB, vec2(v_uv.x - (1.0 - progress) * 0.5, v_uv.y));
  fragColor = progress < 0.5 ? a : b;
}
)";
