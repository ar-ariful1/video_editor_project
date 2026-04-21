// lib/features/home/project_actions.dart
// Rename, duplicate, delete project actions with dialogs
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../core/models/video_project.dart';
import '../../core/repositories/project_repository.dart';
import '../../core/utils/utils.dart';

class ProjectActions {
  // ── Rename dialog ────────────────────────────────────────────────────────────
  static Future<void> rename(
      BuildContext context, VideoProject project, VoidCallback onDone) async {
    final ctrl = TextEditingController(text: project.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Project',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Project name',
              counterStyle: TextStyle(color: AppTheme.textTertiary)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Rename',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty && result != project.name) {
      await ProjectRepository().renameProject(project.id, result);
      onDone();
      if (context.mounted) showSuccess(context, 'Project renamed to "$result"');
    }
  }

  // ── Duplicate ────────────────────────────────────────────────────────────────
  static Future<void> duplicate(
      BuildContext context, VideoProject project, VoidCallback onDone) async {
    try {
      await ProjectRepository().duplicateProject(project.id);
      onDone();
      if (context.mounted) showSuccess(context, '"${project.name}" duplicated');
    } catch (e) {
      if (context.mounted) showError(context, 'Failed to duplicate: $e');
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────────
  static Future<void> delete(
      BuildContext context, VideoProject project, VoidCallback onDone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Project?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
            '"${project.name}" will be permanently deleted and cannot be recovered.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent4),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ProjectRepository().deleteProjectLocally(project.id);
      onDone();
      if (context.mounted) showSuccess(context, 'Project deleted');
    }
  }

  // ── Context menu sheet ───────────────────────────────────────────────────────
  static void showMenu(
    BuildContext context,
    VideoProject project, {
    required VoidCallback onEdit,
    required VoidCallback onRename,
    required VoidCallback onDuplicate,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            const Text('🎬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(project.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const Divider(color: AppTheme.border, height: 1),
        _MenuItem(
            icon: Icons.edit_rounded,
            label: 'Start Editing',
            onTap: () {
              Navigator.pop(context);
              onEdit();
            }),
        _MenuItem(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
            onTap: () {
              Navigator.pop(context);
              onRename();
            }),
        _MenuItem(
            icon: Icons.copy_all_rounded,
            label: 'Duplicate',
            onTap: () {
              Navigator.pop(context);
              onDuplicate();
            }),
        const Divider(color: AppTheme.border, height: 1),
        _MenuItem(
            icon: Icons.delete_rounded,
            label: 'Delete',
            color: AppTheme.accent4,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            }),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(label, style: TextStyle(color: color, fontSize: 14)),
        onTap: onTap,
        visualDensity: VisualDensity.compact,
        dense: true,
      );
}
