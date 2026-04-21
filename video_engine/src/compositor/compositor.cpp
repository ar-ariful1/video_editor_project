// video_engine/src/compositor/compositor.cpp
// Full OpenGL ES GPU compositor implementation

#include "compositor.h"
#include <cstdio>
#include <cstring>
#include <algorithm>

namespace VideoEngine {

Compositor::Compositor(int width, int height)
    : width_(width), height_(height) {}

Compositor::~Compositor() { cleanup(); }

bool Compositor::init() {
    if (!compileShaders()) return false;
    setupQuad();
    if (!setupFBO()) return false;
    return true;
}

bool Compositor::compileShaders() {
    GLuint vert = compileShader(VERT_SHADER, GL_VERTEX_SHADER);
    if (!vert) return false;

    program_normal_ = linkProgram(vert, compileShader(FRAG_NORMAL, GL_FRAGMENT_SHADER));
    program_blend_  = linkProgram(vert, compileShader(FRAG_BLEND,  GL_FRAGMENT_SHADER));

    glDeleteShader(vert);
    return program_normal_ && program_blend_;
}

GLuint Compositor::compileShader(const char* src, GLenum type) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512]; glGetShaderInfoLog(s, 512, nullptr, log);
        fprintf(stderr, "Shader error: %s\n", log);
        glDeleteShader(s); return 0;
    }
    return s;
}

GLuint Compositor::linkProgram(GLuint vert, GLuint frag) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vert); glAttachShader(p, frag);
    glLinkProgram(p);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { glDeleteProgram(p); return 0; }
    glDeleteShader(frag);
    return p;
}

void Compositor::setupQuad() {
    static const float vertices[] = {
        -1,-1, 0,0,   1,-1, 1,0,
         1, 1, 1,1,  -1, 1, 0,1,
    };
    static const uint16_t indices[] = {0,1,2, 2,3,0};

    glGenVertexArrays(1, &quad_vao_);
    glGenBuffers(1, &quad_vbo_);
    glBindVertexArray(quad_vao_);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    GLuint ebo; glGenBuffers(1, &ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)(2*sizeof(float)));
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
}

bool Compositor::setupFBO() {
    glGenFramebuffers(1, &fbo_);
    glGenTextures(1, &output_texture_);
    glBindTexture(GL_TEXTURE_2D, output_texture_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width_, height_, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, output_texture_, 0);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return status == GL_FRAMEBUFFER_COMPLETE;
}

bool Compositor::renderFrame(const std::vector<Layer>& layers, double time_seconds, GLuint output_fbo) {
    glBindFramebuffer(GL_FRAMEBUFFER, output_fbo ? output_fbo : fbo_);
    glViewport(0, 0, width_, height_);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Sort layers by z-index
    auto sorted = layers;
    std::sort(sorted.begin(), sorted.end(), [](const Layer& a, const Layer& b){ return a.z_index < b.z_index; });

    for (const auto& layer : sorted) {
        if (layer.opacity <= 0) continue;

        GLuint prog = (layer.blend_mode == BlendMode::Normal) ? program_normal_ : program_blend_;
        glUseProgram(prog);

        // Transform matrix
        float mat[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
        applyTransform(layer.transform, mat);
        glUniformMatrix4fv(glGetUniformLocation(prog, "u_transform"), 1, GL_FALSE, mat);

        // Texture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, layer.texture_id);
        glUniform1i(glGetUniformLocation(prog, "u_texture"), 0);

        // Uniforms
        glUniform1f(glGetUniformLocation(prog, "u_opacity"), layer.opacity);
        applyColorGrade(layer.color_grade);

        if (layer.blend_mode != BlendMode::Normal) {
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, output_texture_);
            glUniform1i(glGetUniformLocation(prog, "u_base"), 1);
            glUniform1i(glGetUniformLocation(prog, "u_blend_mode"), (int)layer.blend_mode);
        }

        // Draw
        glBindVertexArray(quad_vao_);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, nullptr);
        glBindVertexArray(0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return true;
}

GLuint Compositor::uploadTexture(const uint8_t* rgba, int w, int h) {
    GLuint tex; glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    return tex;
}

void Compositor::releaseTexture(GLuint tex) {
    if (tex) glDeleteTextures(1, &tex);
}

void Compositor::resize(int w, int h) {
    width_ = w; height_ = h;
    glBindTexture(GL_TEXTURE_2D, output_texture_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);
}

void Compositor::applyTransform(const Transform& t, float* mat) {
    // Scale
    mat[0] = t.scaleX; mat[5] = t.scaleY;
    // Translate (normalized device coordinates)
    mat[12] = t.x * 2.0f;
    mat[13] = t.y * 2.0f;
    // Rotation (simple 2D rotation)
    if (t.rotation != 0) {
        float r = t.rotation * 3.14159265f / 180.0f;
        float c = cosf(r), s = sinf(r);
        mat[0] = t.scaleX * c;  mat[1] = t.scaleX * s;
        mat[4] = -t.scaleY * s; mat[5] = t.scaleY * c;
    }
}

void Compositor::applyColorGrade(const ColorGrade& cg) {
    GLuint prog; glGetIntegerv(GL_CURRENT_PROGRAM, (GLint*)&prog);
    glUniform1f(glGetUniformLocation(prog, "u_brightness"),  cg.brightness  / 100.0f);
    glUniform1f(glGetUniformLocation(prog, "u_contrast"),    cg.contrast    / 100.0f);
    glUniform1f(glGetUniformLocation(prog, "u_saturation"),  cg.saturation  / 100.0f);
    glUniform1f(glGetUniformLocation(prog, "u_temperature"), cg.temperature / 100.0f);
    glUniform1f(glGetUniformLocation(prog, "u_exposure"),    cg.exposure    / 100.0f);
}

void Compositor::cleanup() {
    if (program_normal_) { glDeleteProgram(program_normal_); program_normal_ = 0; }
    if (program_blend_)  { glDeleteProgram(program_blend_);  program_blend_  = 0; }
    if (fbo_)            { glDeleteFramebuffers(1, &fbo_);   fbo_           = 0; }
    if (output_texture_) { glDeleteTextures(1, &output_texture_); output_texture_ = 0; }
    if (quad_vao_)       { glDeleteVertexArrays(1, &quad_vao_); quad_vao_ = 0; }
    if (quad_vbo_)       { glDeleteBuffers(1, &quad_vbo_);    quad_vbo_  = 0; }
}

} // namespace VideoEngine
