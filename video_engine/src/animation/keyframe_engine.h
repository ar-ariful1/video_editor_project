#ifndef KEYFRAME_ENGINE_H
#define KEYFRAME_ENGINE_H

#include <vector>

namespace VideoEngine {

enum class EasingType { LINEAR = 0, BEZIER = 1, HOLD = 2 };

struct Keyframe {
    double timeUs;
    float value;
    EasingType easing;
    float cp1x, cp1y, cp2x, cp2y;
};

class KeyframeEngine {
public:
    float evaluate(const std::vector<Keyframe>& keyframes, double currentTimeUs);
private:
    float interpolateBezier(float start, float end, float t, float x1, float y1, float x2, float y2);
};

}

#endif
