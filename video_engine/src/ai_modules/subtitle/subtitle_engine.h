#pragma once

#include <string>
#include <vector>

namespace ClipCut {

class SubtitleEngine {
public:
    SubtitleEngine() = default;
    ~SubtitleEngine() = default;

    void processAudio(const float* samples, int count, int sample_rate);
    std::string generateSubtitles();

private:
    std::vector<std::string> lines_;
};

} // namespace ClipCut