// lib/core/services/realtime_service.dart
// WebSocket real-time service — live export progress, notifications, admin sync
// 2026 edition — reconnect, heartbeat, message queue

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../../app_theme.dart';

// ── Message types ─────────────────────────────────────────────────────────────

enum WsMessageType {
  exportProgress, exportComplete, exportFailed,
  newTemplate, notification, ping, pong, auth,
}

class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WsMessage({required this.type, required this.data})
      : timestamp = DateTime.now();

  factory WsMessage.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? '';
    final type = WsMessageType.values.firstWhere(
      (t) => t.name == typeStr, orElse: () => WsMessageType.ping,
    );
    return WsMessage(type: type, data: Map<String,dynamic>.from(j['data'] as Map? ?? {}));
  }

  Map<String,dynamic> toJson() => {'type': type.name, 'data': data, 'ts': timestamp.toIso8601String()};
}

// ── Connection state ──────────────────────────────────────────────────────────

enum WsState { disconnected, connecting, connected, reconnecting, error }

// ── Real-time service ─────────────────────────────────────────────────────────

class RealtimeService extends ChangeNotifier {
  static final RealtimeService _i = RealtimeService._();
  factory RealtimeService() => _i;
  RealtimeService._();

  static const _wsUrl        = String.fromEnvironment('WS_URL', defaultValue: 'wss://ws.videoeditorpro.app');
  static const _reconnectDelay = Duration(seconds: 3);
  static const _maxReconnect   = 10;
  static const _heartbeatInterval = Duration(seconds: 25);

  WebSocketChannel? _channel;
  WsState     _state     = WsState.disconnected;
  String?     _authToken;
  int         _reconnectCount = 0;
  Timer?      _heartbeatTimer;
  Timer?      _reconnectTimer;
  final _messageQueue = <Map<String,dynamic>>[];  // queue for offline messages

  // Stream controllers
  final _stateCtrl      = StreamController<WsState>.broadcast();
  final _messageCtrl    = StreamController<WsMessage>.broadcast();
  final _exportCtrl     = StreamController<ExportProgressUpdate>.broadcast();

  Stream<WsState>              get stateStream   => _stateCtrl.stream;
  Stream<WsMessage>            get messageStream  => _messageCtrl.stream;
  Stream<ExportProgressUpdate> get exportStream   => _exportCtrl.stream;

  WsState get state    => _state;
  bool    get isConnected => _state == WsState.connected;

  // ── Connect ───────────────────────────────────────────────────────────────────

  Future<void> connect(String authToken) async {
    _authToken = authToken;
    _reconnectCount = 0;
    await _connect();
  }

  Future<void> _connect() async {
    if (_state == WsState.connected || _state == WsState.connecting) return;

    _setState(WsState.connecting);
    try {
      final uri = Uri.parse('$_wsUrl?token=${Uri.encodeComponent(_authToken ?? '')}');
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection
      await _channel!.ready.timeout(const Duration(seconds: 10));

      _setState(WsState.connected);
      _reconnectCount = 0;
      _startHeartbeat();
      _flushMessageQueue();

      // Listen to incoming messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
        cancelOnError: false,
      );

      debugPrint('✅ WebSocket connected');
    } catch (e) {
      debugPrint('❌ WebSocket connect failed: $e');
      _setState(WsState.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String,dynamic>;
      final msg  = WsMessage.fromJson(json);
      _messageCtrl.add(msg);

      switch (msg.type) {
        case WsMessageType.exportProgress:
          _exportCtrl.add(ExportProgressUpdate.fromData(msg.data));
          break;
        case WsMessageType.exportComplete:
          _exportCtrl.add(ExportProgressUpdate.fromData({...msg.data, 'progress': 1.0, 'status': 'done'}));
          break;
        case WsMessageType.exportFailed:
          _exportCtrl.add(ExportProgressUpdate.fromData({...msg.data, 'status': 'failed'}));
          break;
        case WsMessageType.pong:
          break; // heartbeat ack
        default:
          break;
      }
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _onError(error) {
    debugPrint('WS error: $error');
    _setState(WsState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WS connection closed');
    _setState(WsState.disconnected);
    _stopHeartbeat();
    _scheduleReconnect();
  }

  // ── Send message ──────────────────────────────────────────────────────────────

  void send(WsMessage message) {
    if (!isConnected) {
      _messageQueue.add(message.toJson());
      return;
    }
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  void subscribeToExport(String jobId) {
    send(WsMessage(type: WsMessageType.auth, data: {'action': 'subscribe_export', 'jobId': jobId}));
  }

  void unsubscribeFromExport(String jobId) {
    send(WsMessage(type: WsMessageType.auth, data: {'action': 'unsubscribe_export', 'jobId': jobId}));
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected) {
        _channel?.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().toIso8601String()}));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Reconnect with exponential backoff ────────────────────────────────────────

  void _scheduleReconnect() {
    if (_reconnectCount >= _maxReconnect) {
      debugPrint('WS max reconnect attempts reached');
      return;
    }
    final delay = Duration(seconds: _reconnectDelay.inSeconds * (1 << _reconnectCount.clamp(0, 4)));
    _reconnectCount++;
    _setState(WsState.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
    debugPrint('WS reconnect in ${delay.inSeconds}s (attempt $_reconnectCount)');
  }

  void _flushMessageQueue() {
    while (_messageQueue.isNotEmpty) {
      _channel?.sink.add(jsonEncode(_messageQueue.removeAt(0)));
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    await _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _setState(WsState.disconnected);
  }

  void _setState(WsState s) {
    _state = s;
    _stateCtrl.add(s);
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _stateCtrl.close();
    _messageCtrl.close();
    _exportCtrl.close();
    super.dispose();
  }
}

// ── Export progress update ────────────────────────────────────────────────────

class ExportProgressUpdate {
  final String jobId;
  final double progress;
  final String status; // queued | processing | done | failed
  final String? outputUrl;
  final String? error;
  final DateTime timestamp;

  ExportProgressUpdate({required this.jobId, required this.progress,
      required this.status, this.outputUrl, this.error})
      : timestamp = DateTime.now();

  factory ExportProgressUpdate.fromData(Map<String,dynamic> d) => ExportProgressUpdate(
    jobId:     d['jobId'] ?? d['job_id'] ?? '',
    progress:  (d['progress'] as num?)?.toDouble() ?? 0,
    status:    d['status'] ?? 'processing',
    outputUrl: d['output_url'] ?? d['outputUrl'],
    error:     d['error'],
  );

  bool get isDone    => status == 'done';
  bool get isFailed  => status == 'failed';
  double get pct     => (progress * 100).clamp(0, 100);
}

// ── WebSocket status widget ───────────────────────────────────────────────────

class WsStatusDot extends StatelessWidget {
  const WsStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RealtimeService(),
      builder: (_, __) {
        final state = RealtimeService().state;
        final color = state == WsState.connected ? AppTheme.green
            : state == WsState.connecting || state == WsState.reconnecting ? AppTheme.accent3
            : AppTheme.accent4;
        return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
      },
    );
  }
}
