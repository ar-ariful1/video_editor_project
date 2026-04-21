// lib/features/editor/widgets/curves_editor_widget.dart
import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class CurvePoint {
  final double x, y; // 0.0 to 1.0
  const CurvePoint(this.x, this.y);
  CurvePoint copyWith({double? x, double? y}) =>
      CurvePoint(x ?? this.x, y ?? this.y);
}

class CurveChannel {
  final String name;
  final Color color;
  List<CurvePoint> points;
  CurveChannel({required this.name, required this.color, required this.points});

  static CurveChannel master() => CurveChannel(
      name: 'Master',
      color: Colors.white,
      points: [const CurvePoint(0, 0), const CurvePoint(1, 1)]);
  static CurveChannel red() => CurveChannel(
      name: 'Red',
      color: AppTheme.accent4,
      points: [const CurvePoint(0, 0), const CurvePoint(1, 1)]);
  static CurveChannel green() => CurveChannel(
      name: 'Green',
      color: AppTheme.green,
      points: [const CurvePoint(0, 0), const CurvePoint(1, 1)]);
  static CurveChannel blue() => CurveChannel(
      name: 'Blue',
      color: AppTheme.blue,
      points: [const CurvePoint(0, 0), const CurvePoint(1, 1)]);
}

class CurvesEditorWidget extends StatefulWidget {
  final void Function(Map<String, List<CurvePoint>> curves)? onChanged;
  const CurvesEditorWidget({super.key, this.onChanged});

  @override
  State<CurvesEditorWidget> createState() => _CurvesEditorWidgetState();
}

class _CurvesEditorWidgetState extends State<CurvesEditorWidget> {
  late List<CurveChannel> _channels;
  int _activeChannel = 0;
  int _draggingIdx = -1;

  @override
  void initState() {
    super.initState();
    _channels = [
      CurveChannel.master(),
      CurveChannel.red(),
      CurveChannel.green(),
      CurveChannel.blue()
    ];
  }

  CurveChannel get _active => _channels[_activeChannel];

  void _onPanStart(DragStartDetails d, Size size) {
    final pos = _toNorm(d.localPosition, size);
    // Find nearest point
    int nearest = -1;
    double minDist = 0.05;
    for (int i = 0; i < _active.points.length; i++) {
      final p = _active.points[i];
      final dist = (Offset(p.x, 1 - p.y) - pos).distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = i;
      }
    }
    if (nearest == -1) {
      // Add new point
      final pts = [
        ..._active.points,
        CurvePoint(pos.dx.clamp(0, 1), (1 - pos.dy).clamp(0, 1))
      ];
      pts.sort((a, b) => a.x.compareTo(b.x));
      setState(() {
        _active.points = pts;
        _draggingIdx =
            pts.indexWhere((p) => (p.x - pos.dx.clamp(0, 1)).abs() < 0.01);
      });
    } else {
      setState(() => _draggingIdx = nearest);
    }
    _notify();
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_draggingIdx < 0) return;
    final pos = _toNorm(d.localPosition, size);
    final pts = [..._active.points];
    // Clamp x so it doesn't cross neighbors
    double minX = _draggingIdx > 0 ? pts[_draggingIdx - 1].x + 0.02 : 0;
    double maxX =
        _draggingIdx < pts.length - 1 ? pts[_draggingIdx + 1].x - 0.02 : 1;
    pts[_draggingIdx] =
        CurvePoint(pos.dx.clamp(minX, maxX), (1 - pos.dy).clamp(0, 1));
    setState(() => _active.points = pts);
    _notify();
  }

  void _onPanEnd(DragEndDetails d) => setState(() => _draggingIdx = -1);

  Offset _toNorm(Offset local, Size size) =>
      Offset(local.dx / size.width, local.dy / size.height);

  void _notify() {
    widget.onChanged?.call({for (final ch in _channels) ch.name: ch.points});
  }

  void _reset() {
    setState(() =>
        _active.points = [const CurvePoint(0, 0), const CurvePoint(1, 1)]);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Channel tabs
      Row(children: [
        ..._channels.asMap().entries.map((e) => GestureDetector(
              onTap: () => setState(() => _activeChannel = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _activeChannel == e.key
                      ? e.value.color.withValues(alpha: 0.2)
                      : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _activeChannel == e.key
                          ? e.value.color
                          : AppTheme.border),
                ),
                child: Text(e.value.name,
                    style: TextStyle(
                        color: _activeChannel == e.key
                            ? e.value.color
                            : AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            )),
        const Spacer(),
        TextButton(
            onPressed: _reset,
            child: const Text('Reset',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11))),
      ]),
      const SizedBox(height: 10),

      // Curve canvas
      LayoutBuilder(builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxWidth);
        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: size,
            painter: _CurvePainter(
              points: _active.points,
              color: _active.color,
              draggingIdx: _draggingIdx,
            ),
          ),
        );
      }),
      const SizedBox(height: 6),
      const Text('Drag to adjust · Tap to add point · Double-tap to remove',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
          textAlign: TextAlign.center),
    ]);
  }
}

class _CurvePainter extends CustomPainter {
  final List<CurvePoint> points;
  final Color color;
  final int draggingIdx;

  const _CurvePainter(
      {required this.points, required this.color, required this.draggingIdx});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0A0A10));

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A38)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Diagonal reference
    canvas.drawLine(
        Offset.zero,
        Offset(size.width, size.height),
        Paint()
          ..color = const Color(0xFF3A3A48)
          ..strokeWidth = 0.5);

    // Curve via cubic spline
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(
          points.first.x * size.width, (1 - points.first.y) * size.height);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cpX = (p0.x + p1.x) / 2;
        path.cubicTo(
          cpX * size.width,
          (1 - p0.y) * size.height,
          cpX * size.width,
          (1 - p1.y) * size.height,
          p1.x * size.width,
          (1 - p1.y) * size.height,
        );
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    // Control points
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final px = p.x * size.width;
      final py = (1 - p.y) * size.height;
      final isDragging = i == draggingIdx;
      canvas.drawCircle(Offset(px, py), isDragging ? 7 : 5,
          Paint()..color = isDragging ? color : color.withValues(alpha: 0.8));
      canvas.drawCircle(
          Offset(px, py),
          isDragging ? 7 : 5,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.points != points || old.draggingIdx != draggingIdx;
}

