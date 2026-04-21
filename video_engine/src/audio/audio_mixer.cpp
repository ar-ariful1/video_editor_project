// video_engine/src/audio/audio_mixer.cpp
#include "audio_mixer.h"
#include <cstring>
#include <algorithm>
#include <cmath>
#include <numeric>

namespace VideoEngine {
// ... (keep all BiQuad helpers as you had them)

AudioMixer::AudioMixer(int sample_rate, int channels)
    : sample_rate_(sample_rate), channels_(channels) {}

AudioMixer::~AudioMixer() = default;

// Now using AudioTrackDesc
void AudioMixer::addTrack(const AudioTrackDesc& track) {
    std::lock_guard<std::mutex> lk(mutex_);
    tracks_[track.id] = track;
    track_states_[track.id] = TrackState{};
}

void AudioMixer::removeTrack(const std::string& id) {
    std::lock_guard<std::mutex> lk(mutex_);
    tracks_.erase(id);
    track_states_.erase(id);
}

void AudioMixer::updateTrack(const std::string& id, const AudioTrackDesc& desc) {
    std::lock_guard<std::mutex> lk(mutex_);
    tracks_[id] = desc;
}

// Feed samples (you can keep as is)
void AudioMixer::feedSamples(const std::string& track_id,
                             const std::vector<float>& samples,
                             double pts) {
    std::lock_guard<std::mutex> lk(mutex_);
    buffers_[track_id] = samples;
    // ignore pts for now
}


// ========== ADD THESE IMPLEMENTATIONS ==========

std::vector<float> AudioMixer::processTrack(
    const std::vector<float>& input,
    const AudioTrackDesc& track,
    TrackState& state,
    double time)
{
    // Simple pass-through for now (you can add EQ/fade later)
    return input;  // Return unchanged samples
}

void AudioMixer::processMasterBus(std::vector<float>& samples, int n) {
    // Apply master volume only
    for (float& s : samples) {
        s *= master_volume_;
    }
}

// Main mix - matches header
std::vector<float> AudioMixer::mix(
    const std::unordered_map<std::string, std::vector<float>>& track_samples,
    int num_samples,
    double current_time)
{
    std::lock_guard<std::mutex> lk(mutex_);
    const int total = num_samples * channels_;
    std::vector<float> output(total, 0.0f);

    for (auto& [id, samples] : track_samples) {
        auto it = tracks_.find(id);
        if (it == tracks_.end()) continue;
        const auto& track = it->second;
        auto& state       = track_states_[id];

        if (samples.empty()) continue;

        std::vector<float> processed = processTrack(samples, track, state, current_time);
        for (int i = 0; i < total && i < (int)processed.size(); i++) {
            output[i] += processed[i];
        }
    }
    processMasterBus(output, num_samples);
    return output;
}

// Alternative mix (if needed)
MixedFrame AudioMixer::mix(double time_seconds, int num_samples) {
    // Implement if required, or just return empty
    MixedFrame frame;
    return frame;
}

// processTrack – keep your existing implementation (it already matches AudioTrackDesc)
// processMasterBus – keep as is

void AudioMixer::setMasterVolume(float v) { master_volume_ = std::clamp(v, 0.0f, 2.0f); }
float AudioMixer::masterVolume() const { return master_volume_; }
void AudioMixer::setMuteAll(bool mute) { mute_all_ = mute; }
void AudioMixer::flush() { buffers_.clear(); }

// stub for unused methods
void AudioMixer::applyEQ(std::vector<float>&, const float[10]) {}
void AudioMixer::applyFade(std::vector<float>&, double, double, double, float, float, int) {}
void AudioMixer::applyPan(std::vector<float>&, float) {}

} // namespace VideoEngine