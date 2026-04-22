// lib/core/engine/native_engine_bridge.dart
import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeEngineBridge {
  static const MethodChannel _methodChannel = MethodChannel('com.clipcut.app/native_engine');
  static const EventChannel _progressChannel = EventChannel('com.clipcut.app/export_progress');

  // Singleton pattern
  static final NativeEngineBridge _instance = NativeEngineBridge._internal();
  factory NativeEngineBridge() => _instance;
  NativeEngineBridge._internal();

  // --------------------------------------------------------------------------
  // Engine lifecycle
  // --------------------------------------------------------------------------
  Future<void> initialize() async {
    await _methodChannel.invokeMethod('initialize');
  }

  Future<void> release() async {
    await _methodChannel.invokeMethod('release');
  }

  Future<void> applyEffect(String clipId, String effectId, Map<String, dynamic> params) async {
    await _methodChannel.invokeMethod('applyEffect', {
     'clipId': clipId,
     'effectId': effectId,
     'params': params,
    });
  }

 Future<void> setCrop(String clipId, Rect cropRect) async {
   await _methodChannel.invokeMethod('setCrop', {
     'clipId': clipId,
     'left': cropRect.left,
     'top': cropRect.top,
     'right': cropRect.right,
     'bottom': cropRect.bottom,
   });
 }

  // --------------------------------------------------------------------------
  // Video loading and rendering
  // --------------------------------------------------------------------------
  /// Load a video file and return its metadata
  Future<VideoMetadata> loadVideo(String filePath) async {
    final result = await _methodChannel.invokeMethod('loadVideo', {'path': filePath});
    return VideoMetadata.fromMap(Map<String, dynamic>.from(result));
  }

  /// Get a texture ID for Flutter Texture widget
  Future<int> createVideoTexture() async {
    return await _methodChannel.invokeMethod('createVideoTexture');
  }

  /// Render a specific frame at time (microseconds)
  Future<void> renderFrameAt(int timeUs) async {
    await _methodChannel.invokeMethod('renderFrameAt', {'timeUs': timeUs});
  }

  /// Seek to a position and update preview
  Future<void> seekTo(int timeUs) async {
    await _methodChannel.invokeMethod('seekTo', {'timeUs': timeUs});
  }

  // --------------------------------------------------------------------------
  // Playback control
  // --------------------------------------------------------------------------
  Future<void> play() async {
    await _methodChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
  }

  Future<bool> isPlaying() async {
    return await _methodChannel.invokeMethod('isPlaying');
  }

  // --------------------------------------------------------------------------
  // Effects & Adjustments
  // --------------------------------------------------------------------------
  Future<void> setBrightness(double value) async {
    await _methodChannel.invokeMethod('setBrightness', {'value': value});
  }

  Future<void> setContrast(double value) async {
    await _methodChannel.invokeMethod('setContrast', {'value': value});
  }

  Future<void> setSaturation(double value) async {
    await _methodChannel.invokeMethod('setSaturation', {'value': value});
  }

  Future<void> setOpacity(double value) async {
    await _methodChannel.invokeMethod('setOpacity', {'value': value});
  }

  // --------------------------------------------------------------------------
  // Audio controls
  // --------------------------------------------------------------------------
  Future<void> setVolume(String clipId, double volume) async {
    await _methodChannel.invokeMethod('setVolume', {
      'clipId': clipId,
      'volume': volume,
    });
  }

  Future<Uint8List?> getAudioWaveform(String path) async {
    final result = await _methodChannel.invokeMethod('getAudioWaveform', {'path': path});
    if (result is Uint8List) return result;
    return null;
  }

  Future<void> cancelExport() async {
    await _methodChannel.invokeMethod('cancelExport');
  }

  // --------------------------------------------------------------------------
  // Export
  // --------------------------------------------------------------------------
  Future<void> startExport(ExportConfig config) async {
    await _methodChannel.invokeMethod('startExport', config.toMap());
  }

  /// Export progress stream (0.0 to 1.0)
  Stream<double> get exportProgress {
    return _progressChannel.receiveBroadcastStream().map((event) {
      if (event is int) return event / 100.0;
      if (event is double) return event;
      return 0.0;
    });
  }

  /// Export status stream (e.g., 'exporting', 'completed', 'error')
  Stream<String> get exportStatus {
    return _progressChannel.receiveBroadcastStream().map((event) {
      if (event is String) return event;
      return event.toString();
    });
  }
}

// ----------------------------------------------------------------------------
// Data Models
// ----------------------------------------------------------------------------
class VideoMetadata {
  final int width;
  final int height;
  final int durationUs;
  final double frameRate;

  VideoMetadata({
    required this.width,
    required this.height,
    required this.durationUs,
    required this.frameRate,
  });

  factory VideoMetadata.fromMap(Map<String, dynamic> map) {
    return VideoMetadata(
      width: map['width'] as int,
      height: map['height'] as int,
      durationUs: map['durationUs'] as int,
      frameRate: (map['frameRate'] as num).toDouble(),
    );
  }

  Duration get duration => Duration(microseconds: durationUs);
}

class ExportConfig {
  final String outputPath;
  final int width;
  final int height;
  final int bitRate;
  final int frameRate;

  ExportConfig({
    required this.outputPath,
    required this.width,
    required this.height,
    this.bitRate = 8000000,
    this.frameRate = 30,
  });

  Map<String, dynamic> toMap() {
    return {
      'outputPath': outputPath,
      'width': width,
      'height': height,
      'bitRate': bitRate,
      'frameRate': frameRate,
    };
  }
}
