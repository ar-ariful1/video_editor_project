// lib/features/editor/timeline/trim_slider.dart
import 'package:flutter/material.dart';

/// A widget that allows trimming video start and end times.
class TrimSlider extends StatefulWidget {
  final double totalDuration; // in seconds
  final double initialStart; // in seconds
  final double initialEnd; // in seconds
  final ValueChanged<TrimRange>? onChanged;
  final ValueChanged<TrimRange>? onChangeEnd;
  final Color activeColor;
  final Color inactiveColor;
  final Color handleColor;
  final double handleWidth;
  final double barHeight;

  const TrimSlider({
    super.key,
    required this.totalDuration,
    this.initialStart = 0.0,
    this.initialEnd = 0.0,
    this.onChanged,
    this.onChangeEnd,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.handleColor = Colors.white,
    this.handleWidth = 8.0,
    this.barHeight = 48.0,
  });

  @override
  State<TrimSlider> createState() => _TrimSliderState();
}

class TrimRange {
  final double start;
  final double end;
  const TrimRange({required this.start, required this.end});
}

class _TrimSliderState extends State<TrimSlider> {
  late double _start;
  late double _end;
  double _dragStart = 0.0;
  bool _draggingLeft = false;
  bool _draggingRight = false;
  bool _draggingCenter = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart.clamp(0.0, widget.totalDuration);
    _end = widget.initialEnd > 0
        ? widget.initialEnd.clamp(_start, widget.totalDuration)
        : widget.totalDuration;
  }

  @override
  void didUpdateWidget(TrimSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStart != widget.initialStart ||
        oldWidget.initialEnd != widget.initialEnd) {
      setState(() {
        _start = widget.initialStart.clamp(0.0, widget.totalDuration);
        _end = widget.initialEnd > 0
            ? widget.initialEnd.clamp(_start, widget.totalDuration)
            : widget.totalDuration;
      });
    }
  }

  void _notifyChanged({bool isEnd = false}) {
    widget.onChanged?.call(TrimRange(start: _start, end: _end));
    if (isEnd) {
      widget.onChangeEnd?.call(TrimRange(start: _start, end: _end));
    }
  }

  void _handlePanStart(DragStartDetails details, TrimHandle handle) {
    final localX = _getLocalX(details.localPosition);
    _dragStart = _pixelToTime(localX);
    setState(() {
      _draggingLeft = handle == TrimHandle.left;
      _draggingRight = handle == TrimHandle.right;
      _draggingCenter = handle == TrimHandle.center;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final localX = _getLocalX(details.localPosition);
    final currentTime = _pixelToTime(localX);
    final delta = currentTime - _dragStart;
    _dragStart = currentTime;

    setState(() {
      if (_draggingLeft) {
        final newStart = (_start + delta).clamp(0.0, _end - 0.1);
        _start = newStart;
      } else if (_draggingRight) {
        final newEnd = (_end + delta).clamp(_start + 0.1, widget.totalDuration);
        _end = newEnd;
      } else if (_draggingCenter) {
        final range = _end - _start;
        final newStart = (_start + delta).clamp(0.0, widget.totalDuration - range);
        _start = newStart;
        _end = newStart + range;
      }
    });
    _notifyChanged();
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _draggingLeft = false;
      _draggingRight = false;
      _draggingCenter = false;
    });
    _notifyChanged(isEnd: true);
  }

  double _getLocalX(Offset globalPosition) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    return box.globalToLocal(globalPosition).dx;
  }

  double _pixelToTime(double pixelX) {
    final width = context.size?.width ?? 1.0;
    return (pixelX / width) * widget.totalDuration;
  }

  double _timeToPixel(double time) {
    final width = context.size?.width ?? 1.0;
    return (time / widget.totalDuration) * width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final leftPos = _timeToPixel(_start);
        final rightPos = _timeToPixel(_end);
        final activeWidth = rightPos - leftPos;

        return SizedBox(
          height: widget.barHeight,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // Inactive background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      color: widget.inactiveColor,
                      totalDuration: widget.totalDuration,
                    ),
                  ),
                ),
                // Active (selected) region
                Positioned(
                  left: leftPos,
                  width: activeWidth,
                  top: 0,
                  bottom: 0,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      color: widget.activeColor,
                      totalDuration: widget.totalDuration,
                    ),
                  ),
                ),
                // Left handle
                Positioned(
                  left: leftPos - widget.handleWidth / 2,
                  child: GestureDetector(
                    onHorizontalDragStart: (d) => _handlePanStart(d, TrimHandle.left),
                    onHorizontalDragUpdate: _handlePanUpdate,
                    onHorizontalDragEnd: _handlePanEnd,
                    child: Container(
                      width: widget.handleWidth,
                      height: widget.barHeight,
                      decoration: BoxDecoration(
                        color: widget.handleColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.chevron_left, size: 16, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
                // Right handle
                Positioned(
                  left: rightPos - widget.handleWidth / 2,
                  child: GestureDetector(
                    onHorizontalDragStart: (d) => _handlePanStart(d, TrimHandle.right),
                    onHorizontalDragUpdate: _handlePanUpdate,
                    onHorizontalDragEnd: _handlePanEnd,
                    child: Container(
                      width: widget.handleWidth,
                      height: widget.barHeight,
                      decoration: BoxDecoration(
                        color: widget.handleColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.chevron_right, size: 16, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
                // Center drag area (for moving the entire selection)
                Positioned(
                  left: leftPos,
                  width: activeWidth,
                  child: GestureDetector(
                    onHorizontalDragStart: (d) => _handlePanStart(d, TrimHandle.center),
                    onHorizontalDragUpdate: _handlePanUpdate,
                    onHorizontalDragEnd: _handlePanEnd,
                    child: Container(
                      height: widget.barHeight,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum TrimHandle { left, right, center }

/// Simple waveform painter (you can replace with actual waveform generation)
class _WaveformPainter extends CustomPainter {
  final Color color;
  final double totalDuration;

  _WaveformPainter({required this.color, required this.totalDuration});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final step = size.width / 100;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.4;

    for (var i = 0; i < 100; i++) {
      final x = i * step;
      // Generate a pseudo-waveform pattern
      final norm = (i / 100) * 10;
      final amp = (norm.sin() * 0.5 + 0.5) * maxAmp;
      canvas.drawLine(
        Offset(x, midY - amp / 2),
        Offset(x, midY + amp / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}