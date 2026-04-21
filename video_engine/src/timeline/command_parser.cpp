#include "command_parser.h"
#include "../compositor/layer_compositor.h"
#include <iostream>
#include <vector>

namespace ClipCut {

CommandParser& CommandParser::getInstance() {
    static CommandParser instance;
    return instance;
}

void CommandParser::parseAndExecute(const std::string& jsonString) {
    // Note: In a production build, we'd use nlohmann/json here.
    // For this demonstration, we simulate the extraction of layers from the JSON project.

    std::cout << "Parsing Timeline Command: " << jsonString << std::endl;

    // Example: Create internal Layer objects from JSON data
    // std::vector<VideoEngine::Layer> activeLayers;
    // ... logic to populate layers ...

    // The Compositor will then use these layers in the next nProcessTimelineFrame call.
}

}
