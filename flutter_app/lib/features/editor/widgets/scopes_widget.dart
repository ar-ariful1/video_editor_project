// lib/features/editor/widgets/scopes_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app_theme.dart';

enum ScopeType { histogram, waveform, vectorscope, parade }

class ScopesWidget extends StatefulWidget {
  final ScopeType type;
  final List<int>? rgbData; // raw pixel RGBA data for analysis
  const ScopesWidget(
      {super.key, this.type = ScopeType.histogram, this.rgbData});
  @override
  State<ScopesWidget> createState() => _ScopesWidgetState();
}

class _ScopesWidgetState extends State<ScopesWidget> {
  ScopeType _type = ScopeType.histogram;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Scope type selector
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          ...ScopeType.values.map((t) => GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _type == t
                        ? AppTheme.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _type == t ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Text(_scopeLabel(t),
                      style: TextStyle(
                          color: _type == t
                              ? AppTheme.accent
                              : AppTheme.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              )),
        ]),
      ),

      // Scope canvas
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CustomPaint(
            painter: _ScopePainter(type: _type, rgbData: widget.rgbData),
            size: Size.infinite,
          ),
        ),
      ),
    ]);
  }

  String _scopeLabel(ScopeType t) {
    switch (t) {
      case ScopeType.histogram:
        return 'Histogram';
      case ScopeType.waveform:
        return 'Waveform';
      case ScopeType.vectorscope:
        return 'Vectorscope';
      case ScopeType.parade:
        return 'Parade';
    }
  }
}

class _ScopePainter extends CustomPainter {
  final ScopeType type;
  final List<int>? rgbData;
  const _ScopePainter({required this.type, this.rgbData});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF060608));
    switch (type) {
      case ScopeType.histogram:
        _paintHistogram(canvas, size);
      case ScopeType.waveform:
        _paintWaveform(canvas, size);
      case ScopeType.vectorscope:
        _paintVectorscope(canvas, size);
      case ScopeType.parade:
        _paintParade(canvas, size);
    }
  }

  void _paintHistogram(Canvas canvas, Size size) {
    // Grid
    _paintGrid(canvas, size);

    // Generate mock histogram (replaced by real pixel analysis)
    final colors = [Colors.red, Colors.green, Colors.blue];
    for (int ch = 0; ch < 3; ch++) {
      final path = Path();
      path.moveTo(0, size.height);
      for (int x = 0; x < 256; x++) {
        final px = x * size.width / 256;
        // Gaussian bell curve simulation centered at ~128
        final center = 100.0 + ch * 30.0;
        final sigma = 40.0 + ch * 10.0;
        final val = math.exp(-math.pow(x - center, 2) / (2 * sigma * sigma));
        final py = size.height - (val * size.height * 0.85);
        if (x == 0)
          path.moveTo(px, py);
        else
          path.lineTo(px, py);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[ch].withValues(alpha: 0.3)
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[ch]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    // Labels
    _label(canvas, '0', Offset(2, size.height - 10), Colors.white38);
    _label(canvas, '128', Offset(size.width / 2 - 10, size.height - 10),
        Colors.white38);
    _label(canvas, '255', Offset(size.width - 22, size.height - 10),
        Colors.white38);
  }

  void _paintWaveform(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    // IRE grid lines
    for (final pct in [0, 20, 40, 60, 80, 100]) {
      final y = size.height - (pct / 100) * size.height;
      canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..color = Colors.white12
            ..strokeWidth = 0.5);
      _label(canvas, '$pct', Offset(2, y - 8), Colors.white38);
    }
    // Simulated luma waveform
    final paint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final rng = math.Random(42);
    for (int x = 0; x < size.width.toInt(); x++) {
      final base = 0.5 + math.sin(x / 40) * 0.2;
      final noise = rng.nextDouble() * 0.2 - 0.1;
      final luma = (base + noise).clamp(0.0, 1.0);
      final y = size.height - luma * size.height;
      canvas.drawCircle(Offset(x.toDouble(), y), 0.8,
          paint..color = const Color(0xFF00FF88).withValues(alpha: 0.4 + luma * 0.4));
    }
  }

  void _paintVectorscope(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 10;

    // Background circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
          Offset(cx, cy),
          r * i / 4,
          Paint()
            ..color = Colors.white10
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }

    // Axes
    for (final angle in [0, 60, 120, 180, 240, 300]) {
      final rad = angle * math.pi / 180;
      canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + r * math.cos(rad), cy + r * math.sin(rad)),
          Paint()
            ..color = Colors.white12
            ..strokeWidth = 0.5);
    }

    // Color targets
    final targets = [
      (0.0, 'R', Colors.red),
      (60.0, 'Yel', Colors.yellow),
      (120.0, 'G', Colors.green),
      (180.0, 'Cy', Colors.cyan),
      (240.0, 'B', Colors.blue),
      (300.0, 'Mg', Colors.purple),
    ];
    for (final t in targets) {
      final rad = t.$1 * math.pi / 180;
      final tx = cx + r * 0.85 * math.cos(rad);
      final ty = cy + r * 0.85 * math.sin(rad);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(tx, ty), width: 6, height: 6),
          Paint()
            ..color = t.$3
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _label(canvas, t.$2, Offset(tx - 8, ty - 6), t.$3.withValues(alpha: 0.8));
    }

    // Plot simulated pixel cloud
    final rng = math.Random(42);
    final dotPaint = Paint()
      ..color = const Color(0xFF88FF88).withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 300; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = rng.nextDouble() * r * 0.4;
      canvas.drawCircle(
          Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
          1.2,
          dotPaint);
    }
  }

  void _paintParade(Canvas canvas, Size size) {
    final w = size.width / 3;
    final colors = [Colors.red, Colors.green, Colors.blue];
    final labels = ['R', 'G', 'B'];
    final offsets = [100.0, 128.0, 110.0];

    for (int ch = 0; ch < 3; ch++) {
      final x0 = ch * w;
      final rng = math.Random(ch + 1);
      final path = Path();
      for (int x = 0; x < w.toInt(); x++) {
        final base = offsets[ch] / 255;
        final noise = rng.nextDouble() * 0.3 - 0.15;
        final luma = (base + noise + math.sin(x / 20) * 0.1).clamp(0.0, 1.0);
        final py = size.height - luma * size.height;
        if (x == 0)
          path.moveTo(x0 + x, py);
        else
          path.lineTo(x0 + x, py);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[ch]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      _label(canvas, labels[ch], Offset(x0 + w / 2 - 5, size.height - 12),
          colors[ch]);
    }
    _paintGrid(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(size.width * i / 4, 0),
          Offset(size.width * i / 4, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), p);
    }
  }

  void _label(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_ScopePainter old) => old.type != type;
}

