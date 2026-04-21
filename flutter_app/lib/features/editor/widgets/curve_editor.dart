import 'dart:ui' as ui show Clip;
import 'package:flutter/material.dart' hide Clip;
import '../../../core/models/video_project.dart';

class CurveEditor extends StatefulWidget {
  final List<double> bezierHandles; // [p1x, p1y, p2x, p2y]
  final ValueChanged<List<double>> onChanged;

  const CurveEditor({
    super.key,
    required this.bezierHandles,
    required this.onChanged,
  });

  @override
  State<CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<CurveEditor> {
  late Offset cp1;
  late Offset cp2;

  @override
  void initState() {
    super.initState();
    cp1 = Offset(widget.bezierHandles[0], widget.bezierHandles[1]);
    cp2 = Offset(widget.bezierHandles[2], widget.bezierHandles[3]);
  }

  @override
  void didUpdateWidget(CurveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update internal state if handles changed externally and we're not middle of a gesture
    // For simplicity, we just check if they are different.
    if (widget.bezierHandles[0] != cp1.dx ||
        widget.bezierHandles[1] != cp1.dy ||
        widget.bezierHandles[2] != cp2.dx ||
        widget.bezierHandles[3] != cp2.dy) {
      setState(() {
        cp1 = Offset(widget.bezierHandles[0], widget.bezierHandles[1]);
        cp2 = Offset(widget.bezierHandles[2], widget.bezierHandles[3]);
      });
    }
  }

  void _updatePoint(int index, Offset delta, Size size) {
    setState(() {
      if (index == 1) {
        cp1 = Offset(
          (cp1.dx + delta.dx / size.width).clamp(0.0, 1.0),
          (cp1.dy - delta.dy / size.height).clamp(0.0, 1.0),
        );
      } else {
        cp2 = Offset(
          (cp2.dx + delta.dx / size.width).clamp(0.0, 1.0),
          (cp2.dy - delta.dy / size.height).clamp(0.0, 1.0),
        );
      }
      widget.onChanged([cp1.dx, cp1.dy, cp2.dx, cp2.dy]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cubic Bezier Easing',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('(${cp1.dx.toStringAsFixed(2)}, ${cp1.dy.toStringAsFixed(2)}) - (${cp2.dx.toStringAsFixed(2)}, ${cp2.dy.toStringAsFixed(2)})',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  clipBehavior: ui.Clip.none,
                  children: [
                    // Grid lines
                    CustomPaint(
                      size: size,
                      painter: _GridPainter(),
                    ),
                    // The Curve
                    CustomPaint(
                      size: size,
                      painter: _CurvePainter(cp1: cp1, cp2: cp2),
                    ),
                    // Handle 1
                    Positioned(
                      left: cp1.dx * size.width - 15,
                      top: (1 - cp1.dy) * size.height - 15,
                      child: GestureDetector(
                        onPanUpdate: (d) => _updatePoint(1, d.delta, size),
                        child: _buildHandle(Colors.blueAccent),
                      ),
                    ),
                    // Handle 2
                    Positioned(
                      left: cp2.dx * size.width - 15,
                      top: (1 - cp2.dy) * size.height - 15,
                      child: GestureDetector(
                        onPanUpdate: (d) => _updatePoint(2, d.delta, size),
                        child: _buildHandle(Colors.purpleAccent),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _preset('Linear', [0.0, 0.0, 1.0, 1.0]),
                _preset('Ease In', [0.42, 0.0, 1.0, 1.0]),
                _preset('Ease Out', [0.0, 0.0, 0.58, 1.0]),
                _preset('Ease In Out', [0.42, 0.0, 0.58, 1.0]),
                _preset('Fast Start', [0.1, 0.9, 0.2, 1.0]),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHandle(Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _preset(String name, List<double> values) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(name, style: const TextStyle(fontSize: 11)),
        backgroundColor: Colors.white.withOpacity(0.05),
        side: BorderSide.none,
        onPressed: () {
          setState(() {
            cp1 = Offset(values[0], values[1]);
            cp2 = Offset(values[2], values[3]);
          });
          widget.onChanged(values);
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), paint);
      canvas.drawLine(Offset(size.width * i / 4, 0), Offset(size.width * i / 4, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _CurvePainter extends CustomPainter {
  final Offset cp1, cp2;
  _CurvePainter({required this.cp1, required this.cp2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    path.moveTo(0, size.height);
    path.cubicTo(
      cp1.dx * size.width, (1 - cp1.dy) * size.height,
      cp2.dx * size.width, (1 - cp2.dy) * size.height,
      size.width, 0,
    );

    // Draw shadow path
    canvas.drawPath(path, paint);

    // Draw guide lines
    final guidePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height), Offset(cp1.dx * size.width, (1 - cp1.dy) * size.height), guidePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(cp2.dx * size.width, (1 - cp2.dy) * size.height), guidePaint);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => cp1 != old.cp1 || cp2 != old.cp2;
}
