import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/video_project.dart';

/**
 * NativeEngineService (PRODUCTION GRADE)
 * Bridge between Flutter (Dart) and Native MediaCodec + OpenGL Engine
 *
 * Features:
 * - Native Export (MediaCodec + GLRenderEngine)
 * - Progress Stream (frame accurate updates)
 * - Media utilities (thumbnail, info, save)
 * - Safe lifecycle handling
 * - Null-safe + crash-safe communication
 */
class NativeEngineService {
  static final NativeEngineService _instance = NativeEngineService._internal();
  factory NativeEngineService() => _instance;

  NativeEngineService._internal();

  // ─────────────────────────────────────────────
  // Channels
  // ─────────────────────────────────────────────

  static const MethodChannel _nativeChannel =
      MethodChannel('com.clipcut.app/native_engine');

  static const MethodChannel _utilityChannel =
      MethodChannel('com.clipcut.app/engine');

  static const EventChannel _progressChannel =
      EventChannel('com.clipcut.app/export_progress');

  StreamSubscription? _progressSub;
  final StreamController<int> _progressController =
      StreamController<int>.broadcast();

  Stream<int> get exportProgress => _progressController.stream;

  bool _isListening = false;

  // ─────────────────────────────────────────────
  // INIT STREAM SAFE
  // ─────────────────────────────────────────────

  void initProgressListener() {
    if (_isListening) return;

    _progressSub = _progressChannel
        .receiveBroadcastStream()
        .listen((event) {
          try {
            final progress = (event as num).toInt();
            _progressController.add(progress);
          } catch (e) {
            debugPrint("Progress parse error: $e");
          }
        }, onError: (e) {
          debugPrint("Progress stream error: $e");
        });

    _isListening = true;
  }

  void dispose() {
    _progressSub?.cancel();
    _progressController.close();
    _isListening = false;
  }

  // ─────────────────────────────────────────────
  // 🚀 NATIVE EXPORT ENGINE (MAIN)
  // ─────────────────────────────────────────────

  // Add these methods to the existing class

Future<void> setVolume(String clipId, double volume) async {
  try {
    await _nativeChannel.invokeMethod('setVolume', {
      'clipId': clipId,
      'volume': volume,
    });
  } catch (e) {
    debugPrint('setVolume error: $e');
  }
}

Future<void> setCrop(String clipId, Rect cropRect) async {
  try {
    await _nativeChannel.invokeMethod('setCrop', {
      'clipId': clipId,
      'left': cropRect.left,
      'top': cropRect.top,
      'right': cropRect.right,
      'bottom': cropRect.bottom,
    });
  } catch (e) {
    debugPrint('setCrop error: $e');
  }
}

Future<void> applyEffect(String clipId, String effectId, Map<String, dynamic> params) async {
  try {
    await _nativeChannel.invokeMethod('applyEffect', {
      'clipId': clipId,
      'effectId': effectId,
      'params': params,
    });
  } catch (e) {
    debugPrint('applyEffect error: $e');
  }
}

Future<int?> getPreviewTextureId() async {
  try {
    final id = await _nativeChannel.invokeMethod<int>('getPreviewTextureId');
    return id;
  } catch (e) {
    debugPrint('getPreviewTextureId error: $e');
    return null;
  }
}

Future<void> renderFrame(double timeSeconds) async {
  try {
    await _nativeChannel.invokeMethod('renderFrame', {'time': timeSeconds});
  } catch (e) {
    // ignore
  }
}

  Future<String?> startNativeExport({
    required VideoProject project,
    required String outputPath,
    int width = 1080,
    int height = 1920,
    int fps = 30,
    String quality = "STANDARD",
  }) async {
    try {
      initProgressListener();

      final result = await _nativeChannel.invokeMethod<String>(
        'startExport',
        {
          'project': project.toJson(),
          'outputPath': outputPath,
          'width': width,
          'height': height,
          'fps': fps,
          'quality': quality,
        },
      );

      return result;
    } on PlatformException catch (e) {
      debugPrint("❌ Native Export Failed: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("❌ Unknown Export Error: $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 🖼 THUMBNAIL GENERATOR
  // ─────────────────────────────────────────────

  Future<String?> getThumbnail({
    required String videoPath,
    required double timeSeconds,
  }) async {
    try {
      final result = await _utilityChannel.invokeMethod<String>(
        'getThumbnail',
        {
          'path': videoPath,
          'time': timeSeconds,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint("Thumbnail Error: ${e.message}");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 📊 MEDIA INFO (DURATION, SIZE, FPS)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMediaInfo(String videoPath) async {
    try {
      final result = await _utilityChannel.invokeMethod(
        'getMediaInfo',
        {'path': videoPath},
      );

      return result != null
          ? Map<String, dynamic>.from(result)
          : null;
    } on PlatformException catch (e) {
      debugPrint("MediaInfo Error: ${e.message}");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 💾 SAVE TO GALLERY
  // ─────────────────────────────────────────────

  Future<bool> saveToGallery(String videoPath) async {
    try {
      final result = await _utilityChannel.invokeMethod<bool>(
        'saveToGallery',
        {'path': videoPath},
      );

      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("Save Gallery Error: ${e.message}");
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // ⚡ EXTRA: CANCEL EXPORT (Optional support)
  // ─────────────────────────────────────────────

  Future<bool> cancelExport() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('cancelExport');
      return result ?? false;
    } catch (e) {
      debugPrint("Cancel Export Error: $e");
      return false;
    }
  }
}