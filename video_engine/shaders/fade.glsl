#version 300 es
precision highp float;

in vec2 v_TexCoord;
out vec4 outColor;

uniform sampler2D u_TextureFrom;
uniform sampler2D u_TextureTo;
uniform float u_Progress;

void main() {
    vec4 from = texture(u_TextureFrom, v_TexCoord);
    vec4 to = texture(u_TextureTo, v_TexCoord);

    // Smooth cross-fade blending
    outColor = mix(from, to, u_Progress);
}
