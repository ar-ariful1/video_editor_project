// lib/features/editor/export/export_progress_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/engine/native_engine_bridge.dart';

class ExportProgressDialog extends StatefulWidget {
  final ExportConfig config;
  final VoidCallback? onCompleted;
  final VoidCallback? onError;

  const ExportProgressDialog({
    super.key,
    required this.config,
    this.onCompleted,
    this.onError,
  });

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  final _engine = NativeEngineBridge();
  double _progress = 0.0;
  String _status = 'Preparing...';
  bool _isExporting = true;
  bool _isCompleted = false;
  bool _hasError = false;
  String? _outputPath;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      // Listen to export progress stream
      _progressSubscription = _engine.exportProgress.listen(
        (progress) {
          setState(() {
            _progress = progress / 100.0;
            if (_progress >= 1.0) {
              _status = 'Finalizing...';
            } else {
              _status = 'Exporting ${(progress).toStringAsFixed(0)}%';
            }
          });
        },
        onError: (error) {
          _handleError(error.toString());
        },
      );

      _statusSubscription = _engine.exportStatus.listen(
        (status) {
          setState(() => _status = status);
        },
      );

      // Start the actual export
      await _engine.startExport(widget.config);

      // If we reach here, export succeeded
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isCompleted = true;
          _progress = 1.0;
          _status = 'Export completed!';
          _outputPath = widget.config.outputPath;
        });
        widget.onCompleted?.call();
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (!mounted) return;
    setState(() {
      _isExporting = false;
      _hasError = true;
      _status = 'Export failed: $error';
    });
    widget.onError?.call();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isExporting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isCompleted ? 'Export Complete' : 'Exporting Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExporting || _isCompleted) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_progress > 0 && _progress < 1.0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
            if (_hasError) ...[
              const SizedBox(height: 16),
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ],
            if (_isCompleted) ...[
              const SizedBox(height: 16),
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            ],
          ],
        ),
        actions: [
          if (_isExporting)
            TextButton(
              onPressed: _cancelExport,
              child: const Text('Cancel'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_outputPath);
              },
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelExport() async {
    try {
      await _engine.cancelExport();
      if (mounted) {
        setState(() {
          _isExporting = false;
          _status = 'Export cancelled';
        });
      }
    } catch (e) {
      // Ignore cancel errors
    }
  }
}