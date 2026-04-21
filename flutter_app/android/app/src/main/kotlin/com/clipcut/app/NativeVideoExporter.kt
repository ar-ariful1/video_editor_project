#include <jni.h>
#include <string>
#include <android/log.h>
#include "cut_detection/scene_detector.h"
#include "beat_sync/bpm_detector.h"
#include "subtitle/subtitle_engine.h"
#include "tracking/object_tracker.h"

#define TAG "AI_Engine_Native"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

using namespace ClipCut;
using namespace ClipCut::AI;

static SceneDetector* gSceneDetector = nullptr;
static ObjectTracker* gObjectTracker = nullptr;

// Global engine state (simplified – you can expand later)
static bool engineInitialized = false;
static int outputWidth = 1920, outputHeight = 1080;
static std::string currentTimelineJson;

extern "C" {

// ========== REQUIRED JNI FUNCTIONS for NativeVideoExporter ==========

// Add these methods inside NativeVideoExporter class

external fun setVolume(clipId: String, volume: Float)
external fun setCrop(clipId: String, left: Float, top: Float, right: Float, bottom: Float)
external fun applyEffect(clipId: String, effectId: String, params: String)
external fun getPreviewTextureId(): Int
external fun renderFrame(timeSeconds: Double)


JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nInitEngine(JNIEnv*, jobject) {
    LOGI("nInitEngine called");
    engineInitialized = true;
    // TODO: initialize your actual video processing engine here
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nReleaseEngine(JNIEnv*, jobject) {
    LOGI("nReleaseEngine called");
    engineInitialized = false;
    // TODO: clean up resources
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nUpdateTimeline(JNIEnv* env, jobject, jstring json) {
    const char* jsonStr = env->GetStringUTFChars(json, nullptr);
    currentTimelineJson = jsonStr;
    LOGI("nUpdateTimeline: %s", jsonStr);
    env->ReleaseStringUTFChars(json, jsonStr);
    // TODO: parse JSON and build internal timeline representation
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nProcessTimelineFrame(JNIEnv*, jobject, jlong timeUs) {
    // This is called for every frame during export
    // TODO: render the frame at timeUs into the encoder's input surface
    // For now, just log
    // LOGI("nProcessTimelineFrame time=%lld", timeUs);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nSetOutputResolution(JNIEnv*, jobject, jint width, jint height) {
    outputWidth = width;
    outputHeight = height;
    LOGI("nSetOutputResolution %dx%d", width, height);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nApplyAISegmentation(JNIEnv*, jobject, jint textureId) {
    LOGI("nApplyAISegmentation textureId=%d", textureId);
    // TODO: implement AI segmentation on the given OpenGL texture
}

// ========== Existing AI functions ==========

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStartSceneDetection(JNIEnv*, jobject) {
    delete gSceneDetector;
    gSceneDetector = new SceneDetector();
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nAnalyzeFrameForAI(JNIEnv* env, jobject,
                                                             jbyteArray rgba, jint w, jint h, jlong timeUs) {
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