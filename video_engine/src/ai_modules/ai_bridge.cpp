#include <jni.h>
#include <string>
#include <android/log.h>
#include <vector>
#include <map>
#include <mutex>

// AI headers (stubs for now)
#include "cut_detection/scene_detector.h"
#include "beat_sync/bpm_detector.h"
#include "subtitle/subtitle_engine.h"
#include "tracking/object_tracker.h"

// Audio mixer
#include "../audio/audio_mixer.h"

#define TAG "VideoEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

using namespace ClipCut;
using namespace ClipCut::AI;
using namespace VideoEngine;

// Global instances
static SceneDetector* gSceneDetector = nullptr;
static ObjectTracker* gObjectTracker = nullptr;
static AudioMixer* gAudioMixer = nullptr;
static bool engineInitialized = false;
static int outputWidth = 1080, outputHeight = 1920;
static std::string currentTimelineJson;
static std::mutex gMutex;

// For preview texture (simplified)
static int gPreviewTextureId = -1;
static double gCurrentFrameTime = 0.0;

extern "C" {

// ========== REQUIRED JNI FUNCTIONS for NativeVideoExporter ==========

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nInitEngine(JNIEnv* env, jobject) {
    LOGI("nInitEngine called");
    std::lock_guard<std::mutex> lock(gMutex);
    engineInitialized = true;
    gAudioMixer = new AudioMixer(44100, 2);
    LOGI("Engine initialized with audio mixer");
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nReleaseEngine(JNIEnv*, jobject) {
    LOGI("nReleaseEngine called");
    std::lock_guard<std::mutex> lock(gMutex);
    engineInitialized = false;
    delete gAudioMixer;
    gAudioMixer = nullptr;
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nUpdateTimeline(JNIEnv* env, jobject, jstring json) {
    const char* jsonStr = env->GetStringUTFChars(json, nullptr);
    LOGI("nUpdateTimeline: %s", jsonStr);
    currentTimelineJson = jsonStr;
    env->ReleaseStringUTFChars(json, jsonStr);
    // TODO: parse JSON and update internal timeline representation
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nProcessTimelineFrame(JNIEnv*, jobject, jlong timeUs) {
    // Called for each frame during export/preview
    gCurrentFrameTime = timeUs / 1000000.0;
    // TODO: render frame at this time
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nSetOutputResolution(JNIEnv*, jobject, jint width, jint height) {
    LOGI("nSetOutputResolution %dx%d", width, height);
    outputWidth = width;
    outputHeight = height;
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nApplyAISegmentation(JNIEnv*, jobject, jint textureId) {
    LOGI("nApplyAISegmentation textureId=%d", textureId);
    // AI segmentation stub
}

// ========== ADDITIONAL METHODS FOR EDITING TOOLS ==========

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nSetVolume(JNIEnv* env, jobject, jstring clipId, jfloat volume) {
    const char* id = env->GetStringUTFChars(clipId, nullptr);
    LOGI("setVolume clip=%s volume=%f", id, volume);
    // TODO: update volume in audio mixer
    env->ReleaseStringUTFChars(clipId, id);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nSetCrop(JNIEnv* env, jobject, jstring clipId, jfloat left, jfloat top, jfloat right, jfloat bottom) {
    const char* id = env->GetStringUTFChars(clipId, nullptr);
    LOGI("setCrop clip=%s crop=[%f,%f,%f,%f]", id, left, top, right, bottom);
    env->ReleaseStringUTFChars(clipId, id);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nApplyEffect(JNIEnv* env, jobject, jstring clipId, jstring effectId, jstring params) {
    const char* id = env->GetStringUTFChars(clipId, nullptr);
    const char* effect = env->GetStringUTFChars(effectId, nullptr);
    LOGI("applyEffect clip=%s effect=%s", id, effect);
    env->ReleaseStringUTFChars(clipId, id);
    env->ReleaseStringUTFChars(effectId, effect);
}

JNIEXPORT jint JNICALL
Java_com_clipcut_app_NativeVideoExporter_nGetPreviewTextureId(JNIEnv*, jobject) {
    // In real implementation, this would return a SurfaceTexture ID
    // For now, return -1 to indicate not ready
    LOGI("getPreviewTextureId returning %d", gPreviewTextureId);
    return gPreviewTextureId;
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nRenderFrame(JNIEnv*, jobject, jdouble timeSeconds) {
    gCurrentFrameTime = timeSeconds;
    // Trigger render
}

// ========== AI FUNCTIONS (already present) ==========

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStartSceneDetection(JNIEnv*, jobject) {
    delete gSceneDetector;
    gSceneDetector = new SceneDetector();
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nAnalyzeFrameForAI(JNIEnv* env, jobject, jbyteArray rgba, jint w, jint h, jlong timeUs) {
    if (!gSceneDetector) return;
    jbyte* data = env->GetByteArrayElements(rgba, nullptr);
    if (data) {
        gSceneDetector->processFrame((uint8_t*)data, w, h, timeUs);
        env->ReleaseByteArrayElements(rgba, data, JNI_ABORT);
    }
}

JNIEXPORT jstring JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStopSceneDetection(JNIEnv* env, jobject) {
    if (!gSceneDetector) return env->NewStringUTF("{}");
    std::string result = gSceneDetector->getJsonResult();
    delete gSceneDetector;
    gSceneDetector = nullptr;
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_clipcut_app_NativeVideoExporter_nAnalyzeAudioBeats(JNIEnv* env, jobject, jshortArray pcm) {
    BPMDetector detector;
    jshort* data = env->GetShortArrayElements(pcm, nullptr);
    jsize len = env->GetArrayLength(pcm);
    detector.processAudio(data, len);
    std::string result = detector.detectBeats();
    env->ReleaseShortArrayElements(pcm, data, JNI_ABORT);
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStartTracking(JNIEnv*, jobject) {
    delete gObjectTracker;
    gObjectTracker = new ObjectTracker();
}

JNIEXPORT jstring JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStopTracking(JNIEnv* env, jobject) {
    if (!gObjectTracker) return env->NewStringUTF("{}");
    std::string result = gObjectTracker->getTrackingDataJson();
    delete gObjectTracker;
    gObjectTracker = nullptr;
    return env->NewStringUTF(result.c_str());
}

} // extern "C"