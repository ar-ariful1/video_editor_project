import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_bloc.dart';
import '../../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showEmail = false;
  bool _isRegister = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isRegister) {
      context.read<AuthBloc>().add(RegisterWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            displayName: _nameCtrl.text.trim(),
          ));
    } else {
      context.read<AuthBloc>().add(SignInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (!_showEmail)
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Skip',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(context, '/home');
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.accent4),
            );
          }
        },
        builder: (ctx, state) {
          final loading = state is AuthLoading;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const SizedBox(height: 60),
                // Logo
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Icon(Icons.movie_creation_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                const Text('Clip Cut',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Professional editing in your pocket',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 48),

                if (!_showEmail) ...[
                  // Google Sign-In
                  _SocialButton(
                    label: 'Continue with Google',
                    icon: '🌐',
                    loading: loading,
                    onTap: () =>
                        ctx.read<AuthBloc>().add(const SignInWithGoogle()),
                  ),
                  const SizedBox(height: 14),
                  // Email option
                  _SocialButton(
                    label: 'Continue with Email',
                    icon: '✉️',
                    loading: false,
                    onTap: () => setState(() => _showEmail = true),
                    outlined: true,
                  ),
                  const SizedBox(height: 32),
                  Row(children: [
                    const Expanded(child: Divider(color: AppTheme.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Free to start',
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: AppTheme.border)),
                  ]),
                  const SizedBox(height: 24),
                  // Feature list
                  ...[
                    ('🎬', 'Multi-track timeline editor'),
                    ('✨', '50+ effects & transitions'),
                    ('🤖', 'AI auto-captions & background removal'),
                    ('🎨', 'Color grading & LUT support'),
                  ].map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Text(f.$1, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Text(f.$2,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 14)),
                        ]),
                      )),
                ] else ...[
                  // Email form
                  if (_isRegister) ...[
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textTertiary),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(_isRegister ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                        _isRegister
                            ? 'Already have an account?'
                            : "Don't have an account?",
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isRegister = !_isRegister),
                      child: Text(_isRegister ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  TextButton(
                    onPressed: () => setState(() => _showEmail = false),
                    child: const Text('← Back',
                        style: TextStyle(color: AppTheme.textTertiary)),
                  ),
                ],

                const SizedBox(height: 40),
                const Text('By continuing, you agree to our Terms of Service',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool loading;
  final VoidCallback onTap;
  final bool outlined;

  const _SocialButton(
      {required this.label,
      required this.icon,
      required this.loading,
      required this.onTap,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: outlined
          ? OutlinedButton(
              onPressed: loading ? null : onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ]),
            )
          : ElevatedButton(
              onPressed: loading ? null : onTap,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppTheme.accent,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ]),
            ),
    );
  }
}
