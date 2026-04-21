#include "bpm_detector.h"
#include <sstream>

namespace ClipCut {

void BPMDetector::processAudio(const short* pcm, int length) {
    // Stub: you can add a simple BPM detection later
    (void)pcm; (void)length;
}

std::string BPMDetector::detectBeats() {
    return "{\"bpm\": 120.0, \"beats\": []}";
}

} // namespace ClipCut