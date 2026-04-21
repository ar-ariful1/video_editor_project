// lib/core/repositories/project_repository.dart
// Local-first project storage with Hive + cloud sync via API

import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/video_project.dart';

class ProjectRepository {
  static final ProjectRepository _instance = ProjectRepository._();
  factory ProjectRepository() => _instance;
  ProjectRepository._();

  static const String _boxName = 'projects';
  static const String _apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.yourapp.com');

  late Box<String> _box;
  late Dio _dio;

  Future<void> init(String? authToken) async {
    await Hive.initFlutter();

    // ১০০% সিকিউরিটির জন্য এনক্রিপশন কি তৈরি বা উদ্ধার করা হচ্ছে
    final encryptionKey = await _getSecureKey();

    // এনক্রিপশন কি সহ হাইভ বক্স ওপেন করা হচ্ছে
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _dio = Dio(BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        if (authToken != null) 'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    ));
  }

  Future<List<int>> _getSecureKey() async {
    const secureStorage = FlutterSecureStorage();
    // চাবিটি অলরেডি আছে কি না চেক করা হচ্ছে
    String? base64Key = await secureStorage.read(key: 'encrypted_box_key');

    if (base64Key == null) {
      // যদি না থাকে, নতুন একটি ২৫৬-বিট চাবি তৈরি করা হচ্ছে
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: 'encrypted_box_key',
        value: base64Encode(key),
      );
      return key;
    } else {
      // যদি থাকে, তবে সেটি ডিকোড করে নেওয়া হচ্ছে
      return base64Url.decode(base64Key);
    }
  }

  // ── Local CRUD ────────────────────────────────────────────────────────────

  Future<List<VideoProject>> getLocalProjects() async {
    final projects = <VideoProject>[];
    for (final key in _box.keys) {
      try {
        final json = jsonDecode(_box.get(key as String)!);
        final project = VideoProject.fromJson(json);
        if (project.status != ProjectStatus.deleted) {
          projects.add(project);
        }
      } catch (e) {
        // Skip corrupted entries
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<VideoProject?> getProject(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      final raw = _box.get(id);
      if (raw == null) return null;
      return VideoProject.fromJson(jsonDecode(raw));
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProject(VideoProject project) async {
    await _box.put(project.id, jsonEncode(project.toJson()));
  }

  Future<void> deleteProjectLocally(String id) async {
    final project = await getProject(id);
    if (project != null) {
      await saveProject(project.copyWith(status: ProjectStatus.deleted));
    }
  }

  Future<VideoProject> createProject({
    String name = 'Untitled Project',
    Resolution? resolution,
  }) async {
    final project = VideoProject.create(name: name, resolution: resolution);
    await saveProject(project);
    return project;
  }

  // ── Cloud Sync ────────────────────────────────────────────────────────────

  Future<List<VideoProject>> fetchCloudProjects() async {
    try {
      final res = await _dio.get('/projects');
      final List cloudProjects = res.data['projects'];
      return cloudProjects.map((p) => _cloudToProject(p)).toList();
    } on DioException {
      return [];
    }
  }

  Future<void> syncProject(VideoProject project) async {
    try {
      // Check if project exists in cloud
      try {
        await _dio.get('/projects/${project.id}');
        // Update existing
        await _dio.put('/projects/${project.id}', data: {
          'title': project.name,
          'timeline_json': project.toJson(),
          'duration_seconds': project.computedDuration,
          'size_bytes': jsonEncode(project.toJson()).length,
        });
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          // Create new
          await _dio.post('/projects', data: {
            'title': project.name,
            'resolution': project.resolution.toJson(),
          });
          // Then update with timeline
          await _dio.put('/projects/${project.id}', data: {
            'timeline_json': project.toJson(),
          });
        } else {
          rethrow;
        }
      }
    } catch (e) {
      // Sync failed — project is still saved locally
    }
  }

  Future<void> syncAll() async {
    final localProjects = await getLocalProjects();
    for (final project in localProjects) {
      await syncProject(project);
    }
  }

  Future<void> pullFromCloud() async {
    final cloudProjects = await fetchCloudProjects();
    for (final project in cloudProjects) {
      final local = await getProject(project.id);
      // Cloud wins if newer
      if (local == null || project.updatedAt.isAfter(local.updatedAt)) {
        await saveProject(project);
      }
    }
  }

  VideoProject _cloudToProject(Map<String, dynamic> data) {
    if (data['timeline_json'] != null) {
      try {
        return VideoProject.fromJson(data['timeline_json']);
      } catch (_) {}
    }
    return VideoProject(
      id: data['id'],
      name: data['title'] ?? 'Untitled',
      resolution: data['resolution'] != null ? Resolution.fromJson(data['resolution']) : Resolution.p1080,
      status: ProjectStatus.values.byName(data['status'] ?? 'draft'),
      thumbnailPath: data['thumbnail_url'],
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }

  // ── Thumbnail Upload ──────────────────────────────────────────────────────

  Future<String?> uploadThumbnail(String projectId, String imagePath) async {
    try {
      // Get pre-signed URL
      final urlRes = await _dio.get('/projects/$projectId/thumbnail-upload-url');
      final uploadUrl = urlRes.data['uploadUrl'] as String;
      final cdnUrl = urlRes.data['cdnUrl'] as String;

      // Upload to S3
      final imageBytes = await _readFileBytes(imagePath);
      await Dio().put(uploadUrl, data: imageBytes, options: Options(
        headers: {'Content-Type': 'image/jpeg'},
      ));

      // Update project record
      await _dio.put('/projects/$projectId', data: {'thumbnail_url': cdnUrl});
      return cdnUrl;
    } catch (e) {
      return null;
    }
  }

  Future<List<int>> _readFileBytes(String path) async {
    return File(path).readAsBytes();
  }

  // ── Export Record ──────────────────────────────────────────────────────────

  Future<void> recordExport(String projectId, ExportQuality quality, String outputPath) async {
    try {
      await _dio.post('/exports', data: {
        'project_id': projectId,
        'quality': quality.name,
        'output_path': outputPath,
      });
    } catch (_) {}
  }

  Future<void> renameProject(String id, String newName) async {
    final project = await getProject(id);
    if (project != null) {
      await saveProject(project.copyWith(name: newName));
    }
  }

  Future<void> duplicateProject(String id) async {
    final project = await getProject(id);
    if (project == null) return;
    try {
      final now = DateTime.now();
      final newTracks = project.tracks.map((track) {
        return track.copyWith(
          id: const Uuid().v4(),
          clips: track.clips.map((clip) {
            return clip.copyWith(
              id: const Uuid().v4(),
              keyframes: clip.keyframes.map((k) => k.copyWith(id: const Uuid().v4())).toList(),
            );
          }).toList(),
        );
      }).toList();

      final newProject = project.copyWith(
        id: const Uuid().v4(),
        name: '${project.name} (Copy)',
        tracks: newTracks,
        updatedAt: now,
      );
      await saveProject(newProject);
    } catch (e) {
      // Handle error
    }
  }
}
