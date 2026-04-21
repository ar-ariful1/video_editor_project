// lib/core/services/undo_redo_service.dart
// Professional Undo/Redo system with auto-save and recovery

import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/video_project.dart';

class UndoRedoService {
  static final UndoRedoService _instance = UndoRedoService._();
  factory UndoRedoService() => _instance;
  UndoRedoService._();

  final List<VideoProject> _history = [];
  int _currentIndex = -1;
  int get currentIndex => _currentIndex;
  
  int get maxHistorySize => 50;  // Unlimited undo/redo up to 50 states
  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;
  
  final StreamController<UndoRedoEvent> _eventController = StreamController.broadcast();
  Stream<UndoRedoEvent> get events => _eventController.stream;
  
  Timer? _autoSaveTimer;
  static const autoSaveInterval = Duration(seconds: 30);
  
  // Auto-save file path
  late String _autoSavePath;
  
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _autoSavePath = '${dir.path}/auto_save.json';
    await _loadAutoSave();
    
    // Start auto-save timer
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) => autoSave());
  }
  
  void dispose() {
    _autoSaveTimer?.cancel();
    _eventController.close();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Save current state to history
  // ──────────────────────────────────────────────────────────────────────────
  
  void pushState(VideoProject project, {String? actionName}) {
    // Remove any redo states
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Add new state (deep copy)
    final copy = VideoProject.fromJson(project.toJson());
    _history.add(copy);
    
    // Limit history size
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    } else {
      _currentIndex++;
    }
    
    _eventController.add(UndoRedoEvent(
      type: UndoRedoEventType.statePushed,
      canUndo: canUndo,
      canRedo: canRedo,
      actionName: actionName,
    ));
    
    // Trigger auto-save
    autoSave();
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Undo operation
  // ──────────────────────────────────────────────────────────────────────────
  
  VideoProject? undo() {
    if (!canUndo) return null;
    
    _currentIndex--;
    final project = _history[_currentIndex];
    
    _eventController.add(UndoRedoEvent(
      type: UndoRedoEventType.undo,
      canUndo: canUndo,
      canRedo: canRedo,
    ));
    
    return VideoProject.fromJson(project.toJson());
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Redo operation
  // ──────────────────────────────────────────────────────────────────────────
  
  VideoProject? redo() {
    if (!canRedo) return null;
    
    _currentIndex++;
    final project = _history[_currentIndex];
    
    _eventController.add(UndoRedoEvent(
      type: UndoRedoEventType.redo,
      canUndo: canUndo,
      canRedo: canRedo,
    ));
    
    return VideoProject.fromJson(project.toJson());
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Clear history
  // ──────────────────────────────────────────────────────────────────────────
  
  void clearHistory() {
    _history.clear();
    _currentIndex = -1;
    
    _eventController.add(UndoRedoEvent(
      type: UndoRedoEventType.historyCleared,
      canUndo: false,
      canRedo: false,
    ));
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Auto-save functionality
  // ──────────────────────────────────────────────────────────────────────────
  
  Future<void> autoSave() async {
    if (_currentIndex < 0) return;
    
    try {
      final currentProject = _history[_currentIndex];
      final json = currentProject.toJson();
      final data = jsonEncode(json);
      await File(_autoSavePath).writeAsString(data);
      
      _eventController.add(UndoRedoEvent(
        type: UndoRedoEventType.autoSaved,
        canUndo: canUndo,
        canRedo: canRedo,
      ));
    } catch (e) {
      debugPrint('Auto-save failed: $e');
    }
  }
  
  Future<void> _loadAutoSave() async {
    try {
      final file = File(_autoSavePath);
      if (await file.exists()) {
        final data = await file.readAsString();
        final json = jsonDecode(data) as Map<String, dynamic>;
        final project = VideoProject.fromJson(json);
        
        // Clear existing history and add recovered project
        clearHistory();
        pushState(project, actionName: 'Recovered from auto-save');
        
        _eventController.add(UndoRedoEvent(
          type: UndoRedoEventType.autoSaveLoaded,
          canUndo: canUndo,
          canRedo: canRedo,
        ));
      }
    } catch (e) {
      debugPrint('Load auto-save failed: $e');
    }
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Get current project (without affecting history)
  // ──────────────────────────────────────────────────────────────────────────
  
  VideoProject? getCurrentProject() {
    if (_currentIndex < 0) return null;
    return VideoProject.fromJson(_history[_currentIndex].toJson());
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Get history info
  // ──────────────────────────────────────────────────────────────────────────
  
  int getHistorySize() => _history.length;
  
  List<VideoProject> getHistory() {
    return _history.map((p) => VideoProject.fromJson(p.toJson())).toList();
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // Jump to specific state
  // ──────────────────────────────────────────────────────────────────────────
  
  VideoProject? jumpToState(int index) {
    if (index < 0 || index >= _history.length) return null;
    
    _currentIndex = index;
    final project = _history[_currentIndex];
    
    _eventController.add(UndoRedoEvent(
      type: UndoRedoEventType.stateJumped,
      canUndo: canUndo,
      canRedo: canRedo,
    ));
    
    return VideoProject.fromJson(project.toJson());
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Event Models
// ──────────────────────────────────────────────────────────────────────────

enum UndoRedoEventType {
  statePushed,
  undo,
  redo,
  historyCleared,
  autoSaved,
  autoSaveLoaded,
  stateJumped,
}

class UndoRedoEvent {
  final UndoRedoEventType type;
  final bool canUndo;
  final bool canRedo;
  final String? actionName;
  final DateTime timestamp;
  
  UndoRedoEvent({
    required this.type,
    required this.canUndo,
    required this.canRedo,
    this.actionName,
  }) : timestamp = DateTime.now();
}