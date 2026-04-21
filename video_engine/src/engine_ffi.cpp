#include <jni.h>
#include <string>
#include <vector>
#include <memory>
#include <android/log.h>
#include "animation/keyframe_engine.h"
#include "compositor/layer_compositor.h"
#include "timeline/command_parser.h"

#define TAG "VideoEngine_Native"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

using namespace VideoEngine;
using namespace ClipCut;

static std::unique_ptr<KeyframeEngine> g_keyframeEngine;
static std::unique_ptr<LayerCompositor> g_compositor;
static int g_width = 1080;
static int g_height = 1920;

extern "C" {

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nInitEngine(JNIEnv *env, jobject thiz) {
    LOGI("Initializing Native Video Engine for Exporter...");
    g_keyframeEngine = std::make_unique<KeyframeEngine>();
    g_compositor = std::make_unique<LayerCompositor>();
    g_compositor->init();
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nSetOutputResolution(JNIEnv *env, jobject thiz, jint width, jint height) {
    g_width = width;
    g_height = height;
    LOGI("Resolution set to: %dx%d", width, height);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nUpdateTimeline(JNIEnv *env, jobject thiz, jstring json) {
    const char *jsonStr = env->GetStringUTFChars(json, nullptr);
    LOGI("Updating Timeline with JSON: %s", jsonStr);
    CommandParser::getInstance().parseAndExecute(jsonStr);
    env->ReleaseStringUTFChars(json, jsonStr);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nProcessTimelineFrame(JNIEnv *env, jobject thiz, jlong timeUs) {
    if (!g_compositor) return;

    // In a real production scenario, we'd fetch the active layers from a global store
    // or pass them via JSON. For now, we trigger the composite pass.
    std::vector<Layer> layers;
    g_compositor->composite(layers, g_width, g_height);
}

JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nReleaseEngine(JNIEnv *env, jobject thiz) {
    LOGI("Releasing Native Video Engine...");
    if (g_compositor) g_compositor->release();
    g_keyframeEngine.reset();
    g_compositor.reset();
}

// AI Module Link: Background Removal
JNIEXPORT void JNICALL
Java_com_clipcut_app_NativeVideoExporter_nApplyAISegmentation(JNIEnv *env, jobject thiz, jint textureId) {
    LOGI("Applying AI Background Removal to texture: %d", textureId);
    // Link to ai_modules/rmbg_service via gRPC or internal C++ logic
}

}
