#include "object_tracker.h"
#include <sstream>

namespace ClipCut {

void ObjectTracker::processFrame(const uint8_t* rgba, int width, int height) {
    // Stub
    (void)rgba; (void)width; (void)height;
}

std::string ObjectTracker::getTrackingDataJson() {
    return "{\"objects\": []}";
}

} // namespace ClipCut