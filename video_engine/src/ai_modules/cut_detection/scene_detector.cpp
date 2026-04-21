#include "scene_detector.h"
#include <cmath>
#include <sstream>
#include <algorithm>

namespace ClipCut {
namespace AI {

std::vector<uint32_t> SceneDetector::computeHistogram(const uint8_t* rgba, int w, int h) {
    std::vector<uint32_t> hist(768, 0);
    for (int i = 0; i < w * h; ++i) {
        hist[rgba[i*4]]++;
        hist[256 + rgba[i*4+1]]++;
        hist[512 + rgba[i*4+2]]++;
    }
    return hist;
}

float SceneDetector::compare(const std::vector<uint32_t>& h1, const std::vector<uint32_t>& h2) {
    float diff = 0, total = 0;
    for (size_t i = 0; i < h1.size(); ++i) {
        diff += std::abs((float)h1[i] - (float)h2[i]);
        total += (float)h1[i] + (float)h2[i];
    }
    return total > 0 ? diff / total : 0;
}

void SceneDetector::processFrame(const uint8_t* rgba, int w, int h, long timeUs) {
    auto hist = computeHistogram(rgba, w, h);
    if (!lastHist.empty()) {
        float dist = compare(lastHist, hist);
        if (dist > THRESHOLD) {
            cuts.push_back({timeUs, dist, currentFrame});
        }
    }
    lastHist = hist;
    currentFrame++;
}

std::string SceneDetector::getJsonResult() {
    std::stringstream ss;
    ss << "{\"cuts\": [";
    for (size_t i = 0; i < cuts.size(); ++i) {
        ss << "{\"time\":" << cuts[i].timestampUs
           << ",\"score\":" << cuts[i].confidence
           << ",\"index\":" << cuts[i].frameIndex << "}";
        if (i < cuts.size() - 1) ss << ",";
    }
    ss << "]}";
    return ss.str();
}

} // namespace AI
} // namespace ClipCut