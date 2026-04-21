// lib/features/editor/panels/captions_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme.dart';
import '../../../core/bloc/timeline_bloc.dart';

class CaptionsPanel extends StatefulWidget {
  const CaptionsPanel({super.key});

  @override
  State<CaptionsPanel> createState() => _CaptionsPanelState();
}

class _CaptionsPanelState extends State<CaptionsPanel> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Auto Captions'),
              Tab(text: 'Manual'),
            ],
            labelColor: AppTheme.accent,
            indicatorColor: AppTheme.accent,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAutoTab(),
                _buildManualTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.closed_caption_rounded, size: 64, color: AppTheme.accent),
          const SizedBox(height: 20),
          const Text(
            'Speech to Text',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI will automatically generate captions from your video audio using Whisper AI.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                // Trigger AI caption generation
              },
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Generate Auto Captions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add Caption at Playhead'),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('No manual captions yet',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ),
      ],
    );
  }
}
