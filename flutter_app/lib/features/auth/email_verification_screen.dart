// lib/features/auth/email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sending = false;
  bool _sent = false;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _sendVerification();
  }

  Future<void> _sendVerification() async {
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        _sending = false;
        _sent = true;
        _resendCooldown = 60;
      });
      _startCooldown();
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _resendCooldown <= 0) return;
      setState(() => _resendCooldown--);
      _startCooldown();
    });
  }

  Future<void> _checkVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!mounted) return;
    if (verified) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Email not verified yet. Please check your inbox.'),
            backgroundColor: AppTheme.accent4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Spacer(),
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.4), width: 2)),
              child: const Icon(Icons.mark_email_read_rounded,
                  color: AppTheme.accent, size: 48),
            ),
            const SizedBox(height: 28),
            const Text('Verify Your Email',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('We sent a verification link to\n${widget.email}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),

            // Check verified button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _checkVerified,
                child: const Text('I\'ve Verified My Email',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),

            // Resend button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: (_resendCooldown > 0 || _sending)
                    ? null
                    : _sendVerification,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent))
                    : Text(
                        _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown}s'
                            : 'Resend Verification Email',
                        style: const TextStyle(fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Wrong email
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted)
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (_) => false);
              },
              child: const Text('Wrong email? Sign out and try again',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            ),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

