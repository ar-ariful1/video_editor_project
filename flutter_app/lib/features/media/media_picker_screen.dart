// lib/features/media/media_picker_screen.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../../app_theme.dart';

class MediaPickerScreen extends StatefulWidget {
  final bool allowVideo;
  final bool allowImage;
  final bool allowMultiple;
  final void Function(List<AssetEntity>) onSelected;

  const MediaPickerScreen({
    super.key,
    this.allowVideo = true,
    this.allowImage = true,
    this.allowMultiple = true,
    required this.onSelected,
  });

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _assets = [];
  final Set<AssetEntity> _selected = {};
  AssetPathEntity? _currentAlbum;
  bool _loading = true;
  int _page = 0;
  static const _pageSize = 80;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: allowVideo && allowImage
            ? 3
            : allowVideo
                ? 2
                : 2,
        vsync: this);
    _loadAlbums();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get allowVideo => widget.allowVideo;
  bool get allowImage => widget.allowImage;

  Future<void> _loadAlbums() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final types = <RequestType>[];
    if (allowVideo) types.add(RequestType.video);
    if (allowImage) types.add(RequestType.image);

    final albums = await PhotoManager.getAssetPathList(
      type: types.fold(
          RequestType.common, (a, b) => RequestType(a.value | b.value)),
      onlyAll: false,
    );

    setState(() {
      _albums = albums;
      _loading = false;
    });
    if (albums.isNotEmpty) _loadAlbumAssets(albums.first);
  }

  Future<void> _loadAlbumAssets(AssetPathEntity album,
      {bool reset = true}) async {
    if (reset) {
      setState(() {
        _currentAlbum = album;
        _assets = [];
        _page = 0;
      });
    }
    final assets = await album.getAssetListPaged(page: _page, size: _pageSize);
    setState(() {
      _assets.addAll(assets);
      _page++;
    });
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        if (!widget.allowMultiple) _selected.clear();
        _selected.add(asset);
      }
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    widget.onSelected(_selected.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Select Media'),
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text('Add (${_selected.length})',
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.w700)),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.accent,
          tabs: [
            if (allowVideo && allowImage) const Tab(text: 'All'),
            if (allowVideo) const Tab(text: 'Videos'),
            if (allowImage) const Tab(text: 'Photos'),
          ],
        ),
      ),
      body: Column(children: [
        // Album selector
        if (_albums.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final selected = _currentAlbum == _albums[i];
                return GestureDetector(
                  onTap: () => _loadAlbumAssets(_albums[i]),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Text(_albums[i].name,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        )),
                  ),
                );
              },
            ),
          ),

        // Grid
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (_, i) => _AssetTile(
                    asset: _assets[i],
                    isSelected: _selected.contains(_assets[i]),
                    selectionIndex: _selected.toList().indexOf(_assets[i]) + 1,
                    onTap: () => _toggleSelect(_assets[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int selectionIndex;
  final VoidCallback onTap;
  const _AssetTile(
      {required this.asset,
      required this.isSelected,
      required this.selectionIndex,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        // Thumbnail
        Positioned.fill(
          child: FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
            builder: (_, snap) {
              if (snap.data == null) return Container(color: AppTheme.bg3);
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
        ),
        // Video duration
        if (asset.type == AssetType.video)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                _fmtDur(asset.videoDuration),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        // Selection overlay
        if (isSelected)
          Positioned.fill(
              child: Container(color: AppTheme.accent.withValues(alpha: 0.4))),
        // Selection number
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: isSelected
                ? Center(
                    child: Text('$selectionIndex',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)))
                : null,
          ),
        ),
      ]),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

