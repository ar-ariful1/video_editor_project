// lib/features/editor/panels/color_grading_panel.dart
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
    _tabController = TabController(length: 4, vsync: this);
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
            Tab(text: 'LUT'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicAdjustments(),
              _buildColorWheels(),
              _buildColorCurves(),
              _buildLUTPanel(),
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
            onChanged: (c) {},
          ),
          widgets.ColorWheel(
            label: 'GAMMA',
            color: Colors.white,
            onChanged: (c) {},
          ),
          widgets.ColorWheel(
            label: 'GAIN',
            color: Colors.white,
            onChanged: (c) {},
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
            onChanged: (points) {},
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

  Widget _buildLUTPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Picking .cube LUT file...')),
            );
          },
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Import .cube LUT'),
        ),
        const SizedBox(height: 20),
        const Text('Standard LUTs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final luts = ['Natural', 'Vivid', 'Cinematic', 'B&W', 'Vintage', 'Cool'];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Text(luts[index], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            );
          },
        ),
      ],
    );
  }
}