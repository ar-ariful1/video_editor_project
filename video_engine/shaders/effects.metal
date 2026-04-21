// video_engine/shaders/effects.metal
// Metal shading language — iOS/macOS GPU effects pipeline
// All effects mirror the GLSL versions but use Metal syntax

#include <metal_stdlib>
using namespace metal;

// ─── Common structures ────────────────────────────────────────────────────────

struct VertexIn  { float4 position [[attribute(0)]]; float2 texCoord [[attribute(1)]]; };
struct FragIn    { float4 position [[position]]; float2 texCoord; };
struct EffectUniforms { float intensity; float time; float2 resolution; };

vertex FragIn effect_vertex(VertexIn in [[stage_in]]) {
  FragIn out;
  out.position = in.position;
  out.texCoord = in.texCoord;
  return out;
}

// ─── Glitch Effect ────────────────────────────────────────────────────────────
float randG(float2 co) { return fract(sin(dot(co, float2(12.9898f, 78.233f))) * 43758.5453f); }

fragment float4 glitch_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float2 uv = in.texCoord;
  float shift  = (randG(float2(u.time * 0.1f, uv.y)) - 0.5f) * u.intensity * 0.1f;
  float rs = u.intensity * 0.02f;
  float r = tex.sample(s, uv + float2( rs, 0.0f)).r;
  float g = tex.sample(s, uv).g;
  float b = tex.sample(s, uv - float2(rs, 0.0f)).b;
  float scanline = sin(uv.y * 400.0f + u.time * 10.0f) * 0.05f * u.intensity;
  return float4(r + scanline, g + scanline, b + scanline, 1.0f);
}

// ─── VHS Effect ───────────────────────────────────────────────────────────────
fragment float4 vhs_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float2 uv = in.texCoord;
  float wobble = sin(uv.y * 50.0f + u.time * 2.0f) * 0.003f * u.intensity;
  uv.x += wobble;
  float ca = u.intensity * 0.006f;
  float r = tex.sample(s, uv + float2( ca, 0.0f)).r;
  float g = tex.sample(s, uv).g;
  float b = tex.sample(s, uv - float2(ca, 0.0f)).b;
  float3 col(r, g, b);
  float noise = randG(uv + u.time * 0.01f) * 0.1f * u.intensity;
  col += noise;
  float2 center = uv - 0.5f;
  float vignette = saturate(1.0f - dot(center, center) * 1.5f * u.intensity);
  col *= vignette;
  float lum = dot(col, float3(0.299f, 0.587f, 0.114f));
  col = mix(float3(lum), col, 0.8f);
  return float4(col, 1.0f);
}

// ─── Vignette ─────────────────────────────────────────────────────────────────
fragment float4 vignette_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float4 col = tex.sample(s, in.texCoord);
  float2 center = in.texCoord - 0.5f;
  float dist = dot(center, center);
  float v = saturate(1.0f - dist * u.intensity * 3.0f);
  v = pow(v, 1.5f);
  return float4(col.rgb * v, col.a);
}

// ─── Film Grain ───────────────────────────────────────────────────────────────
fragment float4 grain_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float4 col = tex.sample(s, in.texCoord);
  float grain = (randG(in.texCoord + u.time * 0.01f) - 0.5f) * u.intensity * 0.3f;
  return float4(col.rgb + grain, col.a);
}

// ─── Chromatic Aberration ─────────────────────────────────────────────────────
fragment float4 chromatic_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float2 uv  = in.texCoord;
  float amount = u.intensity * 0.02f;
  float2 dir = normalize(uv - 0.5f) * length(uv - 0.5f) * amount;
  float r = tex.sample(s, uv + dir).r;
  float g = tex.sample(s, uv).g;
  float b = tex.sample(s, uv - dir).b;
  return float4(r, g, b, 1.0f);
}

// ─── Sharpen ──────────────────────────────────────────────────────────────────
fragment float4 sharpen_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float2 d = 1.0f / u.resolution;
  float4 center = tex.sample(s, in.texCoord);
  float4 top    = tex.sample(s, in.texCoord + float2(0.0f,  d.y));
  float4 bottom = tex.sample(s, in.texCoord + float2(0.0f, -d.y));
  float4 left   = tex.sample(s, in.texCoord + float2(-d.x,  0.0f));
  float4 right  = tex.sample(s, in.texCoord + float2( d.x,  0.0f));
  float amount = u.intensity * 2.0f;
  float4 result = center * (1.0f + 4.0f * amount) - (top + bottom + left + right) * amount;
  result.a = center.a;
  return result;
}

// ─── Pixelate ────────────────────────────────────────────────────────────────
fragment float4 pixelate_frag(
    FragIn in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant EffectUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::nearest);
  float pixels = mix(200.0f, 5.0f, u.intensity);
  float2 d = 1.0f / (float2(pixels) * u.resolution / max(u.resolution.x, u.resolution.y));
  float2 uv = floor(in.texCoord / d) * d;
  return tex.sample(s, uv);
}

// ─── Transition: Fade ─────────────────────────────────────────────────────────
struct TransitionUniforms { float progress; };

fragment float4 trans_fade_frag(
    FragIn in [[stage_in]],
    texture2d<float> texA [[texture(0)]],
    texture2d<float> texB [[texture(1)]],
    constant TransitionUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float4 a = texA.sample(s, in.texCoord);
  float4 b = texB.sample(s, in.texCoord);
  return mix(a, b, u.progress);
}

// ─── Transition: Dip to Black ─────────────────────────────────────────────────
fragment float4 trans_dip_black_frag(
    FragIn in [[stage_in]],
    texture2d<float> texA [[texture(0)]],
    texture2d<float> texB [[texture(1)]],
    constant TransitionUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  if (u.progress < 0.5f) {
    return mix(texA.sample(s, in.texCoord), float4(0,0,0,1), u.progress * 2.0f);
  } else {
    return mix(float4(0,0,0,1), texB.sample(s, in.texCoord), (u.progress - 0.5f) * 2.0f);
  }
}

// ─── Transition: Wipe ─────────────────────────────────────────────────────────
fragment float4 trans_wipe_frag(
    FragIn in [[stage_in]],
    texture2d<float> texA [[texture(0)]],
    texture2d<float> texB [[texture(1)]],
    constant TransitionUniforms& u [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);
  float edge = smoothstep(u.progress - 0.05f, u.progress + 0.05f, in.texCoord.x);
  return mix(texA.sample(s, in.texCoord), texB.sample(s, in.texCoord), edge);
}
