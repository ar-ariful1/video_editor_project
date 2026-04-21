#ifndef LAYER_COMPOSITOR_H
#define LAYER_COMPOSITOR_H

#include <vector>
#include <GLES3/gl3.h>

namespace VideoEngine {

struct Layer {
    int id;
    int zIndex;
    GLuint textureId;
    float opacity;
    float posX, posY;
    float scaleX, scaleY;
    float rotation;
    bool isVisible;
    float transformMatrix[16]; // Added for advanced transformations
};

class LayerCompositor {
public:
    void init();
    void composite(std::vector<Layer>& layers, int screenWidth, int screenHeight);
    void release();
private:
    void renderLayer(const Layer& layer);
    GLuint shaderProgram;
    GLuint vbo;
};

}

#endif
