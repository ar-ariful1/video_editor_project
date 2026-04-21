// lib/features/editor/widgets/aspect_ratio_switcher.dart
import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../core/models/video_project.dart';

class AspectRatioSwitcher extends StatelessWidget {
  final Resolution current;
  final void Function(Resolution) onChanged;

  const AspectRatioSwitcher(
      {super.key, required this.current, required this.onChanged});

  static const _presets = [
    (
      Resolution(width: 1080, height: 1920, frameRate: 30),
      '9:16',
      'Portrait',
      '📱'
    ),
    (
      Resolution(width: 1920, height: 1080, frameRate: 30),
      '16:9',
      'Landscape',
      '🖥️'
    ),
    (
      Resolution(width: 1080, height: 1080, frameRate: 30),
      '1:1',
      'Square',
      '⬜'
    ),
    (
      Resolution(width: 1080, height: 1350, frameRate: 30),
      '4:5',
      'Instagram',
      '📸'
    ),
    (
      Resolution(width: 720, height: 960, frameRate: 30),
      '3:4',
      'Portrait',
      '📷'
    ),
    (
      Resolution(width: 2560, height: 1080, frameRate: 30),
      '21:9',
      'Cinema',
      '🎬'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (res, ratio, label, icon) = _presets[i];
          final selected =
              current.width == res.width && current.height == res.height;
          return GestureDetector(
            onTap: () => onChanged(res),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color:
                    selected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected ? AppTheme.accent : AppTheme.border,
                    width: selected ? 1.5 : 1),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(ratio,
                        style: TextStyle(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 9)),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

