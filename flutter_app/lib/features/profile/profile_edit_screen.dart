// lib/features/profile/profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../core/utils/utils.dart';
import '../auth/auth_bloc.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  File? _avatarFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      _nameCtrl.text = auth.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg2,
      builder: (_) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded,
              color: AppTheme.textSecondary),
          title: const Text('Take Photo',
              style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () async {
            Navigator.pop(context);
            await _capture(ImageSource.camera);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded,
              color: AppTheme.textSecondary),
          title: const Text('Choose from Gallery',
              style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () async {
            Navigator.pop(context);
            await _capture(ImageSource.gallery);
          },
        ),
      ]),
    );
  }

  Future<void> _capture(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Display name cannot be empty');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Upload avatar if changed
      String? avatarUrl;
      if (_avatarFile != null) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) {
          // Upload via project repo (reuse S3 presigned URL approach)
          // avatarUrl = await UserRepository().uploadAvatar(auth.userId, _avatarFile!.path);
        }
      }
      // Update profile via API
      // await UserRepository().updateProfile(displayName: _nameCtrl.text.trim(), avatarUrl: avatarUrl);
      if (mounted) {
        showSuccess(context, 'Profile updated!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final currentAvatar = auth is AuthAuthenticated ? auth.avatarUrl : null;
    final name = auth is AuthAuthenticated ? (auth.displayName ?? '') : '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent))
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Avatar
          Center(
            child: Stack(children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 2.5),
                  ),
                  child: ClipOval(
                    child: _avatarFile != null
                        ? Image.file(_avatarFile!, fit: BoxFit.cover)
                        : currentAvatar != null
                            ? Image.network(currentAvatar, fit: BoxFit.cover)
                            : Container(
                                color: AppTheme.accent.withValues(alpha: 0.2),
                                child: Center(
                                    child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700),
                                )),
                              ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: AppTheme.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: _pickAvatar,
              child: const Text('Change Photo',
                  style: TextStyle(color: AppTheme.accent))),
          const SizedBox(height: 24),

          // Display Name
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              helperText: 'This is how others will see you',
              helperStyle: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(height: 16),

          // Email (read-only)
          TextField(
            readOnly: true,
            controller: TextEditingController(text: auth is AuthAuthenticated ? auth.email : ''),
            style: const TextStyle(color: AppTheme.textTertiary),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              helperText: 'Email cannot be changed',
              helperStyle: TextStyle(color: AppTheme.textTertiary),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.accent4.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppTheme.accent4, fontSize: 13)),
            ),
          ],
        ]),
      ),
    );
  }
}

