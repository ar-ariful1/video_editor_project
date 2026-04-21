// lib/features/editor/panels/export_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/services/native_engine_service.dart';
import '../../../core/models/video_project.dart' as model;

class ExportPanel extends StatefulWidget {
  const ExportPanel({super.key});
  @override
  State<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<ExportPanel> {
  String _resolution = '1080p';
  int _fps = 30;
  bool _isExporting = false;
  double _progress = 0;

  void _startExport() async {
    final project = context.read<TimelineBloc>().state.project;
    if (project == null) return;

    setState(() { _isExporting = true; _progress = 0; });

    final quality = _resolution == '4K'
        ? 'HIGH'
        : (_resolution == '1080p' ? 'STANDARD' : 'LOW');

    final nativeEngine = NativeEngineService();
    
    // Subscribe to progress
    final progressSub = nativeEngine.exportProgress.listen((p) {
      if (mounted) setState(() => _progress = p / 100.0);
    });

    final String outputPath = '/storage/emulated/0/Download/ClipCut_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final resultPath = await nativeEngine.startNativeExport(
      project: project,
      outputPath: outputPath,
      width: _resolution == '4K' ? 3840 : (_resolution == '1080p' ? 1080 : 720),
      height: _resolution == '4K' ? 2160 : (_resolution == '1080p' ? 1920 : 1280),
      fps: _fps,
      quality: quality,
    );

    await progressSub.cancel();

    if (!mounted) return;
    setState(() { _isExporting = false; });

    if (resultPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Video Exported to: $resultPath'), backgroundColor: AppTheme.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Export Failed'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Export Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          if (_isExporting) ...[
            const Text('Exporting... Please do not close the app', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress, color: AppTheme.accent, backgroundColor: AppTheme.bg3),
            const SizedBox(height: 8),
            Center(child: Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold))),
          ] else ...[
            const Text('Resolution', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            _buildSelectionRow(['720p', '1080p', '4K'], _resolution, (v) => setState(() => _resolution = v)),
            const SizedBox(height: 20),
            const Text('Frame Rate', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            _buildSelectionRow(['24', '30', '60'], _fps.toString(), (v) => setState(() => _fps = int.parse(v))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startExport,
                child: const Text('Export Now'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSelectionRow(List<String> options, String selected, ValueChanged<String> onSelected) {
    return Row(
      children: options.map((opt) {
        final isSelected = selected == opt;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(opt),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : AppTheme.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
              ),
              child: Center(
                child: Text(opt, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
