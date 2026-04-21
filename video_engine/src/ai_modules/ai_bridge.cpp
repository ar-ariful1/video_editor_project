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


extern "C" {

// Scene detection
JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStartSceneDetection(JNIEnv*, jobject) {
    delete gSceneDetector;
    gSceneDetector = new SceneDetector();
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nAnalyzeFrameForAI(JNIEnv* env, jobject,
                                                             jbyteArray rgba,
                                                             jint w, jint h,
                                                             jlong timeUs) {
    if (!gSceneDetector) return;

    jbyte* data = env->GetByteArrayElements(rgba, nullptr);
    if (!data) return;

    gSceneDetector->processFrame((uint8_t*)data, w, h, timeUs);

    env->ReleaseByteArrayElements(rgba, data, JNI_ABORT);
}

JNIEXPORT jstring JNICALL
Java_com_clipcut_app_NativeVideoExporter_nStopSceneDetection(JNIEnv* env, jobject) {
    if (!gSceneDetector) return env->NewStringUTF("{}");

    std::string result = gSceneDetector->getJsonResult();

    delete gSceneDetector;
    gSceneDetector = nullptr;

    return env->NewStringUTF(result.c_str());
}

// BPM
JNIEXPORT jstring JNICALL
Java_com_clipcut_app_NativeVideoExporter_nAnalyzeAudioBeats(JNIEnv* env, jobject,
                                                             jshortArray pcm) {
    BPMDetector detector;

    jshort* data = env->GetShortArrayElements(pcm, nullptr);
    jsize len = env->GetArrayLength(pcm);

    detector.processAudio(data, len);
    std::string result = detector.detectBeats();

    env->ReleaseShortArrayElements(pcm, data, JNI_ABORT);

    return env->NewStringUTF(result.c_str());
}

// Tracking
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

}