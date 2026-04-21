// lib/core/widgets/tutorial_tips.dart
// In-editor tutorial overlay — first-time user guide with spotlight + tooltip

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_theme.dart';

class TutorialTip {
  final String id, title, body;
  final AlignmentGeometry tooltipAlign;
  final Widget? target; // null = center screen

  const TutorialTip(
      {required this.id,
      required this.title,
      required this.body,
      this.tooltipAlign = Alignment.bottomCenter,
      this.target});
}

class TutorialManager {
  static const _editorTips = [
    TutorialTip(
        id: 'tl_import',
        title: 'Import Media',
        body: 'Tap + to add photos or videos to your project.'),
    TutorialTip(
        id: 'tl_tool',
        title: 'Choose a Tool',
        body: 'Tap any tool below to add text, effects, music and more.'),
    TutorialTip(
        id: 'tl_timeline',
        title: 'Timeline',
        body: 'Drag clips to reorder. Pinch to zoom in or out.'),
    TutorialTip(
        id: 'tl_trim',
        title: 'Trim a Clip',
        body: 'Tap a clip, then drag the yellow handles to trim.'),
    TutorialTip(
        id: 'tl_play',
        title: 'Preview Your Video',
        body: 'Tap the play button to preview your edit.'),
    TutorialTip(
        id: 'tl_undo',
        title: 'Undo / Redo',
        body: 'Made a mistake? Tap ↩ to undo or ↪ to redo.'),
    TutorialTip(
        id: 'tl_export',
        title: 'Export Your Video',
        body: 'Tap "Export" in the top-right when you\'re done.'),
  ];

  static Future<List<TutorialTip>> getPendingTips() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList('seen_tips') ?? [];
    return _editorTips.where((t) => !seen.contains(t.id)).toList();
  }

  static Future<void> markSeen(String tipId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList('seen_tips') ?? [];
    if (!seen.contains(tipId)) {
      seen.add(tipId);
      await prefs.setStringList('seen_tips', seen);
    }
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seen_tips');
  }
}

// ── Tutorial overlay widget ───────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  final Widget child;
  const TutorialOverlay({super.key, required this.child});
  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  List<TutorialTip> _pending = [];
  int _current = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tips = await TutorialManager.getPendingTips();
    if (tips.isNotEmpty && mounted) {
      setState(() {
        _pending = tips;
        _visible = true;
      });
    }
  }

  Future<void> _next() async {
    await TutorialManager.markSeen(_pending[_current].id);
    if (_current < _pending.length - 1) {
      setState(() => _current++);
    } else {
      setState(() => _visible = false);
    }
  }

  void _skipAll() async {
    for (final tip in _pending) await TutorialManager.markSeen(tip.id);
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_visible && _pending.isNotEmpty) ...[
        // Semi-transparent overlay
        Positioned.fill(
            child: GestureDetector(
          onTap: _next,
          child: Container(color: Colors.black.withValues(alpha: 0.65)),
        )),
        // Tooltip card
        Positioned(
          bottom: 160,
          left: 20,
          right: 20,
          child: _TipCard(
            tip: _pending[_current],
            current: _current + 1,
            total: _pending.length,
            onNext: _next,
            onSkip: _skipAll,
          ),
        ),
      ],
    ]);
  }
}

class _TipCard extends StatefulWidget {
  final TutorialTip tip;
  final int current, total;
  final VoidCallback onNext, onSkip;
  const _TipCard(
      {required this.tip,
      required this.current,
      required this.total,
      required this.onNext,
      required this.onSkip});
  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2)
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(widget.tip.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800))),
              Text('${widget.current}/${widget.total}',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Text(widget.tip.body,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            // Progress dots
            Row(children: [
              Row(
                  children: List.generate(
                      widget.total,
                      (i) => Container(
                            margin: const EdgeInsets.only(right: 5),
                            width: i == widget.current - 1 ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == widget.current - 1
                                  ? AppTheme.accent
                                  : AppTheme.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ))),
              const Spacer(),
              TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 13))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    minimumSize: const Size(80, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Text(widget.current < widget.total ? 'Next →' : 'Done ✓',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ]),
        ),
      ));
}

