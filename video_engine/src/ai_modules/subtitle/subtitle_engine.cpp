#include "subtitle_engine.h"
#include <sstream>

namespace ClipCut {

void SubtitleEngine::processAudio(const float* samples, int count, int sample_rate) {
    // Stub
    (void)samples; (void)count; (void)sample_rate;
}

std::string SubtitleEngine::generateSubtitles() {
    return "{\"subtitles\": []}";
}

} // namespace ClipCut