# Keep Flutter
-keep class io.flutter.** { *; }

# Keep native engine
-keep class com.clipcut.app.** { *; }

# Prevent stripping native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# GL / MediaCodec safety
-keep class android.media.** { *; }
-keep class android.opengl.** { *; }