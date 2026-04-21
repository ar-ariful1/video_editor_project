// lib/features/legal/legal_screen.dart
import 'package:flutter/material.dart';
import '../../app_theme.dart';

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: Text(
            type == LegalType.terms ? 'Terms of Service' : 'Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: type == LegalType.terms
            ? const _TermsContent()
            : const _PrivacyContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('Terms of Service'),
        _Updated('Last updated: January 2025'),
        _Para(
            'By using Video Editor Pro, you agree to these terms. Please read them carefully.'),
        _Section('1. Use of Service'),
        _Para(
            'Video Editor Pro grants you a personal, non-exclusive, non-transferable, revocable license to use our app for your personal, non-commercial purposes. You may not reverse-engineer, decompile, or modify the app.'),
        _Section('2. User Content'),
        _Para(
            'You retain ownership of all content you create with our app. By using our service, you grant us a limited license to store and process your content solely to provide the service.'),
        _Para(
            'You are responsible for ensuring you have the rights to use all media (video, audio, images) in your projects.'),
        _Section('3. Subscription and Payments'),
        _Para(
            'Pro and Premium subscriptions are billed monthly through the App Store or Google Play. Subscriptions auto-renew unless cancelled at least 24 hours before the renewal date.'),
        _Para(
            'All purchases are final. Refunds are handled according to App Store / Google Play policies.'),
        _Section('4. Prohibited Uses'),
        _Para(
            'You may not use our service to: create illegal content, infringe on intellectual property rights, harass or harm others, or distribute malware.'),
        _Section('5. Export and Watermarks'),
        _Para(
            'Free plan exports include a watermark. Pro and Premium subscriptions remove the watermark for 1080p and 4K exports respectively.'),
        _Section('6. Termination'),
        _Para(
            'We may suspend or terminate your account if you violate these terms. You may cancel your account at any time from the app settings.'),
        _Section('7. Disclaimer of Warranties'),
        _Para(
            'The service is provided "as is" without warranties of any kind. We do not guarantee uninterrupted or error-free service.'),
        _Section('8. Contact'),
        _Para(
            'For questions about these terms, contact us at: legal@videoeditorpro.app'),
        const SizedBox(height: 40),
      ]);
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('Privacy Policy'),
        _Updated('Last updated: January 2025'),
        _Para(
            'Video Editor Pro is committed to protecting your privacy. This policy explains how we collect, use, and protect your information.'),
        _Section('1. Information We Collect'),
        _Para(
            '• Account information: email address, display name, profile photo\n• Usage data: features used, projects created, export history\n• Device information: device model, OS version, app version\n• Crash reports for debugging and stability'),
        _Section('2. How We Use Your Data'),
        _Para(
            'We use your data to: provide and improve the service, send notifications about your exports and new features, process payments through RevenueCat, and analyze usage to improve performance.'),
        _Section('3. Data Storage'),
        _Para(
            'Your projects are stored locally on your device and optionally synced to our secure cloud servers (AWS S3) if cloud sync is enabled. You can disable cloud sync in settings.'),
        _Section('4. Third-Party Services'),
        _Para(
            'We use the following third-party services:\n• Firebase (Google) — Authentication and crash reporting\n• RevenueCat — Subscription management\n• AWS — Cloud storage and processing'),
        _Section('5. Data Retention'),
        _Para(
            'We retain your account data for as long as your account is active. You can request deletion of your account and all associated data from Settings → Account → Delete Account.'),
        _Section('6. Your Rights'),
        _Para(
            'You have the right to: access your personal data, request correction of inaccurate data, request deletion of your data, and opt out of marketing communications.'),
        _Section('7. Children\'s Privacy'),
        _Para(
            'Our service is not directed to children under 13. We do not knowingly collect data from children under 13.'),
        _Section('8. Contact'),
        _Para(
            'For privacy questions or data requests: privacy@videoeditorpro.app'),
        const SizedBox(height: 40),
      ]);
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
      );
}

class _Updated extends StatelessWidget {
  final String text;
  const _Updated(this.text);
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(text,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
      );
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      );
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.65)),
      );
}
