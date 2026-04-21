#pragma once

#include <string>
#include <vector>

namespace ClipCut {

class BPMDetector {
public:
    BPMDetector() = default;
    ~BPMDetector() = default;

    void processAudio(const short* pcm, int length);
    std::string detectBeats();

private:
    // Simple stub – replace with real algorithm later
    float estimated_bpm_ = 120.0f;
};

} // namespace ClipCut