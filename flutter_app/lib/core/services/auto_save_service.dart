// lib/core/services/auto_save_service.dart
import 'dart:async';
import '../models/video_project.dart';
import '../repositories/project_repository.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

class AutoSaveService {
  static final AutoSaveService _i = AutoSaveService._();
  factory AutoSaveService() => _i;
  AutoSaveService._();

  Timer? _timer;
  VideoProject? _lastSaved;
  VideoProject? _pending;
  bool _saving = false;

  final ValueNotifier<AutoSaveStatus> status = ValueNotifier(AutoSaveStatus.idle);

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _trySave());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call whenever the project changes
  void markDirty(VideoProject project) {
    _pending = project;
    status.value = AutoSaveStatus.unsaved;
  }

  Future<void> saveNow() async => _trySave(force: true);

  Future<void> _trySave({bool force = false}) async {
    if (_pending == null || _saving) return;
    if (!force && _lastSaved?.updatedAt == _pending!.updatedAt) return;

    _saving = true;
    status.value = AutoSaveStatus.saving;

    try {
      await ProjectRepository().saveProject(_pending!);
      _lastSaved = _pending;
      status.value = AutoSaveStatus.saved;
      await Future.delayed(const Duration(seconds: 2));
      if (status.value == AutoSaveStatus.saved) status.value = AutoSaveStatus.idle;
    } catch (e) {
      status.value = AutoSaveStatus.error;
    } finally {
      _saving = false;
    }
  }

  void dispose() {
    stop();
    status.dispose();
  }
}

enum AutoSaveStatus { idle, unsaved, saving, saved, error }

// Auto-save indicator widget


class AutoSaveIndicator extends StatelessWidget {
  const AutoSaveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AutoSaveStatus>(
      valueListenable: AutoSaveService().status,
      builder: (_, status, __) {
        if (status == AutoSaveStatus.idle) return const SizedBox.shrink();
        return AnimatedOpacity(
          opacity: status == AutoSaveStatus.idle ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (status == AutoSaveStatus.saving)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textTertiary))
            else
              Icon(_icon(status), size: 12, color: _color(status)),
            const SizedBox(width: 4),
            Text(_label(status), style: TextStyle(color: _color(status), fontSize: 10)),
          ]),
        );
      },
    );
  }

  IconData _icon(AutoSaveStatus s) {
    switch (s) {
      case AutoSaveStatus.saved:   return Icons.cloud_done_outlined;
      case AutoSaveStatus.unsaved: return Icons.edit_outlined;
      case AutoSaveStatus.error:   return Icons.cloud_off_outlined;
      default: return Icons.cloud_outlined;
    }
  }

  Color _color(AutoSaveStatus s) {
    switch (s) {
      case AutoSaveStatus.saved:   return AppTheme.green;
      case AutoSaveStatus.unsaved: return AppTheme.accent3;
      case AutoSaveStatus.error:   return AppTheme.accent4;
      default: return AppTheme.textTertiary;
    }
  }

  String _label(AutoSaveStatus s) {
    switch (s) {
      case AutoSaveStatus.saving:  return 'Saving…';
      case AutoSaveStatus.saved:   return 'Saved';
      case AutoSaveStatus.unsaved: return 'Unsaved';
      case AutoSaveStatus.error:   return 'Save failed';
      default: return '';
    }
  }
}

// Draft recovery dialog
class DraftRecoveryDialog extends StatelessWidget {
  final VideoProject draft;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  const DraftRecoveryDialog({super.key, required this.draft, required this.onRestore, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Text('💾 ', style: TextStyle(fontSize: 20)),
        Text('Unsaved Draft Found', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: Text(
        '"${draft.name}" has unsaved changes from ${_formatTime(draft.updatedAt)}.\nDo you want to restore them?',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(onPressed: onDiscard, child: const Text('Discard', style: TextStyle(color: AppTheme.accent4))),
        ElevatedButton(onPressed: onRestore, child: const Text('Restore Draft')),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
