// lib/features/editor/panels/text_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';

class TextPanel extends StatefulWidget {
  const TextPanel({super.key});
  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (context, state) {
        final clip = _getSelectedTextLayer(state);

        return Column(children: [
          // Add text button
          if (clip == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addText(context, state),
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Add Text'),
                ),
              ),
            ),

          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Font'),
              Tab(text: 'Style'),
              Tab(text: 'Animate'),
              Tab(text: 'Effects')
            ],
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textTertiary,
            indicatorColor: AppTheme.accent,
          ),

          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _FontTab(layer: clip),
              _StyleTab(layer: clip),
              _AnimateTab(layer: clip),
              _EffectsTab(layer: clip),
            ]),
          ),
        ]);
      },
    );
  }

  TextLayer? _getSelectedTextLayer(TimelineState state) {
    if (state.selectedClipId == null || state.project == null) return null;
    for (final track in state.project!.tracks) {
      for (final clip in track.clips) {
        if (clip.id == state.selectedClipId && clip is TextLayer) return clip;
      }
    }
    return null;
  }

  void _addText(BuildContext context, TimelineState state) {
    final currentTime = state.currentTime;
    final textLayer = TextLayer.create(
      startTime: currentTime,
      endTime: currentTime + 3.0,
      text: 'Your Text Here',
      animIn: 'fadeIn',
    );
    // Find or create text track
    var textTrack = state.project?.tracks.firstWhereOrNull(
      (t) => t.type == TrackType.text,
    );
    
    if (textTrack == null) {
      // Create text track if it doesn't exist
      context.read<TimelineBloc>().add(const AddTrack(type: TrackType.text, name: 'Text 1'));
      
      // Since AddTrack is synchronous, we can get the updated state and add clip
      // For simplicity, we'll just show a message or rely on the user to click again
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text track created. Please add text again.')),
      );
    } else {
      context
          .read<TimelineBloc>()
          .add(AddClip(trackId: textTrack.id, clip: textLayer));
    }
  }
}

class _FontTab extends StatelessWidget {
  final TextLayer? layer;
  const _FontTab({this.layer});

  static const _fonts = [
    'Inter',
    'Playfair Display',
    'Roboto',
    'Montserrat',
    'Oswald',
    'Pacifico',
    'Dancing Script',
    'Bebas Neue'
  ];
  static const _sizes = [20.0, 28.0, 36.0, 48.0, 60.0, 72.0, 96.0];

  void _onChipTap(BuildContext context, String property, dynamic value) {
    if (layer == null) return;
    
    final updated = property == 'fontFamily' 
      ? layer!.copyWith(fontFamily: value as String)
      : property == 'fontSize'
        ? layer!.copyWith(fontSize: value as double)
        : property == 'alignment'
          ? layer!.copyWith(alignment: value as TextAlignment)
          : layer!;

    // Find the track for this clip
    final state = context.read<TimelineBloc>().state;
    String? trackId;
    for (final track in state.project!.tracks) {
      if (track.clips.any((c) => c.id == layer!.id)) {
        trackId = track.id;
        break;
      }
    }

    if (trackId != null) {
      context.read<TimelineBloc>().add(UpdateClip(trackId: trackId, clip: updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Font Family',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _fonts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _onChipTap(context, 'fontFamily', _fonts[i]),
              child: _Chip(
                  label: _fonts[i], selected: layer?.fontFamily == _fonts[i]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Size',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
            children: _sizes
                .map((s) => Expanded(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => _onChipTap(context, 'fontSize', s),
                        child: _Chip(
                            label: s.toInt().toString(),
                            selected: layer?.fontSize == s,
                            compact: true),
                      ),
                    )))
                .toList()),
        const SizedBox(height: 16),
        const Text('Alignment',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: () => _onChipTap(context, 'alignment', TextAlignment.left),
            child: _Chip(label: 'Left', selected: layer?.alignment == TextAlignment.left),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _onChipTap(context, 'alignment', TextAlignment.center),
            child: _Chip(label: 'Center', selected: layer?.alignment == TextAlignment.center),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _onChipTap(context, 'alignment', TextAlignment.right),
            child: _Chip(label: 'Right', selected: layer?.alignment == TextAlignment.right),
          ),
        ]),
      ]),
    );
  }
}

class _StyleTab extends StatelessWidget {
  final TextLayer? layer;
  const _StyleTab({this.layer});

  void _onColorTap(BuildContext context, int color) {
    if (layer == null) return;
    final updated = layer!.copyWith(fill: TextFill(colors: [color]));

    final state = context.read<TimelineBloc>().state;
    String? trackId;
    for (final track in state.project!.tracks) {
      if (track.clips.any((c) => c.id == layer!.id)) {
        trackId = track.id;
        break;
      }
    }

    if (trackId != null) {
      context.read<TimelineBloc>().add(UpdateClip(trackId: trackId, clip: updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fill Color',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              0xFFFFFFFF,
              0xFF000000,
              0xFF7C6EF7,
              0xFF4ECDC4,
              0xFFF7C948,
              0xFFF76E6E,
              0xFF4ADE80,
              0xFF60A5FA,
            ]
                .map((c) => GestureDetector(
                      onTap: () => _onColorTap(context, c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: layer?.fill.colors.firstOrNull == c
                              ? Border.all(color: Colors.white, width: 2.5)
                              : Border.all(color: AppTheme.border),
                        ),
                      ),
                    ))
                .toList()),
        const SizedBox(height: 16),
        _SwitchRow(
            label: 'Drop Shadow',
            value: layer?.shadow.enabled ?? false,
            onChanged: (_) {}),
        _SwitchRow(
            label: 'Stroke / Outline',
            value: (layer?.stroke.width ?? 0) > 0,
            onChanged: (_) {}),
        _SwitchRow(
            label: 'Background Box',
            value: (layer?.backgroundOpacity ?? 0) > 0,
            onChanged: (_) {}),
        const SizedBox(height: 16),
        const Text('Gradient Fill',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.orange, Colors.red]),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
            ),
          ],
        ),
      ]),
    );
  }
}

class _EffectsTab extends StatelessWidget {
  final TextLayer? layer;
  const _EffectsTab({this.layer});

  static const _effects = [
    ('none', 'None', Icons.block),
    ('neon', 'Neon', Icons.lightbulb_outline),
    ('glow', 'Glow', Icons.wb_sunny_outlined),
    ('3d', '3D', Icons.layers_outlined),
    ('gradient', 'Gradient', Icons.gradient),
    ('outline', 'Thick Outline', Icons.radio_button_unchecked),
    ('shadow_long', 'Long Shadow', Icons.wb_twilight),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Text Effects',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: _effects.length,
          itemBuilder: (context, index) {
            final effect = _effects[index];
            final selected = false; // logic for selection
            return GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(effect.$3,
                        color:
                            selected ? AppTheme.accent : AppTheme.textSecondary,
                        size: 20),
                    const SizedBox(height: 4),
                    Text(effect.$2,
                        style: TextStyle(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                            fontSize: 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _AnimateTab extends StatelessWidget {
  final TextLayer? layer;
  const _AnimateTab({this.layer});

  static const _animsIn = [
    'None',
    'fadeIn',
    'slideLeft',
    'slideRight',
    'slideUp',
    'slideDown',
    'zoomIn',
    'bounceIn',
    'typewriter',
    'rotateIn'
  ];
  static const _animsOut = [
    'None',
    'fadeOut',
    'slideLeft',
    'slideRight',
    'zoomOut',
    'bounceOut'
  ];
  static const _animsLoop = [
    'None',
    'pulse',
    'wobble',
    'shake',
    'spin',
    'float'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Animate In',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _animsIn
                .map((a) =>
                    _Chip(label: a, selected: (layer?.animIn ?? 'None') == a))
                .toList()),
        const SizedBox(height: 16),
        const Text('Animate Out',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _animsOut
                .map((a) =>
                    _Chip(label: a, selected: (layer?.animOut ?? 'None') == a))
                .toList()),
        const SizedBox(height: 16),
        const Text('Loop Animation',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _animsLoop
                .map((a) =>
                    _Chip(label: a, selected: (layer?.animLoop ?? 'None') == a))
                .toList()),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  const _Chip(
      {required this.label, required this.selected, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}