// lib/core/bloc/timeline_bloc.dart
// Complete BLoC state management for the timeline editor

import 'dart:async';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../models/video_project.dart';
import '../services/project_storage_service.dart';
import '../services/snap_service.dart';
import '../engine/timeline_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override
  List<Object?> get props => [];
}

// Project
class LoadProjectById extends TimelineEvent {
  final String projectId;
  const LoadProjectById(this.projectId);
  @override
  List<Object?> get props => [projectId];
}

class CreateNewProject extends TimelineEvent {
  final String name;
  final List<String>? initialMedia;
  const CreateNewProject({required this.name, this.initialMedia});
  @override
  List<Object?> get props => [name, initialMedia];
}

class LoadProject extends TimelineEvent {
  final VideoProject project;
  const LoadProject(this.project);
  @override
  List<Object?> get props => [project.id];
}

class SaveProject extends TimelineEvent {
  const SaveProject();
}

class NewProject extends TimelineEvent {
  final String name;
  final Resolution resolution;
  final List<String> initialMedia;
  const NewProject(
      {this.name = 'Untitled Project',
      this.resolution = Resolution.p1080,
      this.initialMedia = const []});
  @override
  List<Object?> get props => [name, resolution, initialMedia];
}

class AddAsset extends TimelineEvent {
  final ProjectAsset asset;
  const AddAsset(this.asset);
  @override
  List<Object?> get props => [asset.id];
}

class RemoveAsset extends TimelineEvent {
  final String assetId;
  const RemoveAsset(this.assetId);
  @override
  List<Object?> get props => [assetId];
}

// Playback
class PlayPause extends TimelineEvent {
  const PlayPause();
}

class SeekTo extends TimelineEvent {
  final double time;
  const SeekTo(this.time);
  @override
  List<Object?> get props => [time];
}

class StepFrame extends TimelineEvent {
  final bool forward;
  const StepFrame({this.forward = true});
}

class SetPlaybackRate extends TimelineEvent {
  final double rate;
  const SetPlaybackRate(this.rate);
}

// Clips
class AddClip extends TimelineEvent {
  final String trackId;
  final Clip clip;
  const AddClip({required this.trackId, required this.clip});
  @override
  List<Object?> get props => [trackId, clip.id];
}

class RemoveClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  const RemoveClip({required this.trackId, required this.clipId});
  @override
  List<Object?> get props => [trackId, clipId];
}

class MoveClip extends TimelineEvent {
  final String fromTrackId;
  final String toTrackId;
  final String clipId;
  final double newStartTime;
  const MoveClip(
      {required this.fromTrackId,
      required this.toTrackId,
      required this.clipId,
      required this.newStartTime});
  @override
  List<Object?> get props => [clipId, newStartTime];
}

class TrimClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  final double? newStartTime;
  final double? newEndTime;
  const TrimClip(
      {required this.trackId,
      required this.clipId,
      this.newStartTime,
      this.newEndTime});
  @override
  List<Object?> get props => [clipId, newStartTime, newEndTime];
}

class SplitClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  const SplitClip({required this.trackId, required this.clipId});
  @override
  List<Object?> get props => [trackId, clipId];
}

class FreezeFrame extends TimelineEvent {
  final String trackId;
  final String clipId;
  final double time;
  const FreezeFrame({required this.trackId, required this.clipId, required this.time});
}

class ReverseClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  const ReverseClip({required this.trackId, required this.clipId});
}

class ReplaceClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  final String newMediaPath;
  final bool isAdjustmentLayer;
  const ReplaceClip({
    required this.trackId,
    required this.clipId,
    required this.newMediaPath,
    this.isAdjustmentLayer = false,
  });
}

class ExtractAudio extends TimelineEvent {
  final String trackId;
  final String clipId;
  const ExtractAudio({required this.trackId, required this.clipId});
}

class UnlinkAudio extends TimelineEvent {
  final String trackId;
  final String clipId;
  const UnlinkAudio({required this.trackId, required this.clipId});
}

class RippleDelete extends TimelineEvent {
  final String trackId;
  final String clipId;
  const RippleDelete({required this.trackId, required this.clipId});
  @override
  List<Object?> get props => [trackId, clipId];
}

class DuplicateClip extends TimelineEvent {
  final String trackId;
  final String clipId;
  const DuplicateClip({required this.trackId, required this.clipId});
}

class MatchCutToAudio extends TimelineEvent {
  final String videoTrackId;
  final String audioTrackId;
  final List<double> beatTimes;
  const MatchCutToAudio({
    required this.videoTrackId,
    required this.audioTrackId,
    required this.beatTimes,
  });
  @override
  List<Object?> get props => [videoTrackId, audioTrackId, beatTimes];
}

class AddMultipleClips extends TimelineEvent {
  final String trackId;
  final List<Clip> clips;
  const AddMultipleClips({required this.trackId, required this.clips});
  @override
  List<Object?> get props => [trackId, clips.length];
}

class UpdateClip extends TimelineEvent {
  final String trackId;
  final Clip clip;
  const UpdateClip({required this.trackId, required this.clip});
}

class AddTransition extends TimelineEvent {
  final String trackId;
  final String clipId;
  final Transition transition;
  final bool isIn; // true for transitionIn, false for transitionOut
  const AddTransition({
    required this.trackId,
    required this.clipId,
    required this.transition,
    this.isIn = true,
  });
  @override
  List<Object?> get props => [trackId, clipId, transition, isIn];
}

class SelectClip extends TimelineEvent {
  final String? trackId;
  final String? clipId;
  final bool multiSelect;
  const SelectClip({this.trackId, this.clipId, this.multiSelect = false});
  @override
  List<Object?> get props => [trackId, clipId, multiSelect];
}

class DeselectAll extends TimelineEvent {
  const DeselectAll();
}

class SelectAllClips extends TimelineEvent {
  const SelectAllClips();
}

class RemoveSelectedClips extends TimelineEvent {
  const RemoveSelectedClips();
}

class AddOverlay extends TimelineEvent {
  final String mediaPath;
  final String mediaType;
  const AddOverlay({required this.mediaPath, required this.mediaType});
}

class AddKeyframe extends TimelineEvent {
  final String trackId;
  final String clipId;
  final Keyframe keyframe;
  const AddKeyframe({required this.trackId, required this.clipId, required this.keyframe});
}

class AddKeyframes extends TimelineEvent {
  final String trackId;
  final String clipId;
  final List<Keyframe> keyframes;
  const AddKeyframes({required this.trackId, required this.clipId, required this.keyframes});
  @override
  List<Object?> get props => [trackId, clipId, keyframes.length];
}

class RemoveKeyframe extends TimelineEvent {
  final String trackId;
  final String clipId;
  final String keyframeId;
  const RemoveKeyframe({required this.trackId, required this.clipId, required this.keyframeId});
}

// Tracks
class AddTrack extends TimelineEvent {
  final TrackType type;
  final String? name;
  const AddTrack({required this.type, this.name});
}

class RemoveTrack extends TimelineEvent {
  final String trackId;
  const RemoveTrack(this.trackId);
}

class ReorderTrack extends TimelineEvent {
  final int oldIndex;
  final int newIndex;
  const ReorderTrack({required this.oldIndex, required this.newIndex});
}

class UpdateTrack extends TimelineEvent {
  final Track track;
  const UpdateTrack(this.track);
  @override
  List<Object?> get props => [track.id];
}

class AIObjectRemoval extends TimelineEvent {
  final String trackId;
  final String clipId;
  final List<Offset> points;
  final List<Rect>? boxes;
  const AIObjectRemoval({
    required this.trackId,
    required this.clipId,
    required this.points,
    this.boxes,
  });
  @override
  List<Object?> get props => [trackId, clipId, points, boxes];
}

// Undo / Redo
class Undo extends TimelineEvent {
  const Undo();
}

class Redo extends TimelineEvent {
  const Redo();
}

// Zoom / Project Settings
class SetZoom extends TimelineEvent {
  final double zoom;
  const SetZoom(this.zoom);
  @override
  List<Object?> get props => [zoom];
}

class UpdateResolution extends TimelineEvent {
  final Resolution resolution;
  const UpdateResolution(this.resolution);
  @override
  List<Object?> get props => [resolution];
}

class RenameProject extends TimelineEvent {
  final String name;
  const RenameProject(this.name);
  @override
  List<Object?> get props => [name];
}

// Internal
class _PlaybackTick extends TimelineEvent {
  final double time;
  const _PlaybackTick(this.time);
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

enum TimelineStatus { initial, loading, ready, playing, saving, error }

class TimelineState extends Equatable {
  final VideoProject? project;
  final TimelineStatus status;
  final double currentTime;
  final bool isPlaying;
  final double playbackRate;
  final double zoom;
  final String? selectedTrackId;
  final String? selectedClipId;
  final Set<String> selectedClipIds;
  final bool isMultiSelectMode;
  final String? errorMessage;
  final bool canUndo;
  final bool canRedo;
  final List<VideoProject> undoStack;
  final List<VideoProject> redoStack;

  const TimelineState({
    this.project,
    this.status = TimelineStatus.initial,
    this.currentTime = 0,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.zoom = 100.0,
    this.selectedTrackId,
    this.selectedClipId,
    this.selectedClipIds = const {},
    this.isMultiSelectMode = false,
    this.errorMessage,
    this.canUndo = false,
    this.canRedo = false,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  TimelineState copyWith({
    VideoProject? project,
    TimelineStatus? status,
    double? currentTime,
    bool? isPlaying,
    double? playbackRate,
    double? zoom,
    String? selectedTrackId,
    String? selectedClipId,
    Set<String>? selectedClipIds,
    bool? isMultiSelectMode,
    String? errorMessage,
    bool? canUndo,
    bool? canRedo,
    List<VideoProject>? undoStack,
    List<VideoProject>? redoStack,
  }) =>
      TimelineState(
        project: project ?? this.project,
        status: status ?? this.status,
        currentTime: currentTime ?? this.currentTime,
        isPlaying: isPlaying ?? this.isPlaying,
        playbackRate: playbackRate ?? this.playbackRate,
        zoom: zoom ?? this.zoom,
        selectedTrackId: selectedTrackId ?? this.selectedTrackId,
        selectedClipId: selectedClipId ?? this.selectedClipId,
        selectedClipIds: selectedClipIds ?? this.selectedClipIds,
        isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
        errorMessage: errorMessage ?? this.errorMessage,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
      );

  @override
  List<Object?> get props => [
        project,
        status,
        currentTime,
        isPlaying,
        zoom,
        selectedClipId,
        selectedClipIds,
        isMultiSelectMode,
        canUndo,
        canRedo
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  static const int _maxUndoHistory = 50;
  Timer? _playbackTimer;
  final ProjectStorageService _storage = ProjectStorageService();

  TimelineBloc() : super(const TimelineState()) {
    on<AddAsset>(_onAddAsset);
    on<RemoveAsset>(_onRemoveAsset);
    on<CreateNewProject>(_onCreateNewProject);
    on<AddOverlay>(_onAddOverlay);
    on<LoadProjectById>(_onLoadProjectById);
    on<NewProject>(_onNewProject);
    on<LoadProject>(_onLoadProject);
    on<SaveProject>(_onSaveProject);
    on<PlayPause>(_onPlayPause);
    on<SeekTo>(_onSeekTo);
    on<StepFrame>(_onStepFrame);
    on<SetPlaybackRate>(_onSetPlaybackRate);
    on<AddClip>(_onAddClip);
    on<RemoveClip>(_onRemoveClip);
    on<MoveClip>(_onMoveClip);
    on<TrimClip>(_onTrimClip);
    on<SplitClip>(_onSplitClip);
    on<FreezeFrame>(_onFreezeFrame);
    on<ReverseClip>(_onReverseClip);
    on<ReplaceClip>(_onReplaceClip);
    on<ExtractAudio>(_onExtractAudio);
    on<UnlinkAudio>(_onUnlinkAudio);
    on<RippleDelete>(_onRippleDelete);
    on<DuplicateClip>(_onDuplicateClip);
    on<MatchCutToAudio>(_onMatchCutToAudio);
    on<UpdateClip>(_onUpdateClip);
    on<AddTransition>(_onAddTransition);
    on<SelectClip>(_onSelectClip);
    on<DeselectAll>(_onDeselectAll);
    on<SelectAllClips>(_onSelectAllClips);
    on<RemoveSelectedClips>(_onRemoveSelectedClips);
    on<AddKeyframe>(_onAddKeyframe);
    on<AddKeyframes>(_onAddKeyframes);
    on<RemoveKeyframe>(_onRemoveKeyframe);
    on<AddTrack>(_onAddTrack);
    on<RemoveTrack>(_onRemoveTrack);
    on<ReorderTrack>(_onReorderTrack);
    on<UpdateTrack>(_onUpdateTrack);
    on<Undo>(_onUndo);
    on<Redo>(_onRedo);
    on<SetZoom>(_onSetZoom);
    on<UpdateResolution>(_onUpdateResolution);
    on<RenameProject>(_onRenameProject);
    on<AIObjectRemoval>(_onAIObjectRemoval);
    on<AddMultipleClips>(_onAddMultipleClips);
    on<_PlaybackTick>(_onPlaybackTick);
  }

  @override
  Future<void> close() {
    _playbackTimer?.cancel();
    return super.close();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  TimelineState _withUndoableMutation(
      TimelineState state, VideoProject Function(VideoProject) mutate) {
    if (state.project == null) return state;
    final undo = [...state.undoStack, state.project!];
    if (undo.length > _maxUndoHistory) undo.removeAt(0);
    final newProject = mutate(state.project!);

    // Auto-save on every mutation
    _storage.saveProject(newProject);

    return state.copyWith(
      project: newProject,
      undoStack: undo,
      redoStack: [],
      canUndo: true,
      canRedo: false,
    );
  }

  Track? _findTrack(VideoProject project, String trackId) =>
      project.tracks.firstWhereOrNull((t) => t.id == trackId);

  VideoProject _updateTrackInProject(VideoProject project, Track updatedTrack) {
    final tracks = project.tracks
        .map((t) => t.id == updatedTrack.id ? updatedTrack : t)
        .toList();
    return project.copyWith(tracks: tracks);
  }

  String _getMediaType(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) return 'video';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'image';
    }
    if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) return 'audio';
    return 'video';
  }

  // ── handlers ───────────────────────────────────────────────────────────────

  void _onAddAsset(AddAsset event, Emitter<TimelineState> emit) {
    if (state.project == null) return;
    final newState = _withUndoableMutation(state, (project) {
      if (project.assets.any((a) => a.path == event.asset.path)) return project;
      return project.copyWith(assets: [...project.assets, event.asset]);
    });
    emit(newState);
  }

  void _onRemoveAsset(RemoveAsset event, Emitter<TimelineState> emit) {
    if (state.project == null) return;
    final newState = _withUndoableMutation(state, (project) {
      return project.copyWith(
          assets: project.assets.where((a) => a.id != event.assetId).toList());
    });
    emit(newState);
  }

  void _onCreateNewProject(CreateNewProject event, Emitter<TimelineState> emit) {
    add(NewProject(name: event.name, initialMedia: event.initialMedia ?? []));
  }

  void _onAddOverlay(AddOverlay event, Emitter<TimelineState> emit) {
    if (state.project == null) return;

    final newState = _withUndoableMutation(state, (project) {
      final overlayTracks = project.tracks.where((t) => t.type == TrackType.video).toList();
      final nextZIndex = overlayTracks.isEmpty ? 2 : overlayTracks.map((t) => t.zIndex).reduce((a, b) => a > b ? a : b) + 1;

      final newTrack = Track.create(
        name: 'Overlay ${overlayTracks.length}',
        type: TrackType.video,
        zIndex: nextZIndex,
      );

      final newClip = Clip.create(
        startTime: state.currentTime,
        endTime: state.currentTime + 5.0,
        mediaPath: event.mediaPath,
        mediaType: event.mediaType,
      ).copyWith(
        transform: const Transform3D(scaleX: 0.5, scaleY: 0.5),
      );

      final updatedTrack = newTrack.copyWith(clips: [newClip]);
      return project.copyWith(tracks: [...project.tracks, updatedTrack]);
    });

    emit(newState);
  }

  Future<void> _onLoadProjectById(
      LoadProjectById event, Emitter<TimelineState> emit) async {
    emit(state.copyWith(status: TimelineStatus.loading));
    final project = await _storage.getProject(event.projectId);
    if (project != null) {
      emit(state.copyWith(project: project, status: TimelineStatus.ready));
    } else {
      emit(state.copyWith(status: TimelineStatus.error));
    }
  }

  void _onNewProject(NewProject event, Emitter<TimelineState> emit) {
    final project =
        VideoProject.create(name: event.name, resolution: event.resolution);
    var videoTrack =
        Track.create(name: 'Video 1', type: TrackType.video, zIndex: 1);
    final audioTrack =
        Track.create(name: 'Audio 1', type: TrackType.audio, zIndex: 0);

    if (event.initialMedia.isNotEmpty) {
      double currentTime = 0;
      final List<Clip> clips = [];
      for (final path in event.initialMedia) {
        final type = _getMediaType(path);
        final duration = type == 'image' ? 3.0 : 5.0;
        clips.add(Clip.create(
          startTime: currentTime,
          endTime: currentTime + duration,
          mediaPath: path,
          mediaType: type,
        ));
        currentTime += duration;
      }
      videoTrack = videoTrack.copyWith(clips: clips);
    }

    final updated = project.copyWith(tracks: [videoTrack, audioTrack]);
    emit(state.copyWith(
        project: updated, status: TimelineStatus.ready, currentTime: 0));
  }

  void _onLoadProject(LoadProject event, Emitter<TimelineState> emit) {
    emit(state.copyWith(
        project: event.project, status: TimelineStatus.ready, currentTime: 0));
  }

  Future<void> _onSaveProject(
      SaveProject event, Emitter<TimelineState> emit) async {
    if (state.project == null) return;
    emit(state.copyWith(status: TimelineStatus.saving));
    await _storage.saveProject(state.project!);
    emit(state.copyWith(status: TimelineStatus.ready));
  }

  void _onPlayPause(PlayPause event, Emitter<TimelineState> emit) {
    final willPlay = !state.isPlaying;
    _playbackTimer?.cancel();

    if (willPlay) {
      _playbackTimer =
          Timer.periodic(const Duration(milliseconds: 33), (timer) {
        add(_PlaybackTick(state.currentTime + 0.033));
      });
    }

    emit(state.copyWith(
      isPlaying: willPlay,
      status: willPlay ? TimelineStatus.playing : TimelineStatus.ready,
    ));
  }

  void _onPlaybackTick(_PlaybackTick event, Emitter<TimelineState> emit) {
    if (!state.isPlaying) return;

    final maxTime = state.project?.computedDuration ?? 0;
    if (event.time >= maxTime) {
      _playbackTimer?.cancel();
      emit(state.copyWith(
        currentTime: 0,
        isPlaying: false,
        status: TimelineStatus.ready,
      ));
    } else {
      emit(state.copyWith(currentTime: event.time));
    }
  }

  void _onSeekTo(SeekTo event, Emitter<TimelineState> emit) {
    final maxTime = state.project?.computedDuration ?? 0;
    final t = event.time.clamp(0.0, maxTime);
    emit(state.copyWith(currentTime: t));
  }

  void _onStepFrame(StepFrame event, Emitter<TimelineState> emit) {
    final fps = state.project?.resolution.frameRate ?? 30;
    final delta = 1.0 / fps;
    final newTime =
        event.forward ? state.currentTime + delta : state.currentTime - delta;
    final maxTime = state.project?.computedDuration ?? 0;
    emit(state.copyWith(currentTime: newTime.clamp(0.0, maxTime)));
  }

  void _onSetPlaybackRate(SetPlaybackRate event, Emitter<TimelineState> emit) {
    emit(state.copyWith(playbackRate: event.rate));
  }

  void _onAddClip(AddClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;

      List<Clip> updatedClips = [...track.clips];
      
      // Magnetic behavior for Main Track (zIndex 1)
      if (track.zIndex == 1 && track.type == TrackType.video) {
        final double insertTime = event.clip.startTime;
        final double duration = event.clip.duration;
        
        // Shift following clips
        updatedClips = updatedClips.map((c) {
          if (c.startTime >= insertTime - 0.001) {
            return c.copyWith(
              startTime: c.startTime + duration,
              endTime: c.endTime + duration,
            );
          }
          return c;
        }).toList();
      }

      updatedClips = [...updatedClips, event.clip]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      return _updateTrackInProject(project, track.copyWith(clips: updatedClips));
    });
    emit(newState);
  }

  void _onRemoveClip(RemoveClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;

      final removedClip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (removedClip == null) return project;

      final updatedClips = track.clips.where((c) => c.id != event.clipId).toList();

      if (track.zIndex == 1 && track.type == TrackType.video) {
        double currentPos = removedClip.startTime;
        for (int i = 0; i < updatedClips.length; i++) {
          if (updatedClips[i].startTime > removedClip.startTime) {
            final duration = updatedClips[i].duration;
            updatedClips[i] = updatedClips[i].copyWith(
              startTime: currentPos,
              endTime: currentPos + duration,
            );
            currentPos += duration;
          } else {
            currentPos = updatedClips[i].endTime;
          }
        }
      }

      return _updateTrackInProject(project, track.copyWith(clips: updatedClips));
    });
    emit(newState.copyWith(
      selectedClipId: newState.selectedClipId == event.clipId ? null : newState.selectedClipId,
      selectedClipIds: Set<String>.from(newState.selectedClipIds)..remove(event.clipId),
    ));
  }

  void _onRemoveSelectedClips(RemoveSelectedClips event, Emitter<TimelineState> emit) {
    if (state.project == null || state.selectedClipIds.isEmpty) return;

    final newState = _withUndoableMutation(state, (project) {
      var updatedProject = project;
      for (final track in project.tracks) {
        final remainingClips = track.clips.where((c) => !state.selectedClipIds.contains(c.id)).toList();
        if (remainingClips.length != track.clips.length) {
          updatedProject = _updateTrackInProject(updatedProject, track.copyWith(clips: remainingClips));
        }
      }
      return updatedProject;
    });

    emit(newState.copyWith(
      selectedClipId: null,
      selectedClipIds: {},
      isMultiSelectMode: false,
    ));
  }

  void _onMoveClip(MoveClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final fromTrack = _findTrack(project, event.fromTrackId);
      if (fromTrack == null) return project;
      final clip = fromTrack.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (clip == null) return project;
      final duration = clip.duration;

      final sourceUpdated = fromTrack.copyWith(
        clips: fromTrack.clips.where((c) => c.id != event.clipId).toList(),
      );
      var p = _updateTrackInProject(project, sourceUpdated);

      final toTrack = _findTrack(p, event.toTrackId);
      if (toTrack == null) return p;

      // Magnetic snapping
      double snappedStart = event.newStartTime;
      const double threshold = 0.2; // 200ms

      final snapService = SnapService();
      final snapResult = snapService.snap(
        time: snappedStart,
        project: p,
        playheadTime: state.currentTime,
        excludeClipId: event.clipId,
      );

      if (snapResult.didSnap) {
        snappedStart = snapResult.snappedTime;
      }

      final movedClip = clip.copyWith(
        startTime: snappedStart,
        endTime: snappedStart + duration,
      );
      final destUpdated = toTrack.copyWith(
        clips: [...toTrack.clips, movedClip]
          ..sort((a, b) => a.startTime.compareTo(b.startTime)),
      );
      return _updateTrackInProject(p, destUpdated);
    });
    emit(newState);
  }

  void _onTrimClip(TrimClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;

      final originalClip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (originalClip == null) return project;

      final double oldDuration = originalClip.duration;
      final double newStartTime = event.newStartTime ?? originalClip.startTime;
      final double newEndTime = event.newEndTime ?? originalClip.endTime;
      final double newDuration = (newEndTime - newStartTime).clamp(0.1, 3600.0);
      final double delta = newDuration - oldDuration;

      final List<Clip> clips = track.clips.map((c) {
        if (c.id == event.clipId) {
          return c.copyWith(startTime: newStartTime, endTime: newStartTime + newDuration);
        }
        
        // Ripple effect for Main Track
        if (track.zIndex == 1 && track.type == TrackType.video) {
          if (c.startTime > originalClip.startTime) {
            return c.copyWith(
              startTime: c.startTime + delta,
              endTime: c.endTime + delta,
            );
          }
        }
        return c;
      }).toList();

      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onAddMultipleClips(AddMultipleClips event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final updatedClips = [...track.clips, ...event.clips];
      return _updateTrackInProject(project, track.copyWith(clips: updatedClips));
    });
    emit(newState);
  }

  void _onSplitClip(SplitClip event, Emitter<TimelineState> emit) {
    if (state.project == null) return;
    final track = _findTrack(state.project!, event.trackId);
    if (track == null) return;
    final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
    if (clip == null) return;
    final splitTime = state.currentTime;

    if (splitTime <= clip.startTime || splitTime >= clip.endTime) return;

    final newId = const Uuid().v4();
    final newState = _withUndoableMutation(state, (project) {
      final firstHalf = clip.copyWith(endTime: splitTime);
      final secondHalf = clip.copyWith(
        id: newId,
        startTime: splitTime,
        endTime: clip.endTime,
        trimStart: clip.trimStart + (splitTime - clip.startTime) * clip.speed,
      );
      final updatedClips = track.clips
          .where((c) => c.id != clip.id)
          .followedBy([firstHalf, secondHalf]).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return _updateTrackInProject(
          project, track.copyWith(clips: updatedClips));
    });
    emit(newState.copyWith(selectedClipId: newId));
  }

  void _onFreezeFrame(FreezeFrame event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (clip == null) return project;

      final freezeDuration = 3.0;
      final freezeClip = Clip(
        id: const Uuid().v4(),
        startTime: event.time,
        endTime: event.time + freezeDuration,
        mediaPath: clip.mediaPath,
        mediaType: 'image',
        transform: clip.transform,
      );

      final updatedClips = track.clips.map((c) {
        if (c.startTime >= event.time) {
          return c.copyWith(
            startTime: c.startTime + freezeDuration,
            endTime: c.endTime + freezeDuration,
          );
        }
        return c;
      }).toList();

      updatedClips.add(freezeClip);
      updatedClips.sort((a, b) => a.startTime.compareTo(b.startTime));

      return _updateTrackInProject(project, track.copyWith(clips: updatedClips));
    });
    emit(newState);
  }

  void _onReverseClip(ReverseClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        return c.copyWith(isReversed: !c.isReversed);
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onReplaceClip(ReplaceClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        if (event.isAdjustmentLayer && c is AdjustmentLayer) {
            return c.copyWith(mediaPath: event.newMediaPath);
        }
        return c.copyWith(
          mediaPath: event.newMediaPath,
          mediaType: _getMediaType(event.newMediaPath),
        );
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onExtractAudio(ExtractAudio event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (clip == null) return project;

      var audioTrack = project.tracks.firstWhereOrNull((t) => t.type == TrackType.audio);
      if (audioTrack == null) {
        audioTrack = Track.create(name: 'Audio 1', type: TrackType.audio, zIndex: 0);
        project = project.copyWith(tracks: [...project.tracks, audioTrack]);
      }

      final extractedAudio = Clip.create(
        startTime: clip.startTime,
        endTime: clip.endTime,
        mediaPath: clip.mediaPath,
        mediaType: 'audio',
      );

      final updatedAudioClips = [...audioTrack.clips, extractedAudio]..sort((a, b) => a.startTime.compareTo(b.startTime));
      final updatedProject = _updateTrackInProject(project, audioTrack.copyWith(clips: updatedAudioClips));

      final updatedVideoClips = track.clips.map((c) => c.id == clip.id ? c.copyWith(isMuted: true) : c).toList();
      return _updateTrackInProject(updatedProject, track.copyWith(clips: updatedVideoClips));
    });
    emit(newState);
  }

  void _onUnlinkAudio(UnlinkAudio event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (clip == null || clip.mediaType != 'video') return project;

      var audioTrack = project.tracks.firstWhereOrNull((t) => t.type == TrackType.audio);
      if (audioTrack == null) {
        audioTrack = Track.create(name: 'Audio 1', type: TrackType.audio, zIndex: 0);
        project = project.copyWith(tracks: [...project.tracks, audioTrack]);
      }

      final extractedAudio = Clip.create(
        startTime: clip.startTime,
        endTime: clip.endTime,
        mediaPath: clip.mediaPath,
        mediaType: 'audio',
      );

      final updatedAudioClips = [...audioTrack.clips, extractedAudio]..sort((a, b) => a.startTime.compareTo(b.startTime));
      final updatedProject = _updateTrackInProject(project, audioTrack.copyWith(clips: updatedAudioClips));

      final updatedVideoClips = track.clips.map((c) => c.id == clip.id ? c.copyWith(isMuted: true) : c).toList();
      return _updateTrackInProject(updatedProject, track.copyWith(clips: updatedVideoClips));
    });
    emit(newState);
  }

  void _onRippleDelete(RippleDelete event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
      if (clip == null) return project;
      final gap = clip.duration;
      final cutPoint = clip.startTime;

      final updatedClips =
          track.clips.where((c) => c.id != event.clipId).map((c) {
        if (c.startTime >= cutPoint) {
          return c.copyWith(
            startTime: c.startTime - gap,
            endTime: c.endTime - gap,
          );
        }
        return c;
      }).toList();

      return _updateTrackInProject(
          project, track.copyWith(clips: updatedClips));
    });
    emit(newState);
  }

  void _onDuplicateClip(DuplicateClip event, Emitter<TimelineState> emit) {
    if (state.project == null) return;
    final track = _findTrack(state.project!, event.trackId);
    if (track == null) return;
    final clip = track.clips.firstWhereOrNull((c) => c.id == event.clipId);
    if (clip == null) return;
    final newClip = clip.copyWith(
      id: const Uuid().v4(),
      startTime: clip.endTime,
      endTime: clip.endTime + clip.duration,
    );
    add(AddClip(trackId: event.trackId, clip: newClip));
  }

  void _onMatchCutToAudio(MatchCutToAudio event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final videoTrack = _findTrack(project, event.videoTrackId);
      if (videoTrack == null || videoTrack.clips.isEmpty) return project;

      final List<Clip> updatedClips = [];
      final sourceClips = [...videoTrack.clips]..sort((a, b) => a.startTime.compareTo(b.startTime));

      for (int i = 0; i < event.beatTimes.length; i++) {
        final startTime = i == 0 ? 0.0 : event.beatTimes[i - 1];
        final endTime = event.beatTimes[i];

        final sourceClip = sourceClips[i % sourceClips.length];

        updatedClips.add(sourceClip.copyWith(
          id: const Uuid().v4(),
          startTime: startTime,
          endTime: endTime,
        ));
      }

      return _updateTrackInProject(project, videoTrack.copyWith(clips: updatedClips));
    });
    emit(newState);
  }

  void _onUpdateClip(UpdateClip event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips
          .map((c) => c.id == event.clip.id ? event.clip : c)
          .toList();
      final updatedProject = _updateTrackInProject(project, track.copyWith(clips: clips));
      
      // SYNC WITH NATIVE ENGINE
      TimelineEngine().renderFrame(state.currentTime); 
      
      return updatedProject;
    });
    emit(newState);
  }

  void _onAddTransition(AddTransition event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        return event.isIn
            ? c.copyWith(transitionIn: event.transition)
            : c.copyWith(transitionOut: event.transition);
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onSelectClip(SelectClip event, Emitter<TimelineState> emit) {
    if (event.multiSelect) {
      final newSelectedIds = Set<String>.from(state.selectedClipIds);
      if (event.clipId != null) {
        if (newSelectedIds.contains(event.clipId)) {
          newSelectedIds.remove(event.clipId);
        } else {
          newSelectedIds.add(event.clipId!);
        }
      }
      
      emit(state.copyWith(
        selectedClipIds: newSelectedIds,
        isMultiSelectMode: newSelectedIds.isNotEmpty,
        selectedClipId: newSelectedIds.length == 1 ? newSelectedIds.first : null,
      ));
    } else {
      emit(state.copyWith(
        selectedTrackId: event.trackId,
        selectedClipId: event.clipId,
        selectedClipIds: event.clipId != null ? {event.clipId!} : {},
        isMultiSelectMode: false,
      ));
    }
  }

  void _onDeselectAll(DeselectAll event, Emitter<TimelineState> emit) {
    emit(state.copyWith(
      selectedClipId: null,
      selectedTrackId: null,
      selectedClipIds: {},
      isMultiSelectMode: false,
    ));
  }

  void _onSelectAllClips(SelectAllClips event, Emitter<TimelineState> emit) {
    if (state.project == null) return;
    final allIds = state.project!.tracks
        .expand((t) => t.clips)
        .map((c) => c.id)
        .toSet();
    emit(state.copyWith(
      selectedClipIds: allIds,
      isMultiSelectMode: allIds.isNotEmpty,
      selectedClipId: allIds.length == 1 ? allIds.first : null,
    ));
  }

  void _onAddKeyframe(AddKeyframe event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        final filtered = c.keyframes
            .where((k) => !(k.property == event.keyframe.property &&
                (k.time - event.keyframe.time).abs() < 0.001))
            .toList();
        return c.copyWith(
            keyframes: [...filtered, event.keyframe]
              ..sort((a, b) => a.time.compareTo(b.time)));
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onAddKeyframes(AddKeyframes event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        final existing = c.keyframes.toList();
        // Merge keyframes, replacing if same property and time close
        for (final newKf in event.keyframes) {
          existing.removeWhere((k) => k.property == newKf.property && (k.time - newKf.time).abs() < 0.001);
          existing.add(newKf);
        }
        existing.sort((a, b) => a.time.compareTo(b.time));
        return c.copyWith(keyframes: existing);
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onRemoveKeyframe(RemoveKeyframe event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final track = _findTrack(project, event.trackId);
      if (track == null) return project;
      final clips = track.clips.map((c) {
        if (c.id != event.clipId) return c;
        return c.copyWith(keyframes: c.keyframes.where((k) => k.id != event.keyframeId).toList());
      }).toList();
      return _updateTrackInProject(project, track.copyWith(clips: clips));
    });
    emit(newState);
  }

  void _onAddTrack(AddTrack event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final maxZ = project.tracks.isEmpty ? 0 : project.tracks.map((t) => t.zIndex).reduce((a, b) => a > b ? a : b);
      final newTrack = Track.create(
        name: event.name ?? 'Track ${project.tracks.length + 1}',
        type: event.type,
        zIndex: maxZ + 1,
      );
      return project.copyWith(tracks: [...project.tracks, newTrack]);
    });
    emit(newState);
  }

  void _onRemoveTrack(RemoveTrack event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      return project.copyWith(tracks: project.tracks.where((t) => t.id != event.trackId).toList());
    });
    emit(newState);
  }

  void _onReorderTrack(ReorderTrack event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      final tracks = List<Track>.from(project.tracks);
      final track = tracks.removeAt(event.oldIndex);
      tracks.insert(event.newIndex, track);
      // Reassign zIndex based on order
      for (int i = 0; i < tracks.length; i++) {
        tracks[i] = tracks[i].copyWith(zIndex: i);
      }
      return project.copyWith(tracks: tracks);
    });
    emit(newState);
  }

  void _onUpdateTrack(UpdateTrack event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      return _updateTrackInProject(project, event.track);
    });
    emit(newState);
  }

  void _onUndo(Undo event, Emitter<TimelineState> emit) {
    if (!state.canUndo || state.undoStack.isEmpty) return;
    final newUndoStack = List<VideoProject>.from(state.undoStack);
    final prev = newUndoStack.removeLast();
    final newRedoStack = [...state.redoStack, state.project!];
    emit(state.copyWith(
      project: prev,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      canUndo: newUndoStack.isNotEmpty,
      canRedo: true,
    ));
  }

  void _onRedo(Redo event, Emitter<TimelineState> emit) {
    if (!state.canRedo || state.redoStack.isEmpty) return;
    final newRedoStack = List<VideoProject>.from(state.redoStack);
    final next = newRedoStack.removeLast();
    final newUndoStack = [...state.undoStack, state.project!];
    emit(state.copyWith(
      project: next,
      undoStack: newUndoStack,
      redoStack: newRedoStack,
      canUndo: true,
      canRedo: newRedoStack.isNotEmpty,
    ));
  }

  void _onSetZoom(SetZoom event, Emitter<TimelineState> emit) {
    emit(state.copyWith(zoom: event.zoom.clamp(10.0, 500.0)));
  }

  void _onUpdateResolution(UpdateResolution event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      return project.copyWith(resolution: event.resolution);
    });
    emit(newState);
  }

  void _onRenameProject(RenameProject event, Emitter<TimelineState> emit) {
    final newState = _withUndoableMutation(state, (project) {
      return project.copyWith(name: event.name);
    });
    emit(newState);
  }

  void _onAIObjectRemoval(AIObjectRemoval event, Emitter<TimelineState> emit) {
    // Stub for AI object removal
  }
}