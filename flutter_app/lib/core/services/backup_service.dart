// lib/core/services/backup_service.dart
// Project backup & restore — local JSON export, cloud backup, full restore

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_project.dart';
import '../repositories/project_repository.dart';

// ── Backup format ─────────────────────────────────────────────────────────────

class ProjectBackup {
  final int schemaVersion;
  final VideoProject project;
  final DateTime exportedAt;
  final String appVersion;
  final Map<String, dynamic> metadata;

  const ProjectBackup({
    required this.schemaVersion,
    required this.project,
    required this.exportedAt,
    required this.appVersion,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toIso8601String(),
        'app_version': appVersion,
        'metadata': metadata,
        'project': _serializeProject(project),
      };

  factory ProjectBackup.fromJson(Map<String, dynamic> j) => ProjectBackup(
        schemaVersion: j['schema_version'] ?? 1,
        exportedAt: DateTime.parse(
            j['exported_at'] ?? DateTime.now().toIso8601String()),
        appVersion: j['app_version'] ?? '1.0.0',
        metadata: Map<String, dynamic>.from(j['metadata'] ?? {}),
        project:
            _deserializeProject(Map<String, dynamic>.from(j['project'] as Map)),
      );

  static Map<String, dynamic> _serializeProject(VideoProject p) => {
        'id': p.id,
        'name': p.name,
        'duration': p.computedDuration,
        'resolution': {
          'width': p.resolution.width,
          'height': p.resolution.height,
          'fps': p.resolution.frameRate
        },
        'tracks': p.tracks
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                  'type': t.type.name,
                  'zIndex': t.zIndex,
                  'clips': t.clips
                      .map((c) => {
                            'id': c.id,
                            'startTime': c.startTime,
                            'endTime': c.endTime,
                            'mediaType': c.mediaType,
                            'trimStart': c.trimStart,
                            'volume': c.volume,
                            'fadeIn': c.fadeIn,
                            'fadeOut': c.fadeOut,
                            'speed': c.speed,
                            'textContent': c.textContent,
                            'textStyle': c.textStyle,
                            'effects': c.effects
                                .map((e) => {
                                      'id': e.id,
                                      'type': e.type,
                                      'params': e.params
                                    })
                                .toList(),
                            'keyframes': c.keyframes
                                .map((k) => {
                                      'id': k.id,
                                      'time': k.time,
                                      'property': k.property,
                                      'value': k.value,
                                      'easing': k.easing.name,
                                      'bezierHandles': k.bezierHandles,
                                    })
                                .toList(),
                            'transitionOut': c.transitionOut != null
                                ? {
                                    'type': c.transitionOut!.type,
                                    'duration': c.transitionOut!.duration
                                  }
                                : null,
                          })
                      .toList(),
                })
            .toList(),
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
      };

  static VideoProject _deserializeProject(Map<String, dynamic> d) {
    final res = d['resolution'] as Map;
    return VideoProject(
      id: d['id'],
      name: d['name'],
      duration: (d['duration'] as num).toDouble(),
      resolution: Resolution(
          width: res['width'],
          height: res['height'],
          frameRate: res['fps'] ?? 30),
      tracks: (d['tracks'] as List).map((t) {
        final tm = t as Map;
        return Track(
          id: tm['id'],
          name: tm['name'],
          type: TrackType.values.firstWhere((v) => v.name == tm['type'],
              orElse: () => TrackType.video),
          zIndex: tm['zIndex'] ?? 1,
          clips: (tm['clips'] as List).map((c) {
            final cm = c as Map;
            return Clip(
              id: cm['id'],
              startTime: (cm['startTime'] as num).toDouble(),
              endTime: (cm['endTime'] as num).toDouble(),
              mediaType: cm['mediaType'] ?? 'video',
              trimStart: (cm['trimStart'] as num?)?.toDouble() ?? 0,
              volume: (cm['volume'] as num?)?.toDouble() ?? 1.0,
              fadeIn: (cm['fadeIn'] as num?)?.toDouble() ?? 0,
              fadeOut: (cm['fadeOut'] as num?)?.toDouble() ?? 0,
              speed: (cm['speed'] as num?)?.toDouble() ?? 1.0,
              textContent: cm['textContent'],
              textStyle: cm['textStyle'] != null
                  ? Map<String, dynamic>.from(cm['textStyle'] as Map)
                  : null,
              effects: (cm['effects'] as List? ?? []).map((e) {
                final em = e as Map;
                return Effect(
                    id: em['id'],
                    type: em['type'],
                    params: Map<String, dynamic>.from(em['params'] as Map));
              }).toList(),
              keyframes: (cm['keyframes'] as List? ?? []).map((k) {
                final km = k as Map;
                return Keyframe(
                    id: km['id'],
                    time: (km['time'] as num).toDouble(),
                    property: km['property'],
                    value: (km['value'] as num).toDouble(),
                    easing: EasingType.values.firstWhere(
                        (e) => e.name == km['easing'],
                        orElse: () => EasingType.linear),
                    bezierHandles: km['bezierHandles'] != null
                        ? List<double>.from(km['bezierHandles'] as List)
                        : const [0.25, 0.1, 0.25, 1.0]);
              }).toList(),
              transitionOut: cm['transitionOut'] != null
                  ? Transition(
                      type: (cm['transitionOut'] as Map)['type'],
                      duration:
                          ((cm['transitionOut'] as Map)['duration'] as num)
                              .toDouble())
                  : null,
            );
          }).toList(),
        );
      }).toList(),
      createdAt: DateTime.tryParse(d['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(d['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ── Backup service ────────────────────────────────────────────────────────────

class BackupService {
  static final BackupService _i = BackupService._();
  factory BackupService() => _i;
  BackupService._();

  static const _schemaVersion = 1;
  static const _appVersion = '1.0.0';

  // ── Export project as .vep file (Video Editor Project) ───────────────────────

  Future<String?> exportProjectFile(VideoProject project) async {
    try {
      final backup = ProjectBackup(
        schemaVersion: _schemaVersion,
        project: project,
        exportedAt: DateTime.now(),
        appVersion: _appVersion,
        metadata: {
          'track_count': project.tracks.length,
          'clip_count': project.tracks.fold(0, (a, t) => a + t.clips.length),
          'duration_sec': project.computedDuration,
          'resolution':
              '${project.resolution.width}x${project.resolution.height}',
        },
      );

      final json = jsonEncode(backup.toJson());
      final dir = await getTemporaryDirectory();
      final name =
          '${project.name.replaceAll(RegExp(r'[^\w]'), '_')}_backup.vep';
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);
      return file.path;
    } catch (e) {
      debugPrint('Backup export failed: $e');
      return null;
    }
  }

  // ── Share backup file ─────────────────────────────────────────────────────────

  Future<bool> shareBackup(VideoProject project) async {
    final path = await exportProjectFile(project);
    if (path == null) return false;
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Video Editor Pro — Project: ${project.name}',
    );
    return true;
  }

  // ── Import from .vep file ────────────────────────────────────────────────────

  Future<VideoProject?> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final backup = ProjectBackup.fromJson(json);

      // Save to local repo
      await ProjectRepository().saveProject(backup.project);
      return backup.project;
    } catch (e) {
      debugPrint('Backup import failed: $e');
      return null;
    }
  }

  // ── Auto backup all projects ──────────────────────────────────────────────────

  Future<int> backupAllProjects() async {
    int count = 0;
    try {
      final projects = await ProjectRepository().getLocalProjects();
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      backupDir.createSync(recursive: true);

      for (final project in projects) {
        final backup = ProjectBackup(
          schemaVersion: _schemaVersion,
          project: project,
          exportedAt: DateTime.now(),
          appVersion: _appVersion,
          metadata: {},
        );
        final file = File('${backupDir.path}/${project.id}.vep');
        await file.writeAsString(jsonEncode(backup.toJson()));
        count++;
      }
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
    return count;
  }

  // ── List available backups ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!backupDir.existsSync()) return [];

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.vep'))
          .toList();
      final result = <Map<String, dynamic>>[];

      for (final f in files) {
        try {
          final content = await f.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final meta = json['metadata'] as Map? ?? {};
          result.add({
            'file_path': f.path,
            'project_name': (json['project'] as Map?)?['name'] ?? 'Unknown',
            'exported_at': json['exported_at'],
            'duration_sec': meta['duration_sec'] ?? 0,
            'clip_count': meta['clip_count'] ?? 0,
            'size_kb': f.lengthSync() ~/ 1024,
          });
        } catch (_) {}
      }
      result.sort((a, b) =>
          (b['exported_at'] as String).compareTo(a['exported_at'] as String));
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<VideoProject?> restoreBackup(String filePath) =>
      importFromFile(filePath);
}
