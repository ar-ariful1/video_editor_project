// lib/core/services/download_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../../app_theme.dart';

enum DownloadStatus { queued, downloading, done, failed, cancelled }

class DownloadTask {
  final String id;
  final String url;
  final String name;
  final String type; // music | sticker | font | lut | template
  final String? localPath;
  final double progress;
  final DownloadStatus status;
  final String? error;

  const DownloadTask({
    required this.id, required this.url, required this.name, required this.type,
    this.localPath, this.progress = 0, this.status = DownloadStatus.queued, this.error,
  });

  DownloadTask copyWith({double? progress, DownloadStatus? status, String? localPath, String? error}) =>
      DownloadTask(id: id, url: url, name: name, type: type,
        localPath: localPath ?? this.localPath, progress: progress ?? this.progress,
        status: status ?? this.status, error: error ?? this.error);

  Map<String, dynamic> toMap() => {'id':id,'url':url,'name':name,'type':type,'localPath':localPath,'status':status.name};
  factory DownloadTask.fromMap(Map m) => DownloadTask(id:m['id'],url:m['url'],name:m['name'],type:m['type'],localPath:m['localPath'],status:DownloadStatus.values.firstWhere((s)=>s.name==m['status'],orElse:()=>DownloadStatus.done));
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _i = DownloadManager._();
  factory DownloadManager() => _i;
  DownloadManager._();

  final _tasks    = <String, DownloadTask>{};
  final _dio      = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  final _cancelTokens = <String, CancelToken>{};
  bool _initialized = false;

  List<DownloadTask> get tasks => _tasks.values.toList()..sort((a,b) => a.name.compareTo(b.name));
  List<DownloadTask> get active => tasks.where((t) => t.status == DownloadStatus.downloading).toList();
  List<DownloadTask> get completed => tasks.where((t) => t.status == DownloadStatus.done).toList();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Load cached downloads from Hive
    try {
      final box = await Hive.openBox('downloads');
      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final task = DownloadTask.fromMap(Map<String,dynamic>.from(data));
          if (task.status == DownloadStatus.done && task.localPath != null && File(task.localPath!).existsSync()) {
            _tasks[task.id] = task;
          }
        }
      }
    } catch (_) {}
  }

  bool isDownloaded(String id) => _tasks[id]?.status == DownloadStatus.done;
  String? getLocalPath(String id) => _tasks[id]?.localPath;

  Future<String?> download(String id, String url, String name, String type) async {
    if (isDownloaded(id)) return getLocalPath(id);

    final task = DownloadTask(id: id, url: url, name: name, type: type, status: DownloadStatus.downloading);
    _tasks[id] = task;
    notifyListeners();

    try {
      final dir = await _assetDir(type);
      final ext = url.split('.').last.split('?').first;
      final localPath = '${dir.path}/$id.$ext';

      final token = CancelToken();
      _cancelTokens[id] = token;

      await _dio.download(
        url, localPath,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _tasks[id] = _tasks[id]!.copyWith(progress: received / total);
            notifyListeners();
          }
        },
      );

      _tasks[id] = _tasks[id]!.copyWith(status: DownloadStatus.done, localPath: localPath, progress: 1.0);
      await _persist(id);
      notifyListeners();
      return localPath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _tasks[id] = _tasks[id]!.copyWith(status: DownloadStatus.cancelled);
      } else {
        _tasks[id] = _tasks[id]!.copyWith(status: DownloadStatus.failed, error: e.message);
      }
      notifyListeners();
      return null;
    }
  }

  void cancel(String id) {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
  }

  void remove(String id) {
    final task = _tasks.remove(id);
    if (task?.localPath != null) {
      try { File(task!.localPath!).deleteSync(); } catch (_) {}
    }
    notifyListeners();
  }

  Future<Directory> _assetDir(String type) async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/assets/$type');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<void> _persist(String id) async {
    try {
      final box = await Hive.openBox('downloads');
      await box.put(id, _tasks[id]!.toMap());
    } catch (_) {}
  }

  int get totalDownloaded => completed.length;
  double get totalSizeMB => 0; // TODO: sum file sizes
}

// ── Download Manager Screen ───────────────────────────────────────────────────

class DownloadManagerScreen extends StatelessWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: AppTheme.bg2, title: const Text('Downloads')),
      body: ListenableBuilder(
        listenable: DownloadManager(),
        builder: (_, __) {
          final mgr    = DownloadManager();
          final active = mgr.active;
          final done   = mgr.completed;

          if (active.isEmpty && done.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.download_rounded, color: AppTheme.textTertiary, size: 48),
              SizedBox(height: 12),
              Text('No downloads', style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
            ]));
          }

          return ListView(children: [
            if (active.isNotEmpty) ...[
              _Section('Downloading'),
              ...active.map((t) => _TaskTile(task: t, onCancel: () => DownloadManager().cancel(t.id))),
            ],
            if (done.isNotEmpty) ...[
              _Section('Completed (${done.length})'),
              ...done.map((t) => _TaskTile(task: t, onRemove: () => DownloadManager().remove(t.id))),
            ],
          ]);
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
  );
}

class _TaskTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onCancel, onRemove;
  const _TaskTile({required this.task, this.onCancel, this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppTheme.bg2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(_icon(task.type), color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(task.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        if (onCancel != null) GestureDetector(onTap: onCancel, child: const Icon(Icons.close_rounded, color: AppTheme.accent4, size: 16)),
        if (onRemove != null) GestureDetector(onTap: onRemove, child: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent4, size: 16)),
      ]),
      if (task.status == DownloadStatus.downloading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: task.progress, backgroundColor: AppTheme.border, valueColor: const AlwaysStoppedAnimation(AppTheme.accent), minHeight: 3, borderRadius: BorderRadius.circular(2)),
        const SizedBox(height: 4),
        Text('${(task.progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
      ],
      if (task.status == DownloadStatus.done)
        const Padding(padding: EdgeInsets.only(top: 4), child: Text('✓ Downloaded', style: TextStyle(color: AppTheme.green, fontSize: 11))),
      if (task.status == DownloadStatus.failed)
        Text('❌ ${task.error ?? 'Failed'}', style: const TextStyle(color: AppTheme.accent4, fontSize: 11)),
    ]),
  );

  IconData _icon(String type) {
    switch (type) {
      case 'music':  return Icons.music_note_rounded;
      case 'font':   return Icons.font_download_rounded;
      case 'lut':    return Icons.palette_rounded;
      default:       return Icons.download_rounded;
    }
  }
}
