// lib/core/engine/native_engine_bridge.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeEngineBridge {
  static const MethodChannel _channel = MethodChannel('com.clipcut.app/native_engine');

  // Singleton pattern
  static final NativeEngineBridge _instance = NativeEngineBridge._internal();
  factory NativeEngineBridge() => _instance;
  NativeEngineBridge._internal();

  // --------------------------------------------------------------------------
  // Engine lifecycle
  // --------------------------------------------------------------------------
  Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }

  Future<void> release() async {
    await _channel.invokeMethod('release');
  }

  // --------------------------------------------------------------------------
  // Video loading and rendering
  // --------------------------------------------------------------------------
  /// Load a video file and return its metadata
  Future<VideoMetadata> loadVideo(String filePath) async {
    final result = await _channel.invokeMethod('loadVideo', {'path': filePath});
    return VideoMetadata.fromMap(result);
  }

  /// Get a texture ID for Flutter Texture widget
  Future<int> createVideoTexture() async {
    return await _channel.invokeMethod('createVideoTexture');
  }

  /// Render a specific frame at time (microseconds)
  Future<void> renderFrameAt(int timeUs) async {
    await _channel.invokeMethod('renderFrameAt', {'timeUs': timeUs});
  }

  /// Seek to a position and update preview
  Future<void> seekTo(int timeUs) async {
    await _channel.invokeMethod('seekTo', {'timeUs': timeUs});
  }

  // --------------------------------------------------------------------------
  // Playback control
  // --------------------------------------------------------------------------
  Future<void> play() async {
    await _channel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  Future<bool> isPlaying() async {
    return await _channel.invokeMethod('isPlaying');
  }

  // --------------------------------------------------------------------------
  // Effects & Adjustments
  // --------------------------------------------------------------------------
  Future<void> setBrightness(double value) async {
    await _channel.invokeMethod('setBrightness', {'value': value});
  }

  Future<void> setContrast(double value) async {
    await _channel.invokeMethod('setContrast', {'value': value});
  }

  Future<void> setSaturation(double value) async {
    await _channel.invokeMethod('setSaturation', {'value': value});
  }

  Future<void> setOpacity(double value) async {
    await _channel.invokeMethod('setOpacity', {'value': value});
  }

  // --------------------------------------------------------------------------
  // Audio controls (NEW)
  // --------------------------------------------------------------------------
  /// Set volume for a specific audio clip
  Future<void> setVolume(String clipId, double volume) async {
    await _channel.invokeMethod('setVolume', {
      'clipId': clipId,
      'volume': volume,
    });
  }

  /// Get audio waveform data (returns raw PCM bytes)
  Future<Uint8List?> getAudioWaveform(String path) async {
    final result = await _channel.invokeMethod('getAudioWaveform', {'path': path});
    if (result is Uint8List) return result;
    return null;
  }
  
  Future<void> cancelExport() async {
  await _channel.invokeMethod('cancelExport');
}
  // --------------------------------------------------------------------------
  // Export
  // --------------------------------------------------------------------------
  Future<void> startExport(ExportConfig config) async {
    await _channel.invokeMethod('startExport', config.toMap());
  }

  Stream<double> get exportProgress {
    return _channel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['type'] == 'exportProgress')
        .map((event) => (event['progress'] as num).toDouble());
  }

  Stream<String> get exportStatus {
    return _channel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['type'] == 'exportStatus')
        .map((event) => event['status'] as String);
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

  factory VideoMetadata.fromMap(Map<dynamic, dynamic> map) {
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