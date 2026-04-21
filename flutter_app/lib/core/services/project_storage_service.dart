import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/video_project.dart';

class ProjectStorageService {
  static final ProjectStorageService _instance = ProjectStorageService._();
  factory ProjectStorageService() => _instance;
  ProjectStorageService._();

  static const String _key = 'saved_projects';

  /// Save or Update a project
  Future<void> saveProject(VideoProject project) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];

    final List<VideoProject> projects = rawList
        .map((item) => VideoProject.fromJson(jsonDecode(item)))
        .toList();

    // Check if project exists
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      projects[index] = project.copyWith(updatedAt: DateTime.now());
    } else {
      projects.add(project);
    }

    // Save back to prefs
    final List<String> updatedRawList = projects
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    await prefs.setStringList(_key, updatedRawList);
  }

  /// Get all saved projects
  Future<List<VideoProject>> getAllProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];

    return rawList
        .map((item) => VideoProject.fromJson(jsonDecode(item)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Newest first
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];

    final updatedRawList = rawList.where((item) {
      final project = VideoProject.fromJson(jsonDecode(item));
      return project.id != id;
    }).toList();

    await prefs.setStringList(_key, updatedRawList);
  }

  /// Get a single project by ID
  Future<VideoProject?> getProject(String id) async {
    final projects = await getAllProjects();
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Duplicate a project
  Future<void> duplicateProject(String id) async {
    final project = await getProject(id);
    if (project == null) return;

    final newProject = VideoProject(
      id: const Uuid().v4(),
      name: '${project.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tracks: project.tracks,
      assets: project.assets,
      resolution: project.resolution,
      audioMix: project.audioMix,
      globalColorGrade: project.globalColorGrade,
      duration: project.duration,
    );
    await saveProject(newProject);
  }
}
