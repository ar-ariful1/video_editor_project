import 'package:flutter/material.dart';
import '../editor_screen.dart';
import '../../../app_theme.dart';

class EditorToolbar extends StatelessWidget {
  final EditorPanel activePanel;
  final void Function(EditorPanel) onPanelTap;
  final VoidCallback onExport;

  const EditorToolbar({
    super.key,
    required this.activePanel,
    required this.onPanelTap,
    required this.onExport,
  });

  static const _tools = [
    (EditorPanel.media, Icons.folder_open_rounded, 'Media'),
    (EditorPanel.audio, Icons.audiotrack_rounded, 'Audio'),
    (EditorPanel.text, Icons.text_fields_rounded, 'Text'),
    (EditorPanel.pip, Icons.layers_rounded, 'Overlay'),
    (EditorPanel.effects, Icons.auto_awesome_rounded, 'Effects'),
    (EditorPanel.filters, Icons.filter_b_and_w_rounded, 'Filters'),
    (EditorPanel.adjust, Icons.tune_rounded, 'Adjust'),
    (EditorPanel.sticker, Icons.sticky_note_2_rounded, 'Stickers'),
    (EditorPanel.ai, Icons.psychology_rounded, 'AI Tools'),
    (EditorPanel.crop, Icons.crop_rotate_rounded, 'Ratio'),
    (EditorPanel.color, Icons.palette_rounded, 'Background'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: _tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (panel, icon, label) = _tools[i];
          final active = activePanel == panel;
          return GestureDetector(
            onTap: () => onPanelTap(panel),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 65,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: active ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(height: 5),
                    Text(label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontSize: 10,
                        )),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

