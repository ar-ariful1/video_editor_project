import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class CurvePoint {
  double x; // 0.0 to 1.0
  double y; // 0.0 to 1.0
  CurvePoint(this.x, this.y);
}

class CurvesWidget extends StatefulWidget {
  final Color channelColor;
  final List<CurvePoint> points;
  final ValueChanged<List<CurvePoint>> onChanged;

  const CurvesWidget({
    super.key,
    required this.channelColor,
    required this.points,
    required this.onChanged,
  });

  @override
  State<CurvesWidget> createState() => _CurvesWidgetState();
}

class _CurvesWidgetState extends State<CurvesWidget> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onPanUpdate: (details) {
            // Logic to move points or add new ones
          },
          child: CustomPaint(
            painter: _CurvesPainter(widget.points, widget.channelColor),
          ),
        ),
      ),
    );
  }
}

class _CurvesPainter extends CustomPainter {
  final List<CurvePoint> points;
  final Color color;

  _CurvesPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw grid
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), paint);
      canvas.drawLine(Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), paint);
    }

    // Draw Curve
    final curvePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].x * size.width, (1 - points[0].y) * size.height);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].x * size.width, (1 - points[i].y) * size.height);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Draw Points
    final dotPaint = Paint()..color = Colors.white;
    for (var pt in points) {
      canvas.drawCircle(Offset(pt.x * size.width, (1 - pt.y) * size.height), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
