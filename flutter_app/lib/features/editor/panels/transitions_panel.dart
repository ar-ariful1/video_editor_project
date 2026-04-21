import 'package:flutter/material.dart' hide Clip, Transition;
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class TransitionsPanel extends StatefulWidget {
  final String trackId;
  final String clipId;
  final bool isIn;

  const TransitionsPanel({
    super.key,
    required this.trackId,
    required this.clipId,
    this.isIn = true,
  });

  @override
  State<TransitionsPanel> createState() => _TransitionsPanelState();
}

class _TransitionsPanelState extends State<TransitionsPanel> {
  int _selectedCategory = 0;
  final List<String> _categories = ['Basic', 'Camera', 'Glitch', 'Light'];

  static const List<Map<String, dynamic>> _transitions = [
    {'id': 'none', 'name': 'None', 'icon': Icons.block, 'type': 'none', 'cat': 0},
    {'id': 'fade', 'name': 'Fade', 'icon': Icons.blur_on, 'type': 'fade', 'cat': 0},
    {'id': 'dissolve', 'name': 'Dissolve', 'icon': Icons.grain, 'type': 'dissolve', 'cat': 0},
    {'id': 'zoom_in', 'name': 'Zoom In', 'icon': Icons.zoom_in, 'type': 'zoom', 'dir': 'in', 'cat': 1},
    {'id': 'zoom_out', 'name': 'Zoom Out', 'icon': Icons.zoom_out, 'type': 'zoom', 'dir': 'out', 'cat': 1},
    {'id': 'slide_left', 'name': 'Slide Left', 'icon': Icons.keyboard_arrow_left, 'type': 'slide', 'dir': 'left', 'cat': 1},
    {'id': 'glitch', 'name': 'Glitch', 'icon': Icons.flash_on, 'type': 'glitch', 'cat': 2},
    {'id': 'glitch_rgb', 'name': 'RGB Glitch', 'icon': Icons.vibration, 'type': 'glitch', 'cat': 2},
    {'id': 'burn', 'name': 'Light Burn', 'icon': Icons.wb_sunny_outlined, 'type': 'light', 'cat': 3},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTransitions = _transitions.where((t) => t['cat'] == _selectedCategory).toList();

    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isIn ? 'In Animation' : 'Out Animation',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
          
          // Category Tabs
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => setState(() => _selectedCategory = index),
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedCategory == index ? AppTheme.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: _selectedCategory == index ? AppTheme.accent : AppTheme.textTertiary,
                      fontWeight: _selectedCategory == index ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: filteredTransitions.length,
              itemBuilder: (context, index) {
                final t = filteredTransitions[index];
                return GestureDetector(
                  onTap: () {
                    context.read<TimelineBloc>().add(AddTransition(
                      trackId: widget.trackId,
                      clipId: widget.clipId,
                      transition: Transition(
                        type: t['type'],
                        direction: t['dir'],
                        duration: 0.5,
                      ),
                      isIn: widget.isIn,
                    ));
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.bg3,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Icon(t['icon'], color: Colors.white70, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t['name'],
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
