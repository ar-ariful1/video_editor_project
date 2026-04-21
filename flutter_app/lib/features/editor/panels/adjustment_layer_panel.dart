// lib/features/editor/panels/adjustment_layer_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';
import '../../../core/models/video_project.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AdjustmentLayerPanel extends StatefulWidget {
  const AdjustmentLayerPanel({super.key});
  @override
  State<AdjustmentLayerPanel> createState() => _AdjustmentLayerPanelState();
}

class _AdjustmentLayerPanelState extends State<AdjustmentLayerPanel> {
  void _addAdjustmentLayer(BuildContext ctx, TimelineState state) {
    final currentTime = state.currentTime;
    final clip = Clip(
      id: _uuid.v4(),
      startTime: currentTime,
      endTime: currentTime + 5.0,
      mediaType: 'adjustment',
      isAdjustmentLayer: true,
    );

    // Find or create adjustment track (highest z-index)
    final adjTrack = state.project?.tracks.firstWhere(
      (t) => t.type == TrackType.adjustment,
      orElse: () => Track.create(
          name: 'Adjustment', type: TrackType.adjustment, zIndex: 20),
    );

    if (adjTrack != null) {
      ctx.read<TimelineBloc>().add(AddClip(trackId: adjTrack.id, clip: clip));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (ctx, state) {
        final adjLayers = state.project?.tracks
                .where((t) => t.type == TrackType.adjustment)
                .expand((t) => t.clips)
                .toList() ??
            [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2))),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.accent, size: 16),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Adjustment layers apply effects to ALL tracks below them on the timeline.',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            height: 1.4))),
              ]),
            ),
            const SizedBox(height: 16),

            // Add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addAdjustmentLayer(ctx, state),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Adjustment Layer'),
              ),
            ),
            const SizedBox(height: 16),

            // List of existing adjustment layers
            if (adjLayers.isNotEmpty) ...[
              const Text('Active Adjustment Layers',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...adjLayers.map((clip) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.bg3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      const Icon(Icons.layers_rounded,
                          color: AppTheme.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Adjustment Layer',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${clip.startTime.toStringAsFixed(1)}s — ${clip.endTime.toStringAsFixed(1)}s · ${clip.effects.length} effects',
                                style: const TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11)),
                          ])),
                      if (clip.effects.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('${clip.effects.length} fx',
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  )),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.layers_outlined,
                        color: AppTheme.textTertiary, size: 40),
                    SizedBox(height: 8),
                    Text('No adjustment layers yet',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Add one to apply effects to all clips below',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }
}

