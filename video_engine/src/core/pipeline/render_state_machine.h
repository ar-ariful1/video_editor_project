#ifndef CLIP_CUT_RENDER_STATE_MACHINE_H
#define CLIP_CUT_RENDER_STATE_MACHINE_H

namespace ClipCut {

enum class RenderState {
    IDLE,
    DECODING,
    APPLYING_EFFECTS,
    APPLYING_TRANSITIONS,
    COMPOSITING,
    ENCODING,
    ERROR
};

class RenderStateMachine {
public:
    void setState(RenderState state);
    RenderState getState() const;
    bool canTransitionTo(RenderState newState) const;
    const char* getStateString() const;

private:
    RenderState mCurrentState = RenderState::IDLE;
};

}

#endif
