// lib/features/editor/widgets/safe_zone_overlay.dart
// Social media safe zones — TikTok, Instagram Reels, YouTube Shorts
import 'package:flutter/material.dart';
import '../../../app_theme.dart';

enum SafeZoneType { none, tiktok, instagram, youtube, all }

class SafeZoneOverlay extends StatelessWidget {
  final SafeZoneType type;
  const SafeZoneOverlay({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == SafeZoneType.none) return const SizedBox.shrink();
    return CustomPaint(
        painter: _SafeZonePainter(type: type), size: Size.infinite);
  }
}

class _SafeZonePainter extends CustomPainter {
  final SafeZoneType type;
  const _SafeZonePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    switch (type) {
      case SafeZoneType.tiktok:
        _drawTikTokZones(canvas, size, dashedPaint, fillPaint);
        break;
      case SafeZoneType.instagram:
        _drawInstagramZones(canvas, size, dashedPaint, fillPaint);
        break;
      case SafeZoneType.youtube:
        _drawYouTubeZones(canvas, size, dashedPaint, fillPaint);
        break;
      case SafeZoneType.all:
        _drawTikTokZones(canvas, size, dashedPaint, fillPaint);
        _drawInstagramZones(canvas, size,
            dashedPaint..color = Colors.pink.withValues(alpha: 0.4), fillPaint);
        break;
      default:
        break;
    }

    _drawCenterGuides(canvas, size);
  }

  void _drawTikTokZones(Canvas canvas, Size size, Paint dashed, Paint fill) {
    // TikTok: bottom 20% UI area (comments/buttons), top 8% (header)
    final topH = size.height * 0.08;
    final bottomH = size.height * 0.22;
    final sideW = size.width * 0.20; // Right side buttons

    // Top safe zone
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, topH), fill);
    _drawDashedLine(canvas, Offset(0, topH), Offset(size.width, topH), dashed);
    _drawLabel(canvas, 'TikTok header', Offset(8, topH + 4));

    // Bottom safe zone
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH), fill);
    _drawDashedLine(canvas, Offset(0, size.height - bottomH),
        Offset(size.width, size.height - bottomH), dashed);
    _drawLabel(canvas, 'TikTok UI zone', Offset(8, size.height - bottomH + 4));

    // Right side buttons
    canvas.drawRect(
        Rect.fromLTWH(
            size.width - sideW, size.height * 0.3, sideW, size.height * 0.5),
        fill);
    _drawDashedLine(canvas, Offset(size.width - sideW, size.height * 0.3),
        Offset(size.width - sideW, size.height * 0.8), dashed);
    _drawLabel(
        canvas, 'Buttons', Offset(size.width - sideW + 4, size.height * 0.5));
  }

  void _drawInstagramZones(Canvas canvas, Size size, Paint dashed, Paint fill) {
    final topH = size.height * 0.10;
    final bottomH = size.height * 0.15;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, topH), fill);
    _drawDashedLine(canvas, Offset(0, topH), Offset(size.width, topH), dashed);
    _drawLabel(canvas, 'IG header', Offset(8, topH + 4));

    canvas.drawRect(
        Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH), fill);
    _drawDashedLine(canvas, Offset(0, size.height - bottomH),
        Offset(size.width, size.height - bottomH), dashed);
    _drawLabel(canvas, 'IG caption zone', Offset(8, size.height - bottomH + 4));
  }

  void _drawYouTubeZones(Canvas canvas, Size size, Paint dashed, Paint fill) {
    final topH = size.height * 0.08;
    final bottomH = size.height * 0.20;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, topH), fill);
    _drawDashedLine(canvas, Offset(0, topH), Offset(size.width, topH), dashed);
    _drawLabel(canvas, 'YT header', Offset(8, topH + 4));

    canvas.drawRect(
        Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH), fill);
    _drawDashedLine(canvas, Offset(0, size.height - bottomH),
        Offset(size.width, size.height - bottomH), dashed);
  }

  void _drawCenterGuides(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;
    // Rule of thirds
    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guidePaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 8.0, gapLen = 4.0;
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = (dx * dx + dy * dy);
    if (len == 0) return;
    final total = len / (dashLen + gapLen);
    final ux = dx / total, uy = dy / total;
    var x = p1.dx, y = p1.dy;
    for (int i = 0; i < total.toInt(); i++) {
      canvas.drawLine(
          Offset(x, y),
          Offset(x + ux * dashLen / (dashLen + gapLen),
              y + uy * dashLen / (dashLen + gapLen)),
          paint);
      x += ux;
      y += uy;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_SafeZonePainter old) => old.type != type;
}

// ── Safe zone toggle button ───────────────────────────────────────────────────
class SafeZoneToggle extends StatefulWidget {
  final void Function(SafeZoneType) onChanged;
  const SafeZoneToggle({super.key, required this.onChanged});
  @override
  State<SafeZoneToggle> createState() => _SafeZoneToggleState();
}

class _SafeZoneToggleState extends State<SafeZoneToggle> {
  SafeZoneType _current = SafeZoneType.none;

  @override
  Widget build(BuildContext context) {
    final options = [
      (SafeZoneType.none, '⬜', 'Off'),
      (SafeZoneType.tiktok, '🎵', 'TikTok'),
      (SafeZoneType.instagram, '📸', 'Instagram'),
      (SafeZoneType.youtube, '▶️', 'YouTube'),
    ];
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final sel = _current == o.$1;
          return GestureDetector(
            onTap: () {
              setState(() => _current = o.$1);
              widget.onChanged(o.$1);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: sel ? AppTheme.accent : AppTheme.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(o.$2, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(o.$3,
                    style: TextStyle(
                        color: sel ? AppTheme.accent : AppTheme.textTertiary,
                        fontSize: 10)),
              ]),
            ),
          );
        }).toList());
  }
}

