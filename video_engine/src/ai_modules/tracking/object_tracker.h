#pragma once
#include <string>

namespace ClipCut {
class ObjectTracker {
public:
    void processFrame(const uint8_t* rgba, int width, int height);
    std::string getTrackingDataJson();
};
}