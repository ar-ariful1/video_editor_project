// lib/core/services/feature_gate_service.dart
// Centralized plan-based feature access control

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_theme.dart';
import '../utils/app_icons.dart';
import '../../features/subscription/subscription_bloc.dart';
import '../../features/subscription/subscription_screen.dart';

enum Feature {
  export720p,
  export1080p,
  export4k,
  removeWatermark,
  unlimitedProjects,
  cloudSync,
  effectsLibraryFull,
  aiCaptions,
  aiCaptionsUnlimited,
  aiBackgroundRemoval,
  aiObjectTracking,
  ai4kUpscaling,
  aiBeatDetection,
  customLutImport,
  allTemplates,
  premiumTemplates,
  priorityExport,
  beautyFilter,
  arFilters,
  chromaKey,
  maskTools,
}

enum PlanRequirement { free, pro, premium }

class FeatureGateService {
  static final Map<Feature, PlanRequirement> _requirements = {
    Feature.export720p: PlanRequirement.free,
    Feature.export1080p: PlanRequirement.pro,
    Feature.export4k: PlanRequirement.premium,
    Feature.removeWatermark: PlanRequirement.pro,
    Feature.unlimitedProjects: PlanRequirement.pro,
    Feature.cloudSync: PlanRequirement.pro,
    Feature.effectsLibraryFull: PlanRequirement.pro,
    Feature.aiCaptions: PlanRequirement.pro,
    Feature.aiCaptionsUnlimited: PlanRequirement.premium,
    Feature.aiBackgroundRemoval: PlanRequirement.pro,
    Feature.aiObjectTracking: PlanRequirement.premium,
    Feature.ai4kUpscaling: PlanRequirement.premium,
    Feature.aiBeatDetection: PlanRequirement.pro,
    Feature.customLutImport: PlanRequirement.premium,
    Feature.allTemplates: PlanRequirement.premium,
    Feature.premiumTemplates: PlanRequirement.pro,
    Feature.priorityExport: PlanRequirement.pro,
    Feature.beautyFilter: PlanRequirement.pro,
    Feature.arFilters: PlanRequirement.premium,
    Feature.chromaKey: PlanRequirement.pro,
    Feature.maskTools: PlanRequirement.pro,
  };

  static bool hasAccess(String userPlan, Feature feature) {
    final required = _requirements[feature] ?? PlanRequirement.free;
    final planOrder = {'free': 0, 'pro': 1, 'premium': 2};
    return (planOrder[userPlan] ?? 0) >= (planOrder[required.name] ?? 0);
  }

  static PlanRequirement getRequirement(Feature feature) =>
      _requirements[feature] ?? PlanRequirement.free;

  /// Call before any premium action. Shows paywall if blocked.
  /// Returns true if user has access.
  static bool checkAndGate(BuildContext context, Feature feature,
      {String? featureName}) {
    final sub = context.read<SubscriptionBloc>().state;
    if (hasAccess(sub.plan, feature)) return true;

    // Show paywall
    final required = getRequirement(feature);
    _showPaywall(context, required.name, featureName ?? feature.name);
    return false;
  }

  static void _showPaywall(
      BuildContext context, String requiredPlan, String featureName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BlocProvider.value(
        value: context.read<SubscriptionBloc>(),
        child:
            _PaywallModal(requiredPlan: requiredPlan, featureName: featureName),
      ),
    );
  }
}

class _PaywallModal extends StatelessWidget {
  final String requiredPlan;
  final String featureName;
  const _PaywallModal({required this.requiredPlan, required this.featureName});

  @override
  Widget build(BuildContext context) {
    final isPremium = requiredPlan == 'premium';
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text(isPremium ? '👑' : '✨', style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          '${isPremium ? 'Premium' : 'Pro'} Feature',
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '"$featureName" requires ${isPremium ? 'Premium' : 'Pro'} plan.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          isPremium
              ? 'Get 4K export, unlimited AI, all templates'
              : 'Get 1080p, no watermark, all AI tools',
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                        value: context.read<SubscriptionBloc>(),
                        child: const SubscriptionScreen()),
                    fullscreenDialog: true,
                  ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? AppTheme.pink : AppTheme.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isPremium ? 'Get Premium — \$9.99/mo' : 'Get Pro — \$4.99/mo',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now',
              style: TextStyle(color: AppTheme.textTertiary)),
        ),
      ]),
    );
  }
}

// ── Gated Widget — wraps any widget with plan check ──────────────────────────

class GatedWidget extends StatelessWidget {
  final Feature feature;
  final Widget child;
  final String? featureName;

  const GatedWidget(
      {super.key,
      required this.feature,
      required this.child,
      this.featureName});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionBloc>().state;
    final hasAccess = FeatureGateService.hasAccess(sub.plan, feature);

    if (hasAccess) return child;

    return Stack(children: [
      Opacity(opacity: 0.4, child: child),
      Positioned.fill(
          child: GestureDetector(
        onTap: () => FeatureGateService.checkAndGate(context, feature,
            featureName: featureName),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: const Center(
              child: Icon(AppIcons.crown, color: AppTheme.accent3, size: 18)),
        ),
      )),
    ]);
  }
}
