import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/native_engine_service.dart';

class PreviewPlayer extends StatefulWidget {
  final bool isPlaying;
  final double currentTime;
  final Function(double)? onTimeUpdate;

  const PreviewPlayer({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    this.onTimeUpdate,
  });
}

 


class _PreviewPlayerState extends State<PreviewPlayer> {
  int? _textureId;
  Timer? _timer;
  double _localTime = 0.0;

  @override
  void initState() {
    super.initState();
    _initTexture();
  }

  Future<void> _initTexture() async {
    final id = await NativeEngineService().getPreviewTextureId();
    if (mounted) {
      setState(() => _textureId = id);
    }
  }

  @override
  void didUpdateWidget(PreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startPlayback();
      } else {
        _stopPlayback();
      }
    }
  }

  void _startPlayback() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 33), (timer) {
      _localTime += 1 / 30; 
      widget.onTimeUpdate?.call(_localTime);
      NativeEngineService().renderFrame(_localTime);
    });
  }

  void _stopPlayback() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == null) {
      return Center(child: CircularProgressIndicator());
    }
    return Texture(textureId: _textureId!);
  }
}