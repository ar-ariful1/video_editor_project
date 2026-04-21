import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../core/bloc/timeline_bloc.dart';
import '../../core/models/video_project.dart';
import '../../core/utils/utils.dart';
import 'panels/ai_panel.dart';
import 'panels/audio_panel.dart';
import 'panels/beauty_panel.dart';
import 'panels/chroma_key_panel.dart';
import 'panels/color_panel.dart';
import 'panels/effects_panel.dart';
import 'panels/export_panel.dart';
import 'panels/mask_panel.dart';
import 'panels/media_bin_panel.dart';
import 'panels/pip_panel.dart';
import 'panels/speed_panel.dart';
import 'panels/text_panel.dart';
import 'widgets/preview_player.dart';
import 'widgets/timeline_widget.dart';
import 'panels/animation_panel.dart';
import 'panels/sticker_panel.dart';
import 'panels/crop_panel.dart';
import 'panels/transitions_panel.dart';
import 'panels/color_grading_panel.dart';
import 'widgets/toolbar.dart';
import '../../core/engine/native_engine_bridge.dart';
import 'package:collection/collection.dart';

enum EditorPanel {
  none,
  media,
  audio,
  text,
  pip,
  effects,
  transitions,
  filters,
  adjust,
  ai,
  speed,
  animation,
  mask,
  chroma,
  beauty,
  sticker,
  crop,
  color,
}

class EditorScreen extends StatefulWidget {
  final String? projectId;
  const EditorScreen({super.key, this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorPanel _activePanel = EditorPanel.none;
  bool _isPanelOpen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initEngine();
    if (widget.projectId != null) {
      context.read<TimelineBloc>().add(LoadProjectById(widget.projectId!));
    }
  }
   
  Future<void> _initEngine() async {
    _engine = NativeEngineBridge();
    await _engine.initialize();
    _previewTextureId = await _engine.createVideoTexture();
    setState(() => _engineReady = true);
  }


  @override
  void dispose() {
    _engine.release();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  Future<void> _loadClipToEngine(Clip clip) async {
    if (clip.mediaType == 'video') {
      final metadata = await _engine.loadVideo(clip.mediaPath);
      // মেটাডেটা সংরক্ষণ করতে পারেন
    }
  }
  
  void _togglePlayback() {
    final state = context.read<TimelineBloc>().state;
    if (state.isPlaying) {
      _engine.pause();
      context.read<TimelineBloc>().add(const Pause());
    } else {
      _engine.play();
      context.read<TimelineBloc>().add(const Play());
    }
  }

  void _seekTo(double seconds) {
    _engine.seekTo((seconds * 1000000).toInt());
    context.read<TimelineBloc>().add(SeekTo(seconds));
  }
  }

  void _showPanel(EditorPanel panel) {
    setState(() {
      _activePanel = panel;
      _isPanelOpen = true;
    });
  }

  void _closePanel() {
    setState(() {
      _isPanelOpen = false;
      _activePanel = EditorPanel.none;
    });
  }

  String _panelLabel(EditorPanel key) {
    switch (key) {
      case EditorPanel.media: return 'Media';
      case EditorPanel.audio: return 'Audio';
      case EditorPanel.text: return 'Text';
      case EditorPanel.pip: return 'Overlay';
      case EditorPanel.effects: return 'Effects';
      case EditorPanel.transitions: return 'Transitions';
      case EditorPanel.filters: return 'Filters';
      case EditorPanel.adjust: return 'Adjust';
      case EditorPanel.ai: return 'AI Tools';
      case EditorPanel.speed: return 'Speed';
      case EditorPanel.animation: return 'Animation';
      case EditorPanel.mask: return 'Mask';
      case EditorPanel.chroma: return 'Chroma Key';
      case EditorPanel.beauty: return 'Beauty';
      case EditorPanel.sticker: return 'Sticker';
      case EditorPanel.crop: return 'Crop';
      case EditorPanel.color: return 'Color';
      default: return 'Edit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: _buildAppBar(),
      body: BlocBuilder<TimelineBloc, TimelineState>(
        builder: (context, state) {
          if (state.project == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                flex: 4,
                child: PreviewPlayer(
                  project: state.project!,
                  currentTime: state.currentTime,
                  isPlaying: state.isPlaying,
                  selectedClipId: state.selectedClipId,
                )
              ),
              _buildToolbar(),
              Expanded(
                flex: 5,
                child: TimelineWidget(
                  project: state.project!,
                  currentTime: state.currentTime,
                  zoom: state.zoom,
                  selectedClipId: state.selectedClipId,
                  selectedClipIds: state.selectedClipIds,
                  isMultiSelectMode: state.isMultiSelectMode,
                ),
              ),
              if (_isPanelOpen) _buildSidePanel(),
              _buildFooter(state),
            ],
          );
        }
      ),
    );
  }

  Widget _buildFooter(TimelineState state) {
    final selectedClipId = state.selectedClipId;
    final project = state.project;
    Clip? selectedClip;

    if (project != null && selectedClipId != null) {
      for (final track in project.tracks) {
        selectedClip = track.clips.firstWhereOrNull((c) => c.id == selectedClipId);
        if (selectedClip != null) break;
      }
    }

    if (selectedClip != null) {
      return _buildContextualNav(selectedClip);
    }

    return EditorToolbar(
      activePanel: _activePanel,
      onPanelTap: (panel) {
        if (_activePanel == panel && _isPanelOpen) {
          _closePanel();
        } else {
          _showPanel(panel);
        }
      },
      onExport: _showExportPanel,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: BlocBuilder<TimelineBloc, TimelineState>(
        builder: (context, state) {
          return Text(
            state.project?.name ?? 'Untitled Project',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _showProjectSettings(),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: ElevatedButton(
            onPressed: () => _showExportPanel(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showProjectSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolution', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: Resolution.values.map((res) {
                final isSelected = context.read<TimelineBloc>().state.project?.resolution == res;
                return ChoiceChip(
                  label: Text(res.label),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      context.read<TimelineBloc>().add(UpdateResolution(res));
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showExportPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExportPanel(),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 44,
      color: AppTheme.bg2,
      child: BlocBuilder<TimelineBloc, TimelineState>(
        builder: (context, state) {
          return _PlaybackBar(
            isPlaying: state.isPlaying,
            currentTime: state.currentTime,
            totalDuration: state.project?.computedDuration ?? 0,
            onTogglePlay: () => context.read<TimelineBloc>().add(const PlayPause()),
            onSeek: (t) => context.read<TimelineBloc>().add(SeekTo(t)),
          );
        },
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      height: 250,
      color: AppTheme.bg2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_panelLabel(_activePanel),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                  onPressed: _closePanel,
                ),
              ],
            ),
          ),
          Expanded(child: _getPanelWidget()),
        ],
      ),
    );
  }

  Widget _getPanelWidget() {
    final state = context.read<TimelineBloc>().state;
    switch (_activePanel) {
      case EditorPanel.media: return const MediaBinPanel();
      case EditorPanel.audio: return AudioPanel(selectedClipId: state.selectedClipId);
      case EditorPanel.text: return const TextPanel();
      case EditorPanel.pip: return const PiPPanel();
      case EditorPanel.effects: return const EffectsPanel();
      case EditorPanel.ai: return const AIPanel();
      case EditorPanel.speed: return const SpeedPanel();
      case EditorPanel.animation: return const AnimationPanel();
      case EditorPanel.mask: return const MaskPanel();
      case EditorPanel.chroma: return const ChromaKeyPanel();
      case EditorPanel.beauty: return const BeautyPanel();
      case EditorPanel.filters:
      case EditorPanel.color: return const ColorPanel();
      case EditorPanel.sticker: return const StickerPanel();
      case EditorPanel.crop: return const CropPanel();
      case EditorPanel.transitions:
        if (state.selectedTrackId != null && state.selectedClipId != null) {
          return TransitionsPanel(
            trackId: state.selectedTrackId!,
            clipId: state.selectedClipId!,
          );
        }
        return const Center(child: Text('Select a clip to add transitions', style: TextStyle(color: Colors.white54)));
      case EditorPanel.adjust: return const ColorGradingPanel();
      default: return const Center(child: Text('Panel coming soon', style: TextStyle(color: Colors.white54)));
    }
  }

  Widget _buildContextualNav(Clip clip) {
    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _navItem(Icons.content_cut_rounded, 'Split', 'split'),
            _navItem(Icons.animation_rounded, 'Animation', EditorPanel.animation),
            _navItem(Icons.delete_outline_rounded, 'Delete', 'delete'),
            if (clip.mediaType == 'video') ...[
              _navItem(Icons.auto_fix_high_rounded, 'Remove Background', EditorPanel.chroma),
              _navItem(Icons.transform_rounded, 'Transform', EditorPanel.crop),
              _navItem(Icons.grid_view_rounded, 'Mask', EditorPanel.mask),
              _navItem(Icons.face_retouching_natural_rounded, 'Retouch', EditorPanel.beauty),
              _navItem(Icons.speed_rounded, 'Speed', EditorPanel.speed),
              _navItem(Icons.settings_backup_restore_rounded, 'Reverse', 'reverse'),
            ],
            if (clip.mediaType == 'image') ...[
              _navItem(Icons.auto_fix_high_rounded, 'Remove Background', EditorPanel.chroma),
              _navItem(Icons.transform_rounded, 'Transform', EditorPanel.crop),
              _navItem(Icons.grid_view_rounded, 'Mask', EditorPanel.mask),
              _navItem(Icons.face_retouching_natural_rounded, 'Retouch', EditorPanel.beauty),
            ],
            if (clip.mediaType == 'audio' || clip.mediaType == 'video') ...[
              _navItem(Icons.volume_up_rounded, 'Volume', EditorPanel.audio),
              _navItem(Icons.link_off_rounded, 'Unlink', 'unlink'),
            ],
            if (clip.isTextLayer) ...[
              _navItem(Icons.text_fields_rounded, 'Style', EditorPanel.text),
              _navItem(Icons.spellcheck_rounded, 'Auto Captions', EditorPanel.ai),
            ],
            _navItem(Icons.copy_rounded, 'Duplicate', 'duplicate'),
            _navItem(Icons.swap_horiz_rounded, 'Replace', 'replace'),
            _navItem(Icons.opacity_rounded, 'Opacity', EditorPanel.color),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, dynamic action) {
    final bool active = _activePanel == action && _isPanelOpen;
    return GestureDetector(
      onTap: () {
        if (action == 'split') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            context.read<TimelineBloc>().add(SplitClip(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                ));
          }
        } else if (action == 'delete') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            context.read<TimelineBloc>().add(RemoveClip(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                ));
          }
        } else if (action == 'duplicate') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            context.read<TimelineBloc>().add(DuplicateClip(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                ));
          }
        } else if (action == 'unlink') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            context.read<TimelineBloc>().add(UnlinkAudio(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                ));
          }
        } else if (action == 'reverse') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            context.read<TimelineBloc>().add(ReverseClip(
                  trackId: state.selectedTrackId!,
                  clipId: state.selectedClipId!,
                ));
          }
        } else if (action == 'replace') {
          final state = context.read<TimelineBloc>().state;
          if (state.selectedTrackId != null && state.selectedClipId != null) {
            _replaceMedia(state.selectedTrackId!, state.selectedClipId!);
          }
        } else if (action is EditorPanel) {
          _showPanel(action);
        }
      },
      child: Container(
        width: 65,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? AppTheme.accent : Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: active ? AppTheme.accent : Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _replaceMedia(String trackId, String clipId) async {
    final ImagePicker picker = ImagePicker();
    final bloc = context.read<TimelineBloc>();

    final String? type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Replace Media',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickActionItem(
                  icon: Icons.video_collection_rounded,
                  label: 'Video',
                  onTap: () => Navigator.pop(ctx, 'video'),
                ),
                _QuickActionItem(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  onTap: () => Navigator.pop(ctx, 'image'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (type == null) return;

    XFile? file;
    if (type == 'video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else if (type == 'image') {
      file = await picker.pickImage(source: ImageSource.gallery);
    }

    if (file != null && mounted) {
      bloc.add(ReplaceClip(
        trackId: trackId,
        clipId: clipId,
        newMediaPath: file.path,
      ));
    }
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final double currentTime, totalDuration;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;

  const _PlaybackBar({
    required this.isPlaying,
    required this.currentTime,
    required this.totalDuration,
    required this.onTogglePlay,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalDuration > 0 ? (currentTime / totalDuration).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(formatTimecode(currentTime, 30),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTapDown: (d) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || totalDuration <= 0) return;
                final fraction = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                onSeek(fraction * totalDuration);
              },
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTogglePlay,
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(formatDuration(totalDuration),
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
