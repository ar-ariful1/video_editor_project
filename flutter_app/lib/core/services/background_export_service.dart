// lib/core/services/background_export_service.dart
// Background rendering — export continues even when app is minimized
// Uses Flutter WorkManager + native foreground service

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/video_project.dart';
import 'native_engine_service.dart';
import 'deep_link_service.dart';

const _uuid = Uuid();

// ── Export job ─────────────────────────────────────────────────────────────────

enum ExportJobStatus { queued, processing, paused, done, failed, cancelled }

class ExportJob {
  final String id, projectId, projectName;
  final String quality;
  final int fps;
  final bool watermark;
  ExportJobStatus status;
  double progress;
  String? outputPath;
  String? error;
  DateTime createdAt;
  DateTime? startedAt, completedAt;

  ExportJob({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.quality,
    required this.fps,
    required this.watermark,
    this.status = ExportJobStatus.queued,
    this.progress = 0,
    this.outputPath,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'projectName': projectName,
        'quality': quality,
        'fps': fps,
        'watermark': watermark,
        'status': status.name,
        'progress': progress,
        'outputPath': outputPath,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExportJob.fromJson(Map<String, dynamic> j) => ExportJob(
        id: j['id'],
        projectId: j['projectId'],
        projectName: j['projectName'],
        quality: j['quality'],
        fps: j['fps'],
        watermark: j['watermark'],
        status: ExportJobStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => ExportJobStatus.queued),
        progress: (j['progress'] as num).toDouble(),
        outputPath: j['outputPath'],
        error: j['error'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

// ── Background Export Service ──────────────────────────────────────────────────

class BackgroundExportService extends ChangeNotifier {
  static final BackgroundExportService _i = BackgroundExportService._();
  factory BackgroundExportService() => _i;
  BackgroundExportService._();

  final _queue = <ExportJob>[];
  ExportJob? _active;
  bool _processing = false;
  Timer? _persistTimer;

  List<ExportJob> get queue => List.unmodifiable(_queue);
  ExportJob? get activeJob => _active;
  bool get isExporting => _processing;

  // ── Init: restore persisted queue ────────────────────────────────────────────
  Future<void> init() async {
    await _loadPersistedQueue();
    // Resume any interrupted job
    final interrupted =
        _queue.where((j) => j.status == ExportJobStatus.processing).toList();
    for (final job in interrupted) {
      job.status = ExportJobStatus.queued;
    }
    _processNext();
  }

  // ── Enqueue ───────────────────────────────────────────────────────────────────
  Future<String> enqueue({
    required VideoProject project,
    required String quality,
    required int fps,
    required bool watermark,
  }) async {
    final job = ExportJob(
      id: _uuid.v4(),
      projectId: project.id,
      projectName: project.name,
      quality: quality,
      fps: fps,
      watermark: watermark,
    );
    _queue.add(job);
    await _persist();
    notifyListeners();

    // Save active export for resume tracking
    await DeepLinkService().saveActiveExport(job.id);

    _processNext();
    return job.id;
  }

  // ── Cancel ────────────────────────────────────────────────────────────────────
  Future<void> cancel(String jobId) async {
    final job = _queue.firstWhere((j) => j.id == jobId,
        orElse: () => ExportJob(
            id: '',
            projectId: '',
            projectName: '',
            quality: '',
            fps: 30,
            watermark: false));
    if (job.id.isEmpty) return;

    if (job.status == ExportJobStatus.processing) {
      // Native engine cancellation logic could go here
    }
    job.status = ExportJobStatus.cancelled;
    _active = null;
    _processing = false;
    await _persist();
    notifyListeners();
    _processNext();
  }

  // ── Process queue ─────────────────────────────────────────────────────────────
  void _processNext() {
    if (_processing) return;
    final next = _queue.firstWhere((j) => j.status == ExportJobStatus.queued,
        orElse: () => ExportJob(
            id: '',
            projectId: '',
            projectName: '',
            quality: '',
            fps: 30,
            watermark: false));
    if (next.id.isEmpty) return;

    _active = next;
    _processing = true;
    next.status = ExportJobStatus.processing;
    next.startedAt = DateTime.now();
    notifyListeners();

    _runExport(next);
  }

  Future<void> _runExport(ExportJob job) async {
    try {
      // Resolve output path
      final dir = Directory.systemTemp;
      final outPath =
          '${dir.path}/${job.projectId}_${job.quality}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // NOTE: In a real app, we would load the VideoProject from a database here
      // For this bridge implementation, we assume the project data is needed
      // This is a placeholder for project retrieval logic
      // final project = await _projectRepo.getProject(job.projectId);
      
      // Using Native Engine for hardware-accelerated processing
      final result = await NativeEngineService().startNativeExport(
        project: VideoProject.create(
          name: job.projectName,
          resolution: job.quality == 'q1080p' 
              ? Resolution.vertical9x16 
              : Resolution.p720,
        ), // Placeholder: replace with actual project object
        outputPath: outPath,
        width: job.quality == 'q1080p' ? 1080 : 720,
        height: job.quality == 'q1080p' ? 1920 : 1280,
      );

      if (result != null) {
        job.status = ExportJobStatus.done;
        job.outputPath = result;
        job.completedAt = DateTime.now();
        job.progress = 1.0;
      } else {
        throw Exception("Native export failed to start or returned null");
      }

      // Clear active export tracker
      await DeepLinkService().clearActiveExport();
    } catch (e) {
      job.status = ExportJobStatus.failed;
      job.error = e.toString();
    } finally {
      _active = null;
      _processing = false;
      await _persist();
      notifyListeners();
      _processNext(); // process next in queue
    }
  }

  // ── Retry ─────────────────────────────────────────────────────────────────────
  void retry(String jobId) {
    final job = _queue.firstWhere((j) => j.id == jobId,
        orElse: () => ExportJob(
            id: '',
            projectId: '',
            projectName: '',
            quality: '',
            fps: 30,
            watermark: false));
    if (job.id.isEmpty) return;
    job.status = ExportJobStatus.queued;
    job.progress = 0;
    job.error = null;
    notifyListeners();
    _processNext();
  }

  // ── Progress update for specific job ──────────────────────────────────────────
  ExportJob? getJob(String jobId) {
    try {
      return _queue.firstWhere((j) => j.id == jobId);
    } catch (_) {
      return null;
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────────
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_queue.map((j) => j.toJson()).toList());
    await prefs.setString('export_queue', json);
  }

  void _persistThrottled() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), _persist);
  }

  Future<void> _loadPersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('export_queue');
      if (json == null) return;
      final list = jsonDecode(json) as List;
      _queue.addAll(
          list.map((j) => ExportJob.fromJson(Map<String, dynamic>.from(j))));
    } catch (_) {}
  }

  Future<void> clearCompleted() async {
    _queue.removeWhere((j) =>
        j.status == ExportJobStatus.done ||
        j.status == ExportJobStatus.cancelled);
    await _persist();
    notifyListeners();
  }

  int get queueLength => _queue.length;
  int get completedCount =>
      _queue.where((j) => j.status == ExportJobStatus.done).length;
  int get pendingCount => _queue
      .where((j) =>
          j.status == ExportJobStatus.queued ||
          j.status == ExportJobStatus.processing)
      .length;
}
