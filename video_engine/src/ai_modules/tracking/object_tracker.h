#pragma once

#include <string>
#include <vector>

namespace ClipCut {

class ObjectTracker {
public:
    ObjectTracker() = default;
    ~ObjectTracker() = default;

    void processFrame(const uint8_t* rgba, int width, int height);
    std::string getTrackingDataJson();

private:
    // Stub – real tracking would store bounding boxes
};

} // namespace ClipCut