// lib/features/subscription/subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_theme.dart';
import 'subscription_bloc.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(const LoadSubscription());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Upgrade Plan'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (ctx, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                  content: Text(state.error!),
                  backgroundColor: AppTheme.accent4),
            );
          }
          if (state.isPro || state.isPremium) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                  content: Text('🎉 Welcome to Pro!'),
                  backgroundColor: AppTheme.green),
            );
          }
        },
        builder: (ctx, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.15),
                      AppTheme.accent2.withValues(alpha: 0.15)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  const Text('✨', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  const Text('Unlock Full Power',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Professional tools used by creators worldwide',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 24),

              // Current plan badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bg2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text('Current plan: ${state.plan.toUpperCase()}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),

              // Plan cards
              _PlanCard(
                title: 'Pro',
                price: '\$4.99',
                period: '/month',
                color: AppTheme.accent,
                icon: '✨',
                current: state.plan == 'pro',
                features: const [
                  '1080p export — no watermark',
                  'Unlimited projects',
                  '200+ effects & transitions',
                  'Auto captions (5 min/day)',
                  'Background removal',
                  'Cloud project sync',
                  'Priority export queue',
                ],
                onTap: state.isPurchasing
                    ? null
                    : () =>
                        ctx.read<SubscriptionBloc>().add(const PurchasePro()),
                loading: state.isPurchasing,
              ),
              const SizedBox(height: 14),

              _PlanCard(
                title: 'Premium',
                price: '\$9.99',
                period: '/month',
                color: AppTheme.pink,
                icon: '👑',
                current: state.plan == 'premium',
                featured: true,
                features: const [
                  '4K UHD export — no watermark',
                  'Everything in Pro',
                  'Unlimited AI captions',
                  'Object tracking (YOLOv8)',
                  '4K AI upscaling (ESRGAN)',
                  'All templates unlocked',
                  'Custom LUT import',
                  'Priority support',
                ],
                onTap: state.isPurchasing
                    ? null
                    : () => ctx
                        .read<SubscriptionBloc>()
                        .add(const PurchasePremium()),
                loading: state.isPurchasing,
              ),
              const SizedBox(height: 24),

              // Restore purchases
              TextButton(
                onPressed: () =>
                    ctx.read<SubscriptionBloc>().add(const RestorePurchases()),
                child: const Text('Restore Purchases',
                    style: TextStyle(color: AppTheme.textTertiary)),
              ),

              // Terms note
              const SizedBox(height: 8),
              const Text(
                'Subscriptions auto-renew. Cancel anytime in App Store / Google Play settings.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title, price, period, icon;
  final Color color;
  final bool current, featured, loading;
  final List<String> features;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.color,
    required this.icon,
    required this.features,
    required this.onTap,
    this.current = false,
    this.featured = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: featured ? color : AppTheme.border,
            width: featured ? 1.5 : 1),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  if (featured)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('BEST VALUE',
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text(period,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12)),
            ]),
          ]),
        ),

        // Features
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(f,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13))),
                  ]),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: current ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: current ? AppTheme.bg3 : color,
                  disabledBackgroundColor: AppTheme.bg3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        current ? 'Current Plan' : 'Get $title',
                        style: TextStyle(
                          color: current ? AppTheme.textTertiary : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

