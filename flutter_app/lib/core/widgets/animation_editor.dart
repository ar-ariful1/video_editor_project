// lib/core/widgets/animation_editor.dart
import 'package:flutter/material.dart';
import '../models/animation_keyframe.dart';

class AnimationEditor extends StatefulWidget {
  final KeyframeAnimation animation;
  final Function(KeyframeAnimation) onChanged;
  final Duration videoDuration;
  final Size? previewSize;

  const AnimationEditor({
    super.key,
    required this.animation,
    required this.onChanged,
    required this.videoDuration,
    this.previewSize,
  });

  @override
  State<AnimationEditor> createState() => _AnimationEditorState();
}

class _AnimationEditorState extends State<AnimationEditor>
    with SingleTickerProviderStateMixin {
  late KeyframeAnimation _animation;
  KeyframeType _selectedType = KeyframeType.position;
  double _currentTime = 0;
  AnimationKeyframe? _selectedKeyframe;
  late AnimationController _previewController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animation = widget.animation;
    _previewController = AnimationController(
      vsync: this,
      duration: widget.videoDuration,
    );
    _previewController.addListener(() {
      setState(() {
        _currentTime = _previewController.value;
      });
    });
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.animation, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Animation Editor',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                // Animation name
                SizedBox(
                  width: 150,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Animation Name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    controller: TextEditingController()..text = _animation.name,
                    onChanged: (value) {
                      setState(() {
                        _animation = _animation.copyWith(name: value);
                      });
                      widget.onChanged(_animation);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Loop toggle
                Row(
                  children: [
                    const Text('Loop'),
                    Switch(
                      value: _animation.isLooping,
                      onChanged: (value) {
                        setState(() {
                          _animation = _animation.copyWith(isLooping: value);
                        });
                        widget.onChanged(_animation);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Preview
          if (widget.previewSize != null)
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Center(
                child: Text(
                  'Preview Area\n${(_currentTime * widget.videoDuration.inSeconds).toStringAsFixed(1)}s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Type selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTypeButton(KeyframeType.position, Icons.open_with, 'Position'),
                _buildTypeButton(KeyframeType.scale, Icons.zoom_out_map, 'Scale'),
                _buildTypeButton(KeyframeType.rotation, Icons.rotate_right, 'Rotation'),
                _buildTypeButton(KeyframeType.opacity, Icons.opacity, 'Opacity'),
                _buildTypeButton(KeyframeType.skew, Icons.transform, 'Skew'),
                _buildTypeButton(KeyframeType.anchor, Icons.anchor, 'Anchor'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Timeline
          Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPosition = box.globalToLocal(details.globalPosition);
                  final time = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                  _previewController.value = time;
                  _checkKeyframeTap(time);
                }
              },
              child: CustomPaint(
                painter: KeyframePainter(
                  keyframes: _animation.getKeyframesByType(_selectedType),
                  currentTime: _currentTime,
                  duration: widget.videoDuration,
                ),
              ),
            ),
          ),
          
          // Time slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _formatTime(_currentTime * widget.videoDuration.inSeconds),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Expanded(
                  child: Slider(
                    value: _currentTime,
                    onChanged: (v) {
                      setState(() => _currentTime = v);
                      _previewController.value = v;
                    },
                  ),
                ),
                Text(
                  _formatTime(widget.videoDuration.inSeconds.toDouble()),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePreview,
                ),
              ],
            ),
          ),
          
          // Add keyframe button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _addKeyframe,
              icon: const Icon(Icons.add),
              label: const Text('Add Keyframe at Current Time'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
          
          // Keyframe editor
          if (_selectedKeyframe != null) ...[
            const SizedBox(height: 16),
            _buildKeyframeEditor(),
          ],
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTypeButton(KeyframeType type, IconData icon, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: label,
          child: ElevatedButton(
            onPressed: () => setState(() => _selectedType = type),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedType == type ? Colors.blue : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }

  void _togglePreview() {
    if (_isPlaying) {
      _previewController.stop();
    } else {
      _previewController.repeat();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _checkKeyframeTap(double time) {
    final frames = _animation.getKeyframesByType(_selectedType);
    for (final frame in frames) {
      if ((frame.time - time).abs() < 0.03) {
        setState(() => _selectedKeyframe = frame);
        break;
      }
    }
  }

  void _addKeyframe() {
    dynamic defaultValue;
    switch (_selectedType) {
      case KeyframeType.position:
        defaultValue = Offset.zero;
        break;
      case KeyframeType.anchor:
        defaultValue = Alignment.center;
        break;
      case KeyframeType.scale:
        defaultValue = 1.0;
        break;
      case KeyframeType.rotation:
      case KeyframeType.skew:
        defaultValue = 0.0;
        break;
      case KeyframeType.opacity:
        defaultValue = 1.0;
        break;
    }
    
    final newKeyframe = AnimationKeyframe.create(
      time: _currentTime,
      type: _selectedType,
      value: defaultValue,
    );
    
    setState(() {
      _animation = _animation.addKeyframe(newKeyframe);
      _selectedKeyframe = newKeyframe;
    });
    
    widget.onChanged(_animation);
  }

  Widget _buildKeyframeEditor() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Keyframe at ${(_selectedKeyframe!.time * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _selectedKeyframe!.interpolation.toString().split('.').last,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          const Divider(),
          
          // Time slider
          _buildSlider(
            'Time',
            _selectedKeyframe!.time,
            0.0, 1.0,
            (v) => _updateKeyframe(time: v),
          ),
          
          // Value editor based on type
          _buildValueEditor(),
          
          const SizedBox(height: 8),
          
          // Interpolation selector
          DropdownButtonFormField<InterpolationType>(
            value: _selectedKeyframe!.interpolation,
            decoration: const InputDecoration(
              labelText: 'Interpolation',
              border: OutlineInputBorder(),
            ),
            items: InterpolationType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.toString().split('.').last),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateKeyframe(interpolation: value);
              }
            },
          ),
          
          const SizedBox(height: 8),
          
          // Delete button
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _animation = _animation.removeKeyframe(_selectedKeyframe!.id);
                _selectedKeyframe = null;
              });
              widget.onChanged(_animation);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete Keyframe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueEditor() {
    final value = _selectedKeyframe!.value;
    
    switch (_selectedKeyframe!.type) {
      case KeyframeType.position:
        final offset = value as Offset;
        return Column(
          children: [
            _buildSlider('X', offset.dx, -1, 1, (v) => _updateKeyframe(value: Offset(v, offset.dy))),
            _buildSlider('Y', offset.dy, -1, 1, (v) => _updateKeyframe(value: Offset(offset.dx, v))),
          ],
        );
      case KeyframeType.anchor:
        final alignment = value as Alignment;
        return Column(
          children: [
            _buildSlider('X', alignment.x, -1, 1, (v) => _updateKeyframe(value: Alignment(v, alignment.y))),
            _buildSlider('Y', alignment.y, -1, 1, (v) => _updateKeyframe(value: Alignment(alignment.x, v))),
          ],
        );
      case KeyframeType.scale:
        return _buildSlider('Scale', (value as num).toDouble(), 0, 3, (v) => _updateKeyframe(value: v));
      case KeyframeType.rotation:
        return _buildSlider('Rotation (°)', (value as num).toDouble(), -180, 180, (v) => _updateKeyframe(value: v));
      case KeyframeType.skew:
        return _buildSlider('Skew', (value as num).toDouble(), -45, 45, (v) => _updateKeyframe(value: v));
      case KeyframeType.opacity:
        return _buildSlider('Opacity', (value as num).toDouble(), 0, 1, (v) => _updateKeyframe(value: v));
    }
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  void _updateKeyframe({
    double? time,
    dynamic value,
    InterpolationType? interpolation,
  }) {
    final updated = _selectedKeyframe!.copyWith(
      time: time,
      value: value,
      interpolation: interpolation,
    );
    
    setState(() {
      _animation = _animation.updateKeyframe(updated);
      _selectedKeyframe = updated;
    });
    
    widget.onChanged(_animation);
  }

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class KeyframePainter extends CustomPainter {
  final List<AnimationKeyframe> keyframes;
  final double currentTime;
  final Duration duration;

  KeyframePainter({
    required this.keyframes,
    required this.currentTime,
    required this.duration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.grey.shade800;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Draw timeline line
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 10; i++) {
      final x = size.width * (i / 10);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
    
    // Draw current time indicator
    final currentX = currentTime * size.width;
    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height.toDouble()),
      Paint()..color = Colors.red..strokeWidth = 2,
    );
    
    // Draw keyframes
    for (final keyframe in keyframes) {
      final x = keyframe.time * size.width;
      
      // Outer glow
      canvas.drawCircle(
        Offset(x, size.height / 2),
        12,
        Paint()..color = Colors.blue.withValues(alpha: 0.3),
      );
      
      // Inner circle
      canvas.drawCircle(
        Offset(x, size.height / 2),
        8,
        Paint()..color = Colors.blue..style = PaintingStyle.fill,
      );
      
      // Border
      canvas.drawCircle(
        Offset(x, size.height / 2),
        8,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}