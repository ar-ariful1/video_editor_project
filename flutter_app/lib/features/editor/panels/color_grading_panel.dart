import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import '../../../app_theme.dart';
import '../widgets/color_wheel.dart' as widgets;
import '../widgets/curves_widget.dart';

class ColorGradingPanel extends StatefulWidget {
  const ColorGradingPanel({super.key});

  @override
  State<ColorGradingPanel> createState() => _ColorGradingPanelState();
}

class _ColorGradingPanelState extends State<ColorGradingPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Adjust'),
            Tab(text: 'Wheels'),
            Tab(text: 'Curves'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicAdjustments(),
              _buildColorWheels(),
              _buildColorCurves(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicAdjustments() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _adjustmentSlider('Exposure', -1.0, 1.0, 0.0),
        _adjustmentSlider('Contrast', 0.5, 1.5, 1.0),
        _adjustmentSlider('Saturation', 0.0, 2.0, 1.0),
        _adjustmentSlider('Vibrance', 0.0, 2.0, 1.0),
        _adjustmentSlider('Temperature', -100.0, 100.0, 0.0),
        _adjustmentSlider('Tint', -100.0, 100.0, 0.0),
      ],
    );
  }

  Widget _adjustmentSlider(String label, double min, double max, double defaultValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text(defaultValue.toStringAsFixed(2), style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
          ],
        ),
        Slider(
          value: defaultValue,
          min: min,
          max: max,
          onChanged: (v) {},
        ),
      ],
    );
  }

  Widget _buildColorWheels() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          widgets.ColorWheel(
            label: 'LIFT',
            color: Colors.white,
            onChanged: (c) {
              // Update Lift logic here
            },
          ),
          widgets.ColorWheel(
            label: 'GAMMA',
            color: Colors.white,
            onChanged: (c) {
              // Update Gamma logic here
            },
          ),
          widgets.ColorWheel(
            label: 'GAIN',
            color: Colors.white,
            onChanged: (c) {
              // Update Gain logic here
            },
          ),
        ],
      ),
    );
  }

  Color _selectedCurveChannel = Colors.white;

  Widget _buildColorCurves() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _curveChannelBtn(Colors.white),
              _curveChannelBtn(Colors.red),
              _curveChannelBtn(Colors.green),
              _curveChannelBtn(Colors.blue),
            ],
          ),
        ),
        Expanded(
          child: CurvesWidget(
            channelColor: _selectedCurveChannel,
            points: [CurvePoint(0, 0), CurvePoint(0.5, 0.5), CurvePoint(1, 1)],
            onChanged: (points) {
              // Update curves logic in BLoC
            },
          ),
        ),
      ],
    );
  }

  Widget _curveChannelBtn(Color color) {
    final bool isSelected = _selectedCurveChannel == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedCurveChannel = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
