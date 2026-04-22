// lib/features/editor/panels/pip_panel.dart
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../core/extensions/iterable_extensions.dart';

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
    _tabs = TabController(length: 3, vsync: this);
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
          Tab(text: 'Layouts'),
          Tab(text: 'Styles')
        ],
        labelColor: AppTheme.accent,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.accent,
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _buildAddTab(context),
          _buildLayoutTab(context),
          _buildStyleTab(context),
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

  Widget _buildStyleTab(BuildContext context) {
    final state = context.watch<TimelineBloc>().state;
    final selectedClipId = state.selectedClipId;
    final selectedTrackId = state.selectedTrackId;

    Clip? selectedClip;
    if (selectedTrackId != null && selectedClipId != null) {
      final track = state.project?.tracks.firstWhereOrNull((t) => t.id == selectedTrackId);
      selectedClip = track?.clips.firstWhereOrNull((c) => c.id == selectedClipId);
    }

    if (selectedClip == null) {
      return const Center(
        child: Text('Select a clip to edit styles',
            style: TextStyle(color: AppTheme.textTertiary)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Blend Mode',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.bg3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BlendMode>(
              value: selectedClip.blendMode,
              isExpanded: true,
              dropdownColor: AppTheme.bg2,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              items: BlendMode.values
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(m.name.toUpperCase())))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _updateClip(context, selectedTrackId!, selectedClip!.copyWith(blendMode: v));
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Opacity',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        _StyleSlider(
          label: 'Level',
          value: selectedClip.opacity,
          onChanged: (v) => _updateClip(context, selectedTrackId!, selectedClip!.copyWith(opacity: v)),
        ),
        const Divider(height: 32, color: AppTheme.border),
        
        // Chroma Key Section
        _buildChromaKeySection(context, selectedTrackId!, selectedClip),
        
        const Divider(height: 32, color: AppTheme.border),
        
        // Mask Section
        _buildMaskSection(context, selectedTrackId!, selectedClip),
        
        const SizedBox(height: 20),
        const Text('Border & Shadow',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _StyleSlider(label: 'Border Width', value: 0.0, onChanged: (v) {}),
        _StyleSlider(label: 'Corner Radius', value: 0.0, onChanged: (v) {}),
        _StyleSlider(label: 'Shadow Blur', value: 0.0, onChanged: (v) {}),
      ]),
    );
  }

  Widget _buildChromaKeySection(BuildContext context, String trackId, Clip clip) {
    final chroma = clip.chromaKey ?? ChromaKey.create();
    final enabled = clip.chromaKey != null && clip.chromaKey!.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Chroma Key (Green Screen)',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Switch(
              value: enabled,
              onChanged: (v) {
                _updateClip(context, trackId, clip.copyWith(
                  chromaKey: chroma.copyWith(enabled: v)
                ));
              },
              activeColor: AppTheme.accent,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          const Text('Key Color', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: ChromaKeyColor.values.map((c) {
              final sel = chroma.keyColor == c;
              return GestureDetector(
                onTap: () => _updateClip(context, trackId, clip.copyWith(
                  chromaKey: chroma.copyWith(keyColor: c)
                )),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getChromaColor(c, chroma.customColor),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: sel ? [const BoxShadow(color: Colors.black45, blurRadius: 4)] : null,
                  ),
                  child: sel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _StyleSlider(
            label: 'Similarity',
            value: chroma.similarity,
            onChanged: (v) => _updateClip(context, trackId, clip.copyWith(
              chromaKey: chroma.copyWith(similarity: v)
            )),
          ),
          _StyleSlider(
            label: 'Smoothness',
            value: chroma.smoothness,
            onChanged: (v) => _updateClip(context, trackId, clip.copyWith(
              chromaKey: chroma.copyWith(smoothness: v)
            )),
          ),
        ],
      ],
    );
  }

  Widget _buildMaskSection(BuildContext context, String trackId, Clip clip) {
    final mask = clip.mask ?? Mask.create(type: MaskType.none);
    final enabled = mask.type != MaskType.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Masking',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MaskType.values.map((type) {
              final sel = mask.type == type;
              return GestureDetector(
                onTap: () => _updateClip(context, trackId, clip.copyWith(
                  mask: mask.copyWith(type: type)
                )),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(_getMaskIcon(type), color: sel ? AppTheme.accent : AppTheme.textSecondary, size: 20),
                      const SizedBox(height: 4),
                      Text(type.name.capitalize, style: TextStyle(color: sel ? AppTheme.accent : AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 16),
          _StyleSlider(
            label: 'Feather',
            value: mask.feather / 100.0, // Assuming 0-100 range for feather
            onChanged: (v) => _updateClip(context, trackId, clip.copyWith(
              mask: mask.copyWith(feather: v * 100.0)
            )),
          ),
          _StyleSlider(
            label: 'Mask Opacity',
            value: mask.opacity,
            onChanged: (v) => _updateClip(context, trackId, clip.copyWith(
              mask: mask.copyWith(opacity: v)
            )),
          ),
          Row(
            children: [
              const Text('Invert Mask', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              const Spacer(),
              Switch(
                value: mask.inverted,
                onChanged: (v) => _updateClip(context, trackId, clip.copyWith(
                  mask: mask.copyWith(inverted: v)
                )),
                activeColor: AppTheme.accent,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getChromaColor(ChromaKeyColor type, Color custom) {
    switch (type) {
      case ChromaKeyColor.green: return Colors.green;
      case ChromaKeyColor.blue: return Colors.blue;
      case ChromaKeyColor.red: return Colors.red;
      case ChromaKeyColor.custom: return custom;
    }
  }

  IconData _getMaskIcon(MaskType type) {
    switch (type) {
      case MaskType.none: return Icons.block;
      case MaskType.circle: return Icons.circle_outlined;
      case MaskType.linear: return Icons.linear_scale;
      case MaskType.rectangle: return Icons.crop_square;
      case MaskType.heart: return Icons.favorite_border;
      case MaskType.star: return Icons.star_border;
      case MaskType.text: return Icons.text_fields;
      case MaskType.custom: return Icons.gesture;
    }
  }

  void _updateClip(BuildContext context, String trackId, Clip clip) {
    context.read<TimelineBloc>().add(UpdateClip(trackId: trackId, clip: clip));
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

class _StyleSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool hasKeyframes;
  final VoidCallback? onKeyframeToggle;

  const _StyleSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hasKeyframes = false,
    this.onKeyframeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            if (onKeyframeToggle != null)
              GestureDetector(
                onTap: onKeyframeToggle,
                child: Icon(
                  hasKeyframes ? Icons.diamond : Icons.diamond_outlined,
                  size: 14,
                  color: hasKeyframes ? AppTheme.accent : AppTheme.textTertiary,
                ),
              ),
          ],
        ),
        Row(children: [
          Expanded(
              child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged)),
          Text('${(value * 100).toInt()}%',
              style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }
}
