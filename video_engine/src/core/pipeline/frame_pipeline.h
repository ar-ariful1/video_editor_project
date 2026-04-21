#ifndef CLIP_CUT_FRAME_PIPELINE_H
#define CLIP_CUT_FRAME_PIPELINE_H

#include "../../decoder/video_decoder.h"
#include "../../effects/effect_manager.h"
#include "../../transitions/transition_engine.h"
#include "../../encoder/video_encoder.h"

namespace ClipCut {

class FramePipeline {
public:
    void processFrame(long pts);
    void setOutputSurface(void* surface);

private:
    // Pointers to core modules
    // VideoDecoder* mDecoder;
    // EffectManager* mEffectManager;
    // TransitionEngine* mTransitionEngine;
    // VideoEncoder* mEncoder;

    int mEffectTex;
    int mFinalTex;
};

}

#endif
