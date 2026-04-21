// lib/core/services/ai_service.dart
// Flutter client for all AI microservices

import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/video_project.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class CaptionWord {
  final String word;
  final double start;
  final double end;
  final double probability;
  const CaptionWord(
      {required this.word,
      required this.start,
      required this.end,
      required this.probability});
  factory CaptionWord.fromJson(Map<String, dynamic> j) => CaptionWord(
      word: j['word'],
      start: j['start'].toDouble(),
      end: j['end'].toDouble(),
      probability: j['probability'].toDouble());
}

class CaptionSegment {
  final int id;
  final String text;
  final double start;
  final double end;
  final List<CaptionWord> words;
  const CaptionSegment(
      {required this.id,
      required this.text,
      required this.start,
      required this.end,
      required this.words});
  factory CaptionSegment.fromJson(Map<String, dynamic> j) => CaptionSegment(
        id: j['id'],
        text: j['text'],
        start: j['start'].toDouble(),
        end: j['end'].toDouble(),
        words:
            (j['words'] as List).map((w) => CaptionWord.fromJson(w)).toList(),
      );
}

class TranscriptionResult {
  final String jobId;
  final String language;
  final double duration;
  final List<CaptionSegment> segments;
  final String fullText;
  const TranscriptionResult(
      {required this.jobId,
      required this.language,
      required this.duration,
      required this.segments,
      required this.fullText});
  factory TranscriptionResult.fromJson(Map<String, dynamic> j) =>
      TranscriptionResult(
        jobId: j['job_id'],
        language: j['language'],
        duration: j['duration'].toDouble(),
        segments: (j['segments'] as List)
            .map((s) => CaptionSegment.fromJson(s))
            .toList(),
        fullText: j['full_text'],
      );
}

class BeatResult {
  final double bpm;
  final List<double> beatTimes;
  final List<double> downbeatTimes;
  final int barCount;
  final double duration;
  final List<Map<String, dynamic>> timelineMarkers;
  const BeatResult(
      {required this.bpm,
      required this.beatTimes,
      required this.downbeatTimes,
      required this.barCount,
      required this.duration,
      required this.timelineMarkers});
  factory BeatResult.fromJson(Map<String, dynamic> j) => BeatResult(
        bpm: j['bpm'].toDouble(),
        beatTimes: (j['beat_times'] as List)
            .map((t) => (t as num).toDouble())
            .toList(),
        downbeatTimes: (j['downbeat_times'] as List)
            .map((t) => (t as num).toDouble())
            .toList(),
        barCount: j['bar_count'],
        duration: j['duration_seconds'].toDouble(),
        timelineMarkers: List<Map<String, dynamic>>.from(j['timeline_markers']),
      );
}

class TrackingKeyframe {
  final double time;
  final double x;
  final double y;
  final double width;
  final double height;
  const TrackingKeyframe(
      {required this.time,
      required this.x,
      required this.y,
      required this.width,
      required this.height});
  factory TrackingKeyframe.fromJson(Map<String, dynamic> j) => TrackingKeyframe(
        time: j['time'].toDouble(),
        x: j['x'].toDouble(),
        y: j['y'].toDouble(),
        width: j['width'].toDouble(),
        height: j['height'].toDouble(),
      );
}

class UpscaleJobResult {
  final String jobId;
  final String status;
  final double progress;
  const UpscaleJobResult(
      {required this.jobId, required this.status, required this.progress});
  factory UpscaleJobResult.fromJson(Map<String, dynamic> j) => UpscaleJobResult(
        jobId: j['job_id'] ?? '',
        status: j['status'],
        progress: (j['progress'] ?? 0.0).toDouble(),
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AIService {
  static final AIService _instance = AIService._();
  factory AIService() => _instance;
  AIService._();

  late final Dio _dio;

  static const String _baseUrl = String.fromEnvironment(
    'AI_SERVICE_URL',
    defaultValue: 'http://localhost:8000/ai',
  );

  void init(String? authToken) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    ));
  }

  // ── Auto Captions (Whisper) ─────────────────────────────────────────────

  /// Transcribe video and return caption segments ready for the timeline.
  Future<TranscriptionResult> transcribeVideo(
    String videoPath, {
    String modelSize = 'small',
    String? language,
    void Function(double)? onProgress,
  }) async {
    final file = await MultipartFile.fromFile(videoPath, filename: 'video.mp4');
    final formData = FormData.fromMap({
      'file': file,
      'model_size': modelSize,
      if (language != null) 'language': language,
    });

    onProgress?.call(0.05);

    // Start async job
    final startRes = await _dio.post('/captions/transcribe', data: formData);
    final jobId = startRes.data['job_id'] as String;

    // Poll for result
    return _pollJob<TranscriptionResult>(
      jobId: jobId,
      pollUrl: '/captions/status/$jobId',
      fromJson: (json) => TranscriptionResult.fromJson(json['result']),
      onProgress: onProgress,
    );
  }

  /// Convert TranscriptionResult into TextLayer clips for the timeline.
  List<TextLayer> transcriptionToTextLayers(
    TranscriptionResult result, {
    String fontFamily = 'Inter',
    double fontSize = 40,
    TextFill? fill,
    String? animIn,
  }) {
    return result.segments
        .map((seg) => TextLayer(
              id: DateTime.now().microsecondsSinceEpoch.toString() +
                  seg.id.toString(),
              startTime: seg.start,
              endTime: seg.end,
              text: seg.text,
              fontFamily: fontFamily,
              fontSize: fontSize,
              fill: fill ?? const TextFill(colors: [0xFFFFFFFF]),
              animIn: animIn ?? 'fadeIn',
              isAutoCaption: true,
            ))
        .toList();
  }

  // ── Background Removal (RMBG) ───────────────────────────────────────────

  Future<File> removeBackgroundImage(String imagePath) async {
    final file = await MultipartFile.fromFile(imagePath);
    final formData = FormData.fromMap({'file': file, 'output_format': 'png'});
    final res = await _dio.post<List<int>>(
      '/rmbg/remove-bg/image',
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );
    final outPath = imagePath.replaceAll(RegExp(r'\.\w+$'), '_nobg.png');
    await File(outPath).writeAsBytes(res.data!);
    return File(outPath);
  }

  Future<File> removeBackgroundVideo(String videoPath,
      {void Function(double)? onProgress}) async {
    final file = await MultipartFile.fromFile(videoPath);
    final formData = FormData.fromMap(
        {'file': file, 'process_fps': '15', 'replace_with_green': 'true'});
    onProgress?.call(0.1);
    final res = await _dio.post<List<int>>(
      '/rmbg/remove-bg/video',
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );
    onProgress?.call(1.0);
    final outPath = videoPath.replaceAll(RegExp(r'\.\w+$'), '_nobg.mp4');
    await File(outPath).writeAsBytes(res.data!);
    return File(outPath);
  }

  // ── Object Tracking (YOLOv8) ────────────────────────────────────────────

  Future<List<TrackingKeyframe>> trackObject(
    String videoPath, {
    int targetClass = 0, // 0 = person
    double confidence = 0.4,
    double sampleFps = 10.0,
    void Function(double)? onProgress,
  }) async {
    final file = await MultipartFile.fromFile(videoPath);
    final formData = FormData.fromMap({
      'file': file,
      'target_class': targetClass.toString(),
      'confidence': confidence.toString(),
      'sample_fps': sampleFps.toString(),
    });
    onProgress?.call(0.1);
    final res = await _dio.post('/tracking/track/video', data: formData);
    onProgress?.call(1.0);
    final keyframes = (res.data['keyframes'] as List)
        .map((k) => TrackingKeyframe.fromJson(k))
        .toList();
    return keyframes;
  }

  /// Convert tracking keyframes to Clip keyframes for the Flutter timeline.
  List<Keyframe> trackingToKeyframes(List<TrackingKeyframe> tracking) {
    final result = <Keyframe>[];
    for (final kf in tracking) {
      result.add(Keyframe.create(time: kf.time, property: 'x', value: kf.x));
      result.add(Keyframe.create(time: kf.time, property: 'y', value: kf.y));
    }
    return result;
  }

  // ── Beat Detection ──────────────────────────────────────────────────────

  Future<BeatResult> detectBeats(String audioOrVideoPath,
      {void Function(double)? onProgress}) async {
    final file = await MultipartFile.fromFile(audioOrVideoPath);
    final formData = FormData.fromMap({'file': file});
    onProgress?.call(0.2);
    final res = await _dio.post('/beats/detect', data: formData);
    onProgress?.call(1.0);
    return BeatResult.fromJson(res.data);
  }

  // ── 4K Upscaling (Real-ESRGAN) ──────────────────────────────────────────

  Future<File> upscaleImage(String imagePath) async {
    final file = await MultipartFile.fromFile(imagePath);
    final formData = FormData.fromMap({'file': file, 'output_format': 'png'});
    final res = await _dio.post<List<int>>(
      '/upscale/upscale/image',
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );
    final outPath = imagePath.replaceAll(RegExp(r'\.\w+$'), '_4k.png');
    await File(outPath).writeAsBytes(res.data!);
    return File(outPath);
  }

  Future<String> startVideoUpscale(String videoPath) async {
    final file = await MultipartFile.fromFile(videoPath);
    final formData = FormData.fromMap({'file': file});
    final res = await _dio.post('/upscale/upscale/video/start', data: formData);
    return res.data['job_id'] as String;
  }

  Future<UpscaleJobResult> getUpscaleStatus(String jobId) async {
    final res = await _dio.get('/upscale/upscale/video/status/$jobId');
    return UpscaleJobResult.fromJson(res.data);
  }

  Future<File> downloadUpscaledVideo(String jobId, String outputPath) async {
    final res = await _dio.get<List<int>>(
      '/upscale/upscale/video/download/$jobId',
      options: Options(responseType: ResponseType.bytes),
    );
    final file = File(outputPath);
    await file.writeAsBytes(res.data!);
    return file;
  }

  // ── Smart Cutout (Segment Anything / SAM) ──────────────────────────────

  Future<File> smartCutout(String mediaPath, {required List<Offset> points}) async {
    final file = await MultipartFile.fromFile(mediaPath);
    final formData = FormData.fromMap({
      'file': file,
      'points_json': jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList()),
    });

    final res = await _dio.post<List<int>>(
      '/segment/smart-cutout',
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );

    final outPath = mediaPath.replaceAll(RegExp(r'\.\w+$'), '_cutout.png');
    await File(outPath).writeAsBytes(res.data!);
    return File(outPath);
  }

  // ── AI Object Removal (SAM + LAMA) ─────────────────────────────────────

  Future<File> removeObject(String mediaPath, {required List<Offset> points, List<Rect>? boxes}) async {
    final file = await MultipartFile.fromFile(mediaPath);
    final formData = FormData.fromMap({
      'file': file,
      'points_json': jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList()),
      if (boxes != null)
        'boxes_json': jsonEncode(boxes.map((r) => {
          'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height
        }).toList()),
    });

    final res = await _dio.post<List<int>>(
      '/segment/remove-object',
      data: formData,
      options: Options(responseType: ResponseType.bytes),
    );

    final outPath = mediaPath.replaceAll(RegExp(r'\.\w+$'), '_removed.png');
    await File(outPath).writeAsBytes(res.data!);
    return File(outPath);
  }

  // ── Poll Helper ─────────────────────────────────────────────────────────

  Future<T> _pollJob<T>({
    required String jobId,
    required String pollUrl,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(double)? onProgress,
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 300,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);
      final res = await _dio.get(pollUrl);
      final status = res.data['status'] as String;

      if (status == 'done') {
        onProgress?.call(1.0);
        return fromJson(res.data);
      }
      if (status == 'error') {
        throw Exception('AI job failed: ${res.data['error']}');
      }

      // processing — estimate progress
      final progress = 0.1 + (i / maxAttempts) * 0.85;
      onProgress?.call(progress.clamp(0.1, 0.95));
    }
    throw Exception(
        'AI job timed out after ${maxAttempts * interval.inSeconds}s');
  }
}
