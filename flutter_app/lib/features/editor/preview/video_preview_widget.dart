// lib/features/editor/preview/video_preview_widget.dart
import 'package:flutter/material.dart';
import '../../../core/engine/native_engine_bridge.dart';

class VideoPreviewWidget extends StatefulWidget {
  final NativeEngineBridge engine;
  final VoidCallback? onTextureCreated;

  const VideoPreviewWidget({
    super.key,
    required this.engine,
    this.onTextureCreated,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  int? _textureId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTexture();
  }

  Future<void> _initializeTexture() async {
    try {
      final id = await widget.engine.createVideoTexture();
      setState(() {
        _textureId = id;
        _isLoading = false;
      });
      widget.onTextureCreated?.call();
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
      debugPrint('Failed to create video texture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_textureId == null) {
      return const Center(child: Text('Preview unavailable'));
    }

    return SizedBox.expand(
      child: Texture(textureId: _textureId!),
    );
  }
}