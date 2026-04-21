// lib/features/templates/template_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_theme.dart';
import '../../core/utils/utils.dart';
import '../media/media_picker_screen.dart';
import '../subscription/subscription_bloc.dart';
import '../subscription/subscription_screen.dart';
import 'engine/template_engine.dart';

class TemplateDetailScreen extends StatefulWidget {
  final Map<String, dynamic> template;
  const TemplateDetailScreen({super.key, required this.template});
  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  bool _playing = false;
  final Map<String, String> _selectedMedia = {}; // slotId → local path
  final Map<String, String> _textOverrides = {}; // textLayerId → user text

  List<dynamic> get _slots => (widget.template['slots'] as List?) ?? [];
  List<dynamic> get _textLayers =>
      (widget.template['textLayers'] as List?) ?? [];
  bool get _isPremium => widget.template['is_premium'] == true;
  int get _slotCount => _slots.length;
  bool get _allFilled =>
      _slotCount == 0 ||
      _slots.every((s) => _selectedMedia.containsKey(s['id']));

  Future<void> _pickMediaForSlot(String slotId, String type) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg2,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: MediaPickerScreen(
          allowVideo: type != 'image',
          allowImage: type != 'video',
          allowMultiple: false,
          onSelected: (assets) async {
            if (assets.isNotEmpty) {
              final file = await assets.first.file;
              if (file != null)
                setState(() => _selectedMedia[slotId] = file.path);
            }
          },
        ),
      ),
    );
  }

  Future<void> _useTemplate() async {
    final sub = context.read<SubscriptionBloc>().state;
    if (_isPremium && sub.plan == 'free') {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.bg2,
        builder: (_) => BlocProvider.value(
            value: context.read<SubscriptionBloc>(),
            child: const SubscriptionScreen()),
      );
      return;
    }

    try {
      final def = TemplateDefinition.fromJson(widget.template);
      final result = TemplateEngine.inject(
        template: def,
        mediaPaths: _selectedMedia,
        textOverrides: _textOverrides,
        projectName: widget.template['name'] ?? 'Template Project',
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/editor', (r) => r.settings.name == '/home',
          arguments: {'project': result.project});
    } catch (e) {
      showError(context, 'Failed to apply template: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(slivers: [
        // Preview video area
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          backgroundColor: AppTheme.bg2,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => Navigator.pop(context)),
          actions: [
            if (_isPremium)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.accent3.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppTheme.accent3.withValues(alpha: 0.5))),
                child: const Row(children: [
                  Icon(Icons.lock_rounded, color: AppTheme.accent3, size: 12),
                  SizedBox(width: 4),
                  Text('PRO',
                      style: TextStyle(
                          color: AppTheme.accent3,
                          fontSize: 11,
                          fontWeight: FontWeight.w800))
                ]),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              widget.template['thumbnail_url'] != null
                  ? Image.network(widget.template['thumbnail_url'],
                      fit: BoxFit.cover)
                  : Container(
                      color: AppTheme.bg3,
                      child: const Center(
                          child: Text('🎬', style: TextStyle(fontSize: 64)))),
              // Play button overlay
              GestureDetector(
                onTap: () => setState(() => _playing = !_playing),
                child: Container(
                  color: Colors.black26,
                  child: Center(
                      child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36),
                  )),
                ),
              ),
            ]),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            // Title & meta
            Text(widget.template['name'] ?? '',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              _Tag(widget.template['category'] ?? ''),
              const SizedBox(width: 8),
              _Tag('${_slotCount} clips'),
              const SizedBox(width: 8),
              if (widget.template['duration_seconds'] != null)
                _Tag('${widget.template['duration_seconds']}s'),
              if (widget.template['rating'] != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded,
                    color: AppTheme.accent3, size: 14),
                Text(
                    ' ${(widget.template['rating'] as num).toStringAsFixed(1)}',
                    style:
                        const TextStyle(color: AppTheme.accent3, fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 20),

            // Media slots
            if (_slotCount > 0) ...[
              Text(
                  'Add Your Videos & Photos (${_selectedMedia.length}/$_slotCount filled)',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...List.generate(_slots.length, (i) {
                final slot = _slots[i] as Map<String, dynamic>;
                final slotId = slot['id'] as String;
                final filled = _selectedMedia.containsKey(slotId);
                return GestureDetector(
                  onTap: () => _pickMediaForSlot(
                      slotId, slot['type'] ?? 'image_or_video'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 60,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppTheme.accent.withValues(alpha: 0.1)
                          : AppTheme.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: filled ? AppTheme.accent : AppTheme.border,
                          style:
                              filled ? BorderStyle.solid : BorderStyle.solid),
                    ),
                    child: Row(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            color: filled
                                ? AppTheme.accent.withValues(alpha: 0.2)
                                : AppTheme.bg2,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(9))),
                        child: Icon(
                            filled
                                ? Icons.check_circle_rounded
                                : Icons.add_photo_alternate_rounded,
                            color: filled
                                ? AppTheme.accent
                                : AppTheme.textTertiary,
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Text(slot['label'] ?? 'Clip ${i + 1}',
                                style: TextStyle(
                                    color: filled
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(filled ? 'Tap to change' : 'Tap to select',
                                style: const TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11)),
                          ])),
                      Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right_rounded,
                              color: AppTheme.textTertiary, size: 18)),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Text layers
            if (_textLayers.isNotEmpty) ...[
              const Text('Customize Text',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...List.generate(_textLayers.length, (i) {
                final tl = _textLayers[i] as Map<String, dynamic>;
                if (tl['editable'] != true) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    onChanged: (v) => _textOverrides[tl['id']] = v,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: tl['id'] ?? 'Text',
                      hintText: tl['defaultText'] ?? '',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ])),
        ),
      ]),

      // CTA button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _useTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPremium ? AppTheme.pink : AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _isPremium
                    ? '👑 Use Premium Template'
                    : _allFilled
                        ? '🚀 Start Editing'
                        : '🎬 Use Template',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppTheme.bg3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border)),
        child: Text(label,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      );
}

