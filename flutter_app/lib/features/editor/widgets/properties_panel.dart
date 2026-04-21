import 'package:flutter/material.dart';
import '../../../app_theme.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg2,
      padding: const EdgeInsets.all(16),
      child: const Text('Select a clip to edit properties',
          style: TextStyle(color: AppTheme.textSecondary)),
    );
  }
}
