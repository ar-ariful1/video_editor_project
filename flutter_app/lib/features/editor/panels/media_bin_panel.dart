import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Clip;
import 'dart:ui' as ui show Clip;
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';

class MediaBinPanel extends StatelessWidget {
  const MediaBinPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (context, state) {
        final assets = state.project?.assets ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Media Bin',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _pickMedia(context),
                    icon: const Icon(Icons.add, size: 18, color: AppTheme.accent),
                    label: const Text('Import',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),
            Expanded(
              child: assets.isEmpty
                  ? _buildEmptyState(context)
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: assets.length,
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return _MediaAssetItem(asset: asset);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined,
              size: 48, color: AppTheme.textTertiary.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Your media bin is empty',
              style: TextStyle(color: AppTheme.textTertiary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _pickMedia(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Media'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final bloc = context.read<TimelineBloc>();

    final String? type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Import Media',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ImportButton(
                  icon: Icons.video_collection_rounded,
                  label: 'Video',
                  onTap: () => Navigator.pop(ctx, 'video'),
                ),
                _ImportButton(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  onTap: () => Navigator.pop(ctx, 'image'),
                ),
                _ImportButton(
                  icon: Icons.audiotrack_rounded,
                  label: 'Audio',
                  onTap: () => Navigator.pop(ctx, 'audio'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (type == null) return;

    XFile? file;
    if (type == 'video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else if (type == 'image') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else if (type == 'audio') {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        file = XFile(result.files.single.path!);
      }
    }

    if (file != null) {
      bloc.add(AddAsset(ProjectAsset(
        id: const Uuid().v4(),
        name: file.name,
        path: file.path,
        type: type,
      )));
    }
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImportButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MediaAssetItem extends StatelessWidget {
  final ProjectAsset asset;
  const _MediaAssetItem({required this.asset});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showAssetOptions(context),
      onTap: () => _addToTimeline(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: ui.Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset.type == 'image')
              Image.file(File(asset.path), fit: BoxFit.cover)
            else
              const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white70, size: 32)),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.black54,
                child: Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
            if (asset.type == 'video')
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.videocam, color: Colors.white70, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  void _showAssetOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_to_photos, color: Colors.white),
            title: const Text('Add to Timeline',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _addToTimeline(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Remove from Bin',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              context.read<TimelineBloc>().add(RemoveAsset(asset.id));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _addToTimeline(BuildContext context) {
    final bloc = context.read<TimelineBloc>();
    final state = bloc.state;

    // Add to the main video track
    final mainTrack = state.project?.tracks.firstWhere(
      (t) => t.type == TrackType.video && t.zIndex == 1,
      orElse: () => state.project!.tracks.first,
    );

    if (mainTrack != null) {
      final double startTime = state.currentTime;
      final double duration = asset.type == 'image' ? 3.0 : 5.0;

      bloc.add(AddClip(
        trackId: mainTrack.id,
        clip: Clip.create(
          startTime: startTime,
          endTime: startTime + duration,
          mediaPath: asset.path,
          mediaType: asset.type,
        ),
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${asset.name} to timeline')),
      );
    }
  }
}
