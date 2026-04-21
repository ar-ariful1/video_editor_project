#include "layer_compositor.h"
#include <algorithm>
#include <android/log.h>

#define TAG "LayerCompositor"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

namespace VideoEngine {

static GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        LOGE("Shader compilation failed!");
        return 0;
    }
    return shader;
}

void LayerCompositor::init() {
    const char* vs = R"(
        #version 300 es
        layout(location = 0) in vec2 aPosition;
        layout(location = 1) in vec2 aTexCoord;
        uniform mat4 uMatrix;
        out vec2 vTexCoord;
        void main() {
            gl_Position = uMatrix * vec4(aPosition, 0.0, 1.0);
            vTexCoord = aTexCoord;
        }
    )";

    const char* fs = R"(
        #version 300 es
        precision mediump float;
        uniform sampler2D uTexture;
        uniform float uOpacity;
        in vec2 vTexCoord;
        out vec4 fragColor;
        void main() {
            vec4 color = texture(uTexture, vTexCoord);
            fragColor = vec4(color.rgb, color.a * uOpacity);
        }
    )";

    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vs);
    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fs);
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glGenBuffers(1, &vbo);
    float vertices[] = {
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
         1.0f,  1.0f,  1.0f, 1.0f
    };
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

void LayerCompositor::composite(std::vector<Layer>& layers, int screenWidth, int screenHeight) {
    std::sort(layers.begin(), layers.end(), [](const Layer& a, const Layer& b) {
        return a.zIndex < b.zIndex;
    });

    glViewport(0, 0, screenWidth, screenHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(shaderProgram);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

    for (const auto& layer : layers) {
        if (layer.isVisible) {
            renderLayer(layer);
        }
    }
}

void LayerCompositor::renderLayer(const Layer& layer) {
    glBindTexture(GL_TEXTURE_2D, layer.textureId);

    GLint opacityLoc = glGetUniformLocation(shaderProgram, "uOpacity");
    glUniform1f(opacityLoc, layer.opacity);

    // Default Identity Matrix for now (until nlohmann/json integration for matrices)
    GLint matrixLoc = glGetUniformLocation(shaderProgram, "uMatrix");
    float identity[16] = {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    };
    glUniformMatrix4fv(matrixLoc, 1, GL_FALSE, identity);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

void LayerCompositor::release() {
    glDeleteProgram(shaderProgram);
    glDeleteBuffers(1, &vbo);
}

}
