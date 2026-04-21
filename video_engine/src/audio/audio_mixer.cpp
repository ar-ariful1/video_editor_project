#include "audio_mixer.h"
#include <algorithm>
#include <cstring>

namespace VideoEngine {

AudioMixer::AudioMixer(int rate, int ch) : sample_rate_(rate), channels_(ch) {}
AudioMixer::~AudioMixer() = default;

void AudioMixer::addTrack(const AudioTrackDesc& t) {
    std::lock_guard<std::mutex> lock(mutex_);
    tracks_[t.id] = t;
    track_states_[t.id] = TrackState{};
}

void AudioMixer::removeTrack(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    tracks_.erase(id);
    track_states_.erase(id);
}

void AudioMixer::updateTrack(const std::string& id, const AudioTrackDesc& desc) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (tracks_.find(id) != tracks_.end()) {
        tracks_[id] = desc;
    }
}

void AudioMixer::setTrackVolume(const std::string& id, float volume) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (tracks_.find(id) != tracks_.end()) {
        tracks_[id].volume = volume;
    }
}

std::vector<float> AudioMixer::mix(const std::unordered_map<std::string, std::vector<float>>& track_samples,
                                   int num_samples, double current_time) {
    std::lock_guard<std::mutex> lock(mutex_);
    int total = num_samples * channels_;
    std::vector<float> output(total, 0.0f);
    
    for (const auto& pair : track_samples) {
        const std::string& id = pair.first;
        const std::vector<float>& samples = pair.second;
        auto it = tracks_.find(id);
        if (it == tracks_.end()) continue;
        
        auto& state = track_states_[id];
        std::vector<float> processed = processTrack(samples, it->second, state, current_time);
        for (size_t i = 0; i < processed.size() && i < output.size(); ++i) {
            output[i] += processed[i];
        }
    }
    
    processMasterBus(output, num_samples);
    return output;
}

std::vector<float> AudioMixer::processTrack(const std::vector<float>& input,
                                            const AudioTrackDesc& track,
                                            TrackState& state,
                                            double time) {
    std::vector<float> out = input;
    int n = out.size() / channels_;
    
    // Volume
    float gain = track.volume;
    
    // Fade in/out
    if (track.fade_in_sec > 0 || track.fade_out_sec > 0) {
        for (int i = 0; i < n; ++i) {
            double t = time + (double)i / sample_rate_;
            double fadeGain = 1.0;
            if (track.fade_in_sec > 0 && t < track.start_time + track.fade_in_sec) {
                fadeGain *= (t - track.start_time) / track.fade_in_sec;
            }
            if (track.fade_out_sec > 0 && t > track.end_time - track.fade_out_sec) {
                fadeGain *= (track.end_time - t) / track.fade_out_sec;
            }
            gain *= fadeGain;
        }
    }
    
    // Apply gain
    for (float& s : out) s *= gain;
    
    // Simple pan (stereo only)
    if (channels_ == 2 && track.pan != 0.0f) {
        float left = (track.pan <= 0) ? 1.0f : 1.0f - track.pan;
        float right = (track.pan >= 0) ? 1.0f : 1.0f + track.pan;
        for (int i = 0; i < n; ++i) {
            out[i*2] *= left;
            out[i*2+1] *= right;
        }
    }
    
    return out;
}

void AudioMixer::processMasterBus(std::vector<float>& samples, int n) {
    for (float& s : samples) s *= master_volume_;
}

void AudioMixer::setMasterVolume(float v) {
    master_volume_ = std::max(0.0f, std::min(2.0f, v));
}

float AudioMixer::masterVolume() const { return master_volume_; }

} // namespace