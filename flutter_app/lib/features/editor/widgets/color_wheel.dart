import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class ColorWheel extends StatefulWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorWheel({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late Offset _handlePos;
  final double _wheelSize = 100.0;

  @override
  void initState() {
    super.initState();
    _handlePos = const Offset(0, 0); // Center
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        GestureDetector(
          onPanUpdate: (details) {
            final center = Offset(_wheelSize / 2, _wheelSize / 2);
            final localPos = details.localPosition;
            final offset = localPos - center;

            // Limit within circle
            final distance = offset.distance;
            final maxDist = _wheelSize / 2;

            Offset finalOffset = offset;
            if (distance > maxDist) {
              finalOffset = Offset.fromDirection(offset.direction, maxDist);
            }

            setState(() {
              _handlePos = finalOffset;
            });

            // Calculate color based on position (Simplified for now)
            widget.onChanged(Colors.blue); // Placeholder
          },
          child: Container(
            width: _wheelSize,
            height: _wheelSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Colors.red,
                  Color(0xFFFF00FF), // Magenta
                  Colors.blue,
                  Colors.cyan,
                  Colors.green,
                  Colors.yellow,
                  Colors.red,
                ],
              ),
              border: Border.all(color: AppTheme.border, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Transform.translate(
                    offset: _handlePos,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)
                        ],
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
