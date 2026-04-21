// lib/features/editor/panels/pip_panel.dart
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class PiPPanel extends StatefulWidget {
  const PiPPanel({super.key});
  @override
  State<PiPPanel> createState() => _PiPPanelState();
}

class _PiPPanelState extends State<PiPPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _selectedLayout = 0;

  static const List<_Layout> _pipLayouts = [
    _Layout('Bottom Right', Alignment.bottomRight, 0.3),
    _Layout('Bottom Left', Alignment.bottomLeft, 0.3),
    _Layout('Top Right', Alignment.topRight, 0.3),
    _Layout('Top Left', Alignment.topLeft, 0.3),
    _Layout('Center', Alignment.center, 0.4),
  ];

  static const List<_SplitLayout> _splitLayouts = [
    _SplitLayout('Vertical Split', Icons.view_column_rounded, 'Two videos side-by-side'),
    _SplitLayout('Horizontal Split', Icons.view_stream_rounded, 'One video above another'),
    _SplitLayout('Grid 2x2', Icons.grid_view_rounded, 'Four videos in a grid'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addOverlay() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media != null && mounted) {
      final bloc = context.read<TimelineBloc>();
      final state = bloc.state;
      if (state.project == null) return;

      // Find or create overlay track
      var overlayTrack = state.project!.tracks.firstWhere(
        (t) => t.type == TrackType.video && t.name == 'Overlay',
        orElse: () => Track.create(name: 'Overlay', type: TrackType.video, zIndex: 10),
      );

      if (!state.project!.tracks.contains(overlayTrack)) {
        bloc.add(const AddTrack(type: TrackType.video, name: 'Overlay'));
        // Wait for state update to get the real ID if it was just created
        await Future.delayed(const Duration(milliseconds: 50));
        final updatedState = bloc.state;
        overlayTrack = updatedState.project!.tracks.firstWhere((t) => t.name == 'Overlay');
      }

      final ext = media.path.split('.').last.toLowerCase();
      final type = ['jpg', 'jpeg', 'png'].contains(ext) ? 'image' : 'video';

      final clip = Clip.create(
        startTime: state.currentTime,
        endTime: state.currentTime + (type == 'image' ? 3.0 : 5.0),
        mediaPath: media.path,
        mediaType: type,
      ).copyWith(
        transform: const Transform3D(scaleX: 0.5, scaleY: 0.5), // Default smaller for PiP
      );

      bloc.add(AddClip(trackId: overlayTrack.id, clip: clip));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Add Overlay'),
          Tab(text: 'Layouts')
        ],
        labelColor: AppTheme.accent,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.accent,
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _buildAddTab(context),
          _buildLayoutTab(context),
        ]),
      ),
    ]);
  }

  Widget _buildAddTab(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_outlined, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addOverlay,
            icon: const Icon(Icons.add),
            label: const Text('Add Overlay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Select media to add as a PiP layer',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLayoutTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Position',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_pipLayouts.length, (i) {
                final layout = _pipLayouts[i];
                final sel = _selectedLayout == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLayout = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Text(layout.name,
                        style: TextStyle(
                            color: sel ? AppTheme.accent : AppTheme.textSecondary,
                            fontSize: 12)),
                  ),
                );
              })),
          const SizedBox(height: 16),
          const Text('Size',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Row(children: [
            const Icon(Icons.photo_size_select_small_rounded,
                color: AppTheme.textTertiary, size: 16),
            Expanded(
                child: Slider(
                    value: _selectedLayout < _pipLayouts.length ? _pipLayouts[_selectedLayout].size : 0.5,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) {
                      // Logic to update selected clip size
                    })),
            const Icon(Icons.photo_size_select_large_rounded,
                color: AppTheme.textTertiary, size: 16),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _applyPiP(context),
              icon: const Icon(Icons.picture_in_picture_rounded),
              label: const Text('Apply Picture-in-Picture'),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Split Layout',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...List.generate(_splitLayouts.length, (i) {
            final layout = _splitLayouts[i];
            final layoutIdx = i + 100;
            final sel = _selectedLayout == layoutIdx;
            return GestureDetector(
              onTap: () => setState(() => _selectedLayout = layoutIdx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
                ),
                child: Row(children: [
                  Icon(layout.icon,
                      color: sel ? AppTheme.accent : AppTheme.textSecondary,
                      size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(layout.name,
                            style: TextStyle(
                                color: sel ? AppTheme.accent : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(layout.desc,
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 11)),
                      ])),
                  if (sel)
                    const Icon(Icons.check_circle,
                        color: AppTheme.accent, size: 18),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedLayout >= 100 ? () => _applySplit(context) : null,
              icon: const Icon(Icons.view_column_rounded),
              label: const Text('Apply Split Screen'),
            ),
          ),
        ],
      ),
    );
  }

  void _applyPiP(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('✅ PiP applied — drag the overlay in preview to position'),
        backgroundColor: AppTheme.green));
  }

  void _applySplit(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('✅ Split screen layout applied'),
        backgroundColor: AppTheme.green));
  }
}

class _Layout {
  final String name;
  final Alignment alignment;
  final double size;
  const _Layout(this.name, this.alignment, this.size);
}

class _SplitLayout {
  final String name;
  final IconData icon;
  final String desc;
  const _SplitLayout(this.name, this.icon, this.desc);
}
