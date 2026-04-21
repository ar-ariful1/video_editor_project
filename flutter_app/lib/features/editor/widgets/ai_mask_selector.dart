// lib/features/editor/widgets/ai_mask_selector.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../core/models/video_project.dart';

class AIMaskSelector extends StatefulWidget {
  final File imageFile;
  final Resolution resolution;
  final Function(List<Offset> points, List<Rect> boxes) onConfirmed;
  final VoidCallback onCancel;

  const AIMaskSelector({
    super.key,
    required this.imageFile,
    required this.resolution,
    required this.onConfirmed,
    required this.onCancel,
  });

  @override
  State<AIMaskSelector> createState() => _AIMaskSelectorState();
}

class _AIMaskSelectorState extends State<AIMaskSelector> {
  final List<Offset> _points = [];
  final List<Rect> _boxes = [];
  Rect? _currentBox;
  Offset? _boxStart;

  bool _isBoxMode = false;

  void _handleTap(TapDownDetails details, Size size) {
    if (_isBoxMode) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      _points.add(Offset(
        localPosition.dx / size.width,
        localPosition.dy / size.height,
      ));
    });
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    if (!_isBoxMode) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    _boxStart = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentBox = Rect.fromPoints(_boxStart!, _boxStart!);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (!_isBoxMode || _boxStart == null) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final currentPos = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentBox = Rect.fromPoints(_boxStart!, currentPos);
    });
  }

  void _handlePanEnd(DragEndDetails details, Size size) {
    if (!_isBoxMode || _currentBox == null) return;

    setState(() {
      _boxes.add(Rect.fromLTRB(
        _currentBox!.left / size.width,
        _currentBox!.top / size.height,
        _currentBox!.right / size.width,
        _currentBox!.bottom / size.height,
      ));
      _currentBox = null;
      _boxStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onCancel,
                  ),
                  const Expanded(
                    child: Text(
                      'Select Object to Remove',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onConfirmed(_points, _boxes),
                    child: const Text('REMOVE', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  final aspect = widget.resolution.aspectRatio;

                  double drawW, drawH;
                  if (size.width / size.height > aspect) {
                    drawH = size.height;
                    drawW = drawH * aspect;
                  } else {
                    drawW = size.width;
                    drawH = drawW / aspect;
                  }

                  return Center(
                    child: Container(
                      width: drawW,
                      height: drawH,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                      ),
                      child: GestureDetector(
                        onTapDown: (d) => _handleTap(d, Size(drawW, drawH)),
                        onPanStart: (d) => _handlePanStart(d, Size(drawW, drawH)),
                        onPanUpdate: (d) => _handlePanUpdate(d, Size(drawW, drawH)),
                        onPanEnd: (d) => _handlePanEnd(d, Size(drawW, drawH)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(widget.imageFile, fit: BoxFit.fill),
                            CustomPaint(
                              painter: _SelectionPainter(
                                points: _points,
                                boxes: _boxes,
                                currentBox: _currentBox,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Toolbar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.bg2,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ToolButton(
                        icon: Icons.touch_app,
                        label: 'Points',
                        isSelected: !_isBoxMode,
                        onTap: () => setState(() => _isBoxMode = false),
                      ),
                      const SizedBox(width: 20),
                      _ToolButton(
                        icon: Icons.crop_square,
                        label: 'Box',
                        isSelected: _isBoxMode,
                        onTap: () => setState(() => _isBoxMode = true),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            if (_isBoxMode && _boxes.isNotEmpty) {
                              _boxes.removeLast();
                            } else if (!_isBoxMode && _points.isNotEmpty) {
                              _points.removeLast();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _points.clear();
                            _boxes.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to add points or drag to draw boxes around the object.',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: isSelected ? AppTheme.accent : Colors.white54),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? AppTheme.accent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final List<Offset> points;
  final List<Rect> boxes;
  final Rect? currentBox;

  _SelectionPainter({required this.points, required this.boxes, this.currentBox});

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final boxPaint = Paint()
      ..color = AppTheme.accent.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final boxBorderPaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var p in points) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 4, pointPaint);
    }

    for (var b in boxes) {
      final rect = Rect.fromLTWH(
        b.left * size.width,
        b.top * size.height,
        b.width * size.width,
        b.height * size.height,
      );
      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, boxBorderPaint);
    }

    if (currentBox != null) {
      canvas.drawRect(currentBox!, boxPaint);
      canvas.drawRect(currentBox!, boxBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
