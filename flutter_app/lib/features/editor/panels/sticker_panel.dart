// lib/features/editor/panels/sticker_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';

class StickerPanel extends StatefulWidget {
  const StickerPanel({super.key});
  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';

  static const _categories = [
    'Trending',
    'Vlog',
    'Retro',
    '3D',
    'Nature',
    'Arrows',
    'Social'
  ];

  // Professional placeholders for stickers (Real app would fetch SVGs/PNGs from CMS)
  static const _stickers = [
    Icons.play_circle_outline_rounded,
    Icons.favorite_border_rounded,
    Icons.auto_awesome_rounded,
    Icons.bolt_rounded,
    Icons.stars_rounded,
    Icons.celebration_rounded,
    Icons.diamond_rounded,
    Icons.verified_user_rounded,
    Icons.location_on_rounded,
    Icons.videocam_rounded,
    Icons.audiotrack_rounded,
    Icons.camera_alt_rounded,
    Icons.brush_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.rocket_launch_rounded,
    Icons.flight_takeoff_rounded,
    Icons.emoji_events_rounded,
    Icons.mic_none_rounded,
    Icons.theaters_rounded,
    Icons.festival_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<IconData> get _currentItems {
    return _stickers; // Simplified for MVP professional look
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.all(10),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search professional stickers…',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search,
                color: AppTheme.textTertiary, size: 18),
            filled: true,
            fillColor: AppTheme.bg3,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border)),
          ),
        ),
      ),

      // Category tabs
      TabBar(
        controller: _tabs,
        isScrollable: true,
        labelColor: AppTheme.accent,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.accent,
        tabs: _categories.map((c) => Tab(text: c)).toList(),
        onTap: (_) => setState(() {}),
      ),

      // Sticker grid
      Expanded(
        child: BlocBuilder<TimelineBloc, TimelineState>(
          builder: (ctx, state) => GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _currentItems.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _addSticker(ctx, state, _currentItems[i]),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(
                    child: Icon(_currentItems[i],
                        color: Colors.white, size: 32)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  void _addSticker(BuildContext ctx, TimelineState state, IconData icon) {
    final currentTime = state.currentTime;
    // For MVP, we use the icon's code point or a name
    final stickerLayer = TextLayer.create(
      startTime: currentTime,
      endTime: currentTime + 3.0,
      text: String.fromCharCode(icon.codePoint),
    );
    // ...
    // Add to sticker track
    final stickerTrack = state.project?.tracks.firstWhere(
      (t) => t.type == TrackType.sticker,
      orElse: () =>
          Track.create(name: 'Stickers', type: TrackType.sticker, zIndex: 9),
    );
    if (stickerTrack != null) {
      ctx
          .read<TimelineBloc>()
          .add(AddClip(trackId: stickerTrack.id, clip: stickerLayer));
    }
  }
}
