#pragma once

#include <vector>
#include <map>
#include <unordered_map>
#include <memory>
#include <functional>
#include <string>
#include <mutex>
#include <algorithm>
#include <cstdint>

namespace VideoEngine {

// EQ band structure
struct EQSettings {
    float low_gain_db = 0.0f;
    float mid_gain_db = 0.0f;
    float high_gain_db = 0.0f;
    float low_freq = 100.0f;
    float mid_freq = 1000.0f;
    float high_freq = 8000.0f;
};

// Compressor settings
struct CompressorSettings {
    bool enabled = false;
    float threshold_db = -12.0f;
    float ratio = 4.0f;
    float knee_db = 6.0f;
    float attack_ms = 10.0f;
    float release_ms = 100.0f;
    float makeup_gain_db = 0.0f;
};

// Full audio track description (matching cpp usage)
struct AudioTrackDesc {
    std::string id;
    double start_time = 0.0;
    double end_time = 0.0;
    float volume = 1.0f;
    float pan = 0.0f;
    float fade_in_sec = 0.0f;
    float fade_out_sec = 0.0f;
    EQSettings eq;
    CompressorSettings compressor;
    float reverb = 0.0f;           // 0..1
    float noise_reduction = 0.0f;  // 0..1
};

// For internal state
struct TrackState {
    float gain = 1.0f;
    float pan = 0.0f;
    bool active = true;
    float comp_gain = 1.0f;
    std::vector<float> reverb_buf[2];  // per channel
    int reverb_pos = 0;
    float noise_avg[2] = {0.0f, 0.0f};
    // EQ states (per channel)
    struct BiQuadState { float x1=0,x2=0,y1=0,y2=0; };
    BiQuadState eq_low[2], eq_mid[2], eq_high[2];
};

// Configuration struct for backward compatibility (if needed)
struct AudioTrackConfig {
    std::string track_id;
    float volume = 1.0f;
    float pan = 0.0f;
    bool muted = false;
    bool solo = false;
    float fade_in_duration = 0.0f;
    float fade_out_duration = 0.0f;
    double start_time = 0.0;
    double end_time = 0.0;
    float eq_bands[10] = {0};
};

struct MixedFrame {
    std::vector<float> samples;
    int sample_count;
    int sample_rate;
    double pts;
};

class AudioMixer {
public:
    AudioMixer(int sample_rate = 44100, int channels = 2);
    ~AudioMixer();

    // New methods matching your .cpp
    void addTrack(const AudioTrackDesc& track);
    void removeTrack(const std::string& track_id);
    void updateTrack(const std::string& id, const AudioTrackDesc& desc);

    void feedSamples(const std::string& track_id,
                     const std::vector<float>& samples,
                     double pts);

    // Main mix function (signature from .cpp)
    std::vector<float> mix(
        const std::unordered_map<std::string, std::vector<float>>& track_samples,
        int num_samples,
        double current_time);

    MixedFrame mix(double time_seconds, int num_samples); // alternative

    void setMasterVolume(float vol);
    float masterVolume() const;

    void setMuteAll(bool mute);
    void flush();

private:
    int sample_rate_;
    int channels_;
    float master_volume_ = 1.0f;
    bool mute_all_ = false;

    std::mutex mutex_;

    std::map<std::string, AudioTrackDesc> tracks_;  // changed to AudioTrackDesc
    std::unordered_map<std::string, std::vector<float>> buffers_;
    std::unordered_map<std::string, TrackState> track_states_;

    // Helper functions (declared)
    std::vector<float> processTrack(const std::vector<float>& input,
                                    const AudioTrackDesc& track,
                                    TrackState& state,
                                    double time);
    void processMasterBus(std::vector<float>& samples, int n);

    void applyEQ(std::vector<float>& buf, const float eq_bands[10]);
    void applyFade(std::vector<float>& buf, double pts,
                   double start, double end,
                   float fade_in, float fade_out,
                   int sample_rate);
    void applyPan(std::vector<float>& buf, float pan);
};

} // namespace VideoEngine