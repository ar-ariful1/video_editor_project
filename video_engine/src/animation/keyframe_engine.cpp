#include "keyframe_engine.h"
#include <algorithm>
#include <cmath>

namespace VideoEngine {

float KeyframeEngine::evaluate(const std::vector<Keyframe>& keyframes, double currentTimeUs) {
    if (keyframes.empty()) return 0.0f;
    if (keyframes.size() == 1 || currentTimeUs <= keyframes.front().timeUs)
        return keyframes.front().value;
    if (currentTimeUs >= keyframes.back().timeUs)
        return keyframes.back().value;

    auto it = std::lower_bound(keyframes.begin(), keyframes.end(), currentTimeUs,
        [](const Keyframe& k, double t) { return k.timeUs < t; });

    const Keyframe& next = *it;
    const Keyframe& prev = *(--it);

    float t = (float)((currentTimeUs - prev.timeUs) / (next.timeUs - prev.timeUs));

    if (next.easing == EasingType::BEZIER) {
        return interpolateBezier(prev.value, next.value, t, next.cp1x, next.cp1y, next.cp2x, next.cp2y);
    } else if (next.easing == EasingType::HOLD) {
        return prev.value;
    }

    return prev.value + (next.value - prev.value) * t;
}

float KeyframeEngine::interpolateBezier(float start, float end, float t, float x1, float y1, float x2, float y2) {
    float cx = 3.0f * x1;
    float bx = 3.0f * (x2 - x1) - cx;
    float ax = 1.0f - cx - bx;

    auto sampleCurveX = [&](float t) { return ((ax * t + bx) * t + cx) * t; };

    float t0 = t;
    for (int i = 0; i < 8; i++) {
        float x2_val = sampleCurveX(t0) - t;
        if (fabs(x2_val) < 1e-6) break;
        float d2 = (3.0f * ax * t0 + 2.0f * bx) * t0 + cx;
        if (fabs(d2) < 1e-6) break;
        t0 = t0 - x2_val / d2;
    }

    float cy = 3.0f * y1;
    float by = 3.0f * (y2 - y1) - cy;
    float ay = 1.0f - cy - by;
    return start + (end - start) * ((ay * t0 + by) * t0 + cy) * t0;
}

}
