// lib/features/editor/widgets/speed_curve_editor.dart
import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../core/models/advanced_features.dart';

class SpeedCurveEditor extends StatefulWidget {
  final List<SpeedPoint> points;
  final void Function(List<SpeedPoint>) onChanged;
  final double clipDuration;

  const SpeedCurveEditor(
      {super.key,
      required this.points,
      required this.onChanged,
      required this.clipDuration});

  @override
  State<SpeedCurveEditor> createState() => _SpeedCurveEditorState();
}

class _SpeedCurveEditorState extends State<SpeedCurveEditor> {
  late List<SpeedPoint> _points;
  int _dragging = -1;

  static const _minSpeed = 0.1;
  static const _maxSpeed = 8.0;
  static const _midSpeed = 1.0; // 1x = middle of canvas

  @override
  void initState() {
    super.initState();
    _points = widget.points.isEmpty
        ? [const SpeedPoint(time: 0, speed: 1.0), const SpeedPoint(time: 1, speed: 1.0)]
        : List.from(widget.points);
  }

  Offset _toCanvas(SpeedPoint p, Size size) => Offset(
        p.time * size.width,
        size.height -
            ((p.speed - _minSpeed) / (_maxSpeed - _minSpeed)) * size.height,
      );

  SpeedPoint _fromCanvas(Offset pos, Size size) => SpeedPoint(
        time: (pos.dx / size.width).clamp(0, 1),
        speed: (_minSpeed + (1 - pos.dy / size.height) * (_maxSpeed - _minSpeed))
            .clamp(_minSpeed, _maxSpeed),
      );

  void _onPanStart(DragStartDetails d, Size size) {
    final pos = d.localPosition;
    for (int i = 0; i < _points.length; i++) {
      final cp = _toCanvas(_points[i], size);
      if ((cp - pos).distance < 16) {
        _dragging = i;
        return;
      }
    }
    // Add new point
    final np = _fromCanvas(pos, size);
    final newPts = [..._points, np]..sort((a, b) => a.time.compareTo(b.time));
    setState(() {
      _points = newPts;
      _dragging = newPts.indexWhere((p) => (p.time - np.time).abs() < 0.01);
    });
    widget.onChanged(_points);
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_dragging < 0) return;
    var np = _fromCanvas(d.localPosition, size);
    // Clamp x between neighbors
    double minT = _dragging > 0 ? _points[_dragging - 1].time + 0.02 : 0;
    double maxT =
        _dragging < _points.length - 1 ? _points[_dragging + 1].time - 0.02 : 1;
    np = SpeedPoint(time: np.time.clamp(minT, maxT), speed: np.speed);
    setState(() => _points[_dragging] = np);
    widget.onChanged(_points);
  }

  void _reset() {
    setState(
        () => _points = [const SpeedPoint(time: 0, speed: 1.0), const SpeedPoint(time: 1, speed: 1.0)]);
    widget.onChanged(_points);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child: Text('Speed Curve',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))),
        TextButton(
            onPressed: _reset,
            child: const Text('Reset',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11))),
      ]),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (_, constraints) {
        final size = Size(constraints.maxWidth, 160);
        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: (_) => _dragging = -1,
          child: CustomPaint(
              size: size,
              painter:
                  _SpeedCurvePainter(points: _points, dragging: _dragging)),
        );
      }),
      const SizedBox(height: 6),
      // Speed labels for current points
      Wrap(
          spacing: 8,
          children: _points
              .map((p) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppTheme.bg3,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                        '${(p.time * widget.clipDuration).toStringAsFixed(1)}s → ${p.speed.toStringAsFixed(1)}x',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 10)),
                  ))
              .toList()),
    ]);
  }
}

class _SpeedCurvePainter extends CustomPainter {
  final List<SpeedPoint> points;
  final int dragging;
  const _SpeedCurvePainter({required this.points, required this.dragging});

  static const _min = 0.1, _max = 8.0;

  Offset _pos(SpeedPoint p, Size s) => Offset(p.time * s.width,
      s.height - ((p.speed - _min) / (_max - _min)) * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0A0A10));

    // Grid
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    final midY = size.height - ((1.0 - _min) / (_max - _min)) * size.height;

    for (int i = 1; i < 4; i++)
      canvas.drawLine(Offset(size.width * i / 4, 0),
          Offset(size.width * i / 4, size.height), grid);
    canvas.drawLine(
        Offset(0, midY),
        Offset(size.width, midY),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 1
          ..strokeDash([4, 4]));

    // Labels
    void lbl(String t, Offset o) {
      final tp = TextPainter(
          text: TextSpan(
              text: t,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o);
    }

    lbl('8x', Offset(2, 2));
    lbl('1x', Offset(2, midY - 10));
    lbl('0.1x', Offset(2, size.height - 12));

    if (points.length < 2) return;

    // Curve
    final path = Path();
    path.moveTo(_pos(points.first, size).dx, _pos(points.first, size).dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = _pos(points[i], size);
      final p1 = _pos(points[i + 1], size);
      final cpX = (p0.dx + p1.dx) / 2;
      path.cubicTo(cpX, p0.dy, cpX, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.accent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Fill under curve
    final fill = Path.from(path);
    fill.lineTo(_pos(points.last, size).dx, size.height);
    fill.lineTo(0, size.height);
    fill.close();
    canvas.drawPath(
        fill,
        Paint()
          ..color = AppTheme.accent.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill);

    // Control points
    for (int i = 0; i < points.length; i++) {
      final p = _pos(points[i], size);
      final active = dragging == i;
      canvas.drawCircle(
          p,
          active ? 8 : 6,
          Paint()
            ..color =
                active ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.8));
      canvas.drawCircle(
          p,
          active ? 8 : 6,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_SpeedCurvePainter old) =>
      old.points != points || old.dragging != dragging;
}

extension on Paint {
  // ignore: unused_element
  void strokeDash(List<double> d) {}
}

