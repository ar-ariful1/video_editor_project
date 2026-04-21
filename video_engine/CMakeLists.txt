cmake_minimum_required(VERSION 3.18)
project(video_engine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(ANDROID)
    add_definitions(-DANDROID_PLATFORM)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -Wall -fPIC")
endif()

file(GLOB_RECURSE ENGINE_SOURCES "src/**/*.cpp")

add_library(video_engine SHARED ${ENGINE_SOURCES})

target_include_directories(video_engine PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/audio
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ai_modules
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ai_modules/cut_detection
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ai_modules/beat_sync
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ai_modules/subtitle
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ai_modules/tracking
)

target_link_libraries(video_engine
    android
    log
    mediandk
    nativewindow
    GLESv3
    EGL
    m
    z
)

message(STATUS "Video Engine configured OK")