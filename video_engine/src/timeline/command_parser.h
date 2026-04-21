#ifndef CLIP_CUT_COMMAND_PARSER_H
#define CLIP_CUT_COMMAND_PARSER_H

#include <string>
#include <vector>

namespace ClipCut {

class CommandParser {
public:
    static CommandParser& getInstance();
    void parseAndExecute(const std::string& jsonString);

private:
    CommandParser() = default;
};

}

#endif
