#pragma once
#include <string>

namespace ClipCut {
class SubtitleEngine {
public:
    void processAudio(const float* samples, int count, int sample_rate);
    std::string generateSubtitles();
};
}