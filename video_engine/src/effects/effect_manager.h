#pragma once
#include <vector>
#include <string>

namespace ClipCut {

struct EffectParam {
  int type;
  float intensity;
};

class EffectManager {
public:
  void applyEffects(int inputTex, int outputTex, const std::vector<EffectParam>& effects);

private:
  void runShader(const std::string& shaderName, int input, int output, const EffectParam& p);
};

}