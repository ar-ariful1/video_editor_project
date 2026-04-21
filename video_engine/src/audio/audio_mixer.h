#pragma once
#include <vector>
#include <map>
#include <string>
#include <mutex>
#include <unordered_map>
#include <cmath>

namespace VideoEngine {

struct AudioTrackDesc {
    std::string id;
    double start_time = 0.0;
    double end_time = 0.0;
    float volume = 1.0f;
    float pan = 0.0f;
    float fade_in_sec = 0.0f;
    float fade_out_sec = 0.0f;
    // EQ (simplified)
    float eq_low_gain = 0.0f;
    float eq_mid_gain = 0.0f;
    float eq_high_gain = 0.0f;
};

struct TrackState {
    float gain = 1.0f;
    float pan = 0.0f;
};

class AudioMixer {
public:
    AudioMixer(int sample_rate = 44100, int channels = 2);
    ~AudioMixer();

    void addTrack(const AudioTrackDesc& track);
    void removeTrack(const std::string& id);
    void updateTrack(const std::string& id, const AudioTrackDesc& desc);
    void setTrackVolume(const std::string& id, float volume);
    
    std::vector<float> mix(const std::unordered_map<std::string, std::vector<float>>& track_samples,
                           int num_samples, double current_time);
    void setMasterVolume(float vol);
    float masterVolume() const;

private:
    int sample_rate_;
    int channels_;
    float master_volume_ = 1.0f;
    std::mutex mutex_;
    std::map<std::string, AudioTrackDesc> tracks_;
    std::unordered_map<std::string, TrackState> track_states_;
    
    std::vector<float> processTrack(const std::vector<float>& input,
                                    const AudioTrackDesc& track,
                                    TrackState& state,
                                    double time);
    void processMasterBus(std::vector<float>& samples, int n);
};

} // namespace