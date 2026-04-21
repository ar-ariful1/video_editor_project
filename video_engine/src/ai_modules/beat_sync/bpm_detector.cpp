#include "bpm_detector.h"
namespace ClipCut {
void BPMDetector::processAudio(const short*, int) {}
std::string BPMDetector::detectBeats() { return "{\"bpm\":120}"; }
}