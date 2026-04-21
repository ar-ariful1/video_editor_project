#include "object_tracker.h"
namespace ClipCut {
void ObjectTracker::processFrame(const uint8_t*, int, int) {}
std::string ObjectTracker::getTrackingDataJson() { return "{\"objects\":[]}"; }
}