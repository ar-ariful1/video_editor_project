// lib/core/services/monitoring_service.dart
// Production monitoring — crash reporting, export logs, device perf, user actions
// 2026 edition — Firebase Crashlytics + custom analytics pipeline

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ── Event types ───────────────────────────────────────────────────────────────

enum AnalyticsEvent {
  // User actions
  appOpen,
  appBackground,
  appForeground,
  projectCreated,
  projectOpened,
  projectDeleted,
  projectDuplicated,
  exportStarted,
  exportCompleted,
  exportFailed,
  exportCancelled,
  templateViewed,
  templateUsed,
  templateFavorited,
  toolUsed,
  effectApplied,
  filterApplied,
  subscriptionUpgraded,
  paywallShown,
  paywallDismissed,
  shareClicked,
  shareSent,
  searchPerformed,
  searchResultClicked,
  onboardingStarted,
  onboardingCompleted,
  onboardingSkipped,
  // Performance
  renderLag,
  exportSlowdown,
  memoryWarning,
  thermalWarning,
  // Errors
  exportError,
  uploadError,
  networkError,
  crashRecovered,
}

// ── Event model ───────────────────────────────────────────────────────────────

class AnalyticsEventData {
  final String id, sessionId;
  final AnalyticsEvent event;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? userId;

  AnalyticsEventData({
    required this.event,
    this.userId,
    Map<String, dynamic>? properties,
    required this.sessionId,
  })  : id = _uuid.v4(),
        properties = properties ?? {},
        timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'event': event.name,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
      };
}

// ── Monitoring service ────────────────────────────────────────────────────────

class MonitoringService {
  static final MonitoringService _i = MonitoringService._();
  factory MonitoringService() => _i;
  MonitoringService._();

  final _dio = Dio();
  final _eventBuffer = <AnalyticsEventData>[];
  final _sessionId = _uuid.v4();
  Timer? _flushTimer;
  String? _userId;
  String? _deviceId;
  Map<String, dynamic> _deviceInfo = {};

  static const _apiBase = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.videoeditorpro.app');
  static const _batchSize = 20;
  static const _flushInterval = Duration(seconds: 30);

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> init({String? userId}) async {
    _userId = userId;
    _deviceId = await _getDeviceId();
    _deviceInfo = await _collectDeviceInfo();

    // Setup Flutter error handler
    FlutterError.onError = (details) {
      _recordFlutterError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Setup Dart async error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      _recordError(error, stack, fatal: true);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Start flush timer
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());

    // Set Crashlytics user info
    if (userId != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
      FirebaseCrashlytics.instance.setCustomKey('device_id', _deviceId ?? '');
    }

    track(AnalyticsEvent.appOpen, properties: {'device': _deviceInfo});
  }

  void setUser(String userId) {
    _userId = userId;
    FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  // ── Track event ───────────────────────────────────────────────────────────────

  void track(AnalyticsEvent event, {Map<String, dynamic>? properties}) {
    final data = AnalyticsEventData(
      event: event,
      userId: _userId,
      sessionId: _sessionId,
      properties: {
        ...?properties,
        'device_id': _deviceId,
        'platform': defaultTargetPlatform.name,
      },
    );
    _eventBuffer.add(data);
    if (_eventBuffer.length >= _batchSize) _flush();
  }

  // ── Shorthand trackers ────────────────────────────────────────────────────────

  void trackExportStarted(
          {required String quality,
          required int fps,
          required bool watermark}) =>
      track(AnalyticsEvent.exportStarted,
          properties: {'quality': quality, 'fps': fps, 'watermark': watermark});

  void trackExportCompleted(
          {required String quality,
          required int durationSec,
          required int outputMB}) =>
      track(AnalyticsEvent.exportCompleted, properties: {
        'quality': quality,
        'duration_sec': durationSec,
        'size_mb': outputMB
      });

  void trackExportFailed({required String quality, required String error}) =>
      track(AnalyticsEvent.exportFailed,
          properties: {'quality': quality, 'error': error});

  void trackToolUsed(String toolName, {Map<String, dynamic>? extra}) =>
      track(AnalyticsEvent.toolUsed, properties: {'tool': toolName, ...?extra});

  void trackTemplateUsed(String templateId, {required String category}) =>
      track(AnalyticsEvent.templateUsed,
          properties: {'template_id': templateId, 'category': category});

  void trackPaywallShown({required String feature, required String plan}) =>
      track(AnalyticsEvent.paywallShown,
          properties: {'feature': feature, 'required_plan': plan});

  void trackRenderLag({required double frameMs, required int droppedFrames}) =>
      track(AnalyticsEvent.renderLag,
          properties: {'frame_ms': frameMs, 'dropped': droppedFrames});

  // ── Error recording ───────────────────────────────────────────────────────────

  void recordExportError(String jobId, String error,
      {Map<String, dynamic>? context}) {
    FirebaseCrashlytics.instance.log('ExportError: $error');
    FirebaseCrashlytics.instance.setCustomKey('last_export_error', error);
    track(AnalyticsEvent.exportError,
        properties: {'job_id': jobId, 'error': error, ...?context});
    _persistErrorLog('export', {
      'job_id': jobId,
      'error': error,
      'context': context,
      'ts': DateTime.now().toIso8601String()
    });
  }

  void recordUploadError(String path, String error) {
    track(AnalyticsEvent.uploadError,
        properties: {'path': path, 'error': error});
  }

  void recordNetworkError(String endpoint, int? statusCode, String error) {
    track(AnalyticsEvent.networkError, properties: {
      'endpoint': endpoint,
      'status': statusCode,
      'error': error
    });
  }

  void _recordFlutterError(FlutterErrorDetails details) {
    track(AnalyticsEvent.crashRecovered, properties: {
      'exception': details.exception.toString().substring(0, 200),
      'library': details.library ?? '',
    });
    _persistErrorLog('flutter', {
      'error': details.exception.toString(),
      'ts': DateTime.now().toIso8601String()
    });
  }

  void _recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    track(fatal ? AnalyticsEvent.crashRecovered : AnalyticsEvent.networkError,
        properties: {
          'error': error.toString().substring(0, 200),
          'fatal': fatal,
        });
  }

  // ── Device performance log ────────────────────────────────────────────────────

  void logPerformanceSnapshot(
      {required double fps, required int memoryMB, required String perfMode}) {
    FirebaseCrashlytics.instance.setCustomKey('last_fps', fps);
    FirebaseCrashlytics.instance.setCustomKey('memory_mb', memoryMB);
    FirebaseCrashlytics.instance.setCustomKey('perf_mode', perfMode);
  }

  // ── Flush to backend ──────────────────────────────────────────────────────────

  Future<void> _flush() async {
    if (_eventBuffer.isEmpty) return;
    final batch = List<AnalyticsEventData>.from(_eventBuffer);
    _eventBuffer.clear();

    try {
      await _dio.post(
        '$_apiBase/analytics/events',
        data: {'events': batch.map((e) => e.toJson()).toList()},
        options: Options(
            headers: {'Content-Type': 'application/json'},
            sendTimeout: const Duration(seconds: 10)),
      );
    } catch (_) {
      // Re-queue failed events (limited retry)
      if (_eventBuffer.length < 100) _eventBuffer.addAll(batch);
    }
  }

  Future<void> flush() => _flush();

  // ── Error log persistence ─────────────────────────────────────────────────────

  Future<void> _persistErrorLog(String type, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'error_log_$type';
      final existing = prefs.getStringList(key) ?? [];
      existing.insert(0, jsonEncode(data));
      if (existing.length > 20) existing.removeLast(); // keep last 20
      await prefs.setStringList(key, existing);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getErrorLogs(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('error_log_$type') ?? [];
      return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Device info ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    try {
      return {
        'platform': defaultTargetPlatform.name,
        'is_physical': !kIsWeb,
        'locale': WidgetsBinding.instance.platformDispatcher.locale.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush();
  }
}
