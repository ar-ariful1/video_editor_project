#pragma once

#include <vector>
#include <string>
#include <cstdint>

namespace ClipCut {
namespace AI {

struct SceneCut {
    long timestampUs;
    float confidence;
    int frameIndex;
};

class SceneDetector {
public:
    SceneDetector() = default;
    ~SceneDetector() = default;

    void processFrame(const uint8_t* rgba, int w, int h, long timeUs);
    std::string getJsonResult();

private:
    std::vector<uint32_t> lastHist;
    std::vector<SceneCut> cuts;
    const float THRESHOLD = 0.65f;
    int currentFrame = 0;

    std::vector<uint32_t> computeHistogram(const uint8_t* rgba, int w, int h);
    float compare(const std::vector<uint32_t>& h1, const std::vector<uint32_t>& h2);
};

} // namespace AI
} // namespace ClipCut