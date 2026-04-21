#pragma once
#include <string>

namespace ClipCut {
class BPMDetector {
public:
    void processAudio(const short* pcm, int length);
    std::string detectBeats();
};
}