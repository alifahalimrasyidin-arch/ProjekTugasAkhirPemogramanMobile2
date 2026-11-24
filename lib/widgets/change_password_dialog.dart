import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'app_dialogs.dart';
import 'password_input.dart';

/// Dialog ubah kata sandi: validasi real time, konfirmasi Ya/Tidak,
/// lalu popup berhasil.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (changed == true && context.mounted) {
    await showInfoDialog(
      context,
      icon: Icons.check_circle_outline,
      title: 'Kata sandi diubah',
      text: 'Gunakan kata sandi baru saat masuk berikutnya.',
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _submitted = false;
  bool _loading = false;
  String? _oldError;
  String? _generalError;

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  String? get _oldFieldError {
    if (_oldError != null) return _oldError;
    if (_submitted && _oldC.text.isEmpty) return 'Kata sandi lama wajib diisi';
    return null;
  }

  String? get _newFieldError {
    if (_submitted && _newC.text.isEmpty) return 'Kata sandi baru wajib diisi';
    if (_newC.text.isNotEmpty && _newC.text == _oldC.text) {
      return 'Kata sandi baru harus berbeda dari yang lama';
    }
    return null;
  }

  bool get _valid =>
      _oldC.text.isNotEmpty &&
      isPasswordAcceptable(_newC.text) &&
      _newC.text != _oldC.text &&
      _confirmC.text == _newC.text;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _generalError = null;
    });
    if (!_valid) return;

    final yes = await showConfirmDialog(
      context,
      icon: Icons.lock_outline,
      title: 'Ubah kata sandi?',
      text: 'Kata sandi akunmu akan diganti dengan yang baru.',
      yesLabel: 'Ya, ubah',
    );
    if (!yes || !mounted) return;

    setState(() => _loading = true);
    try {
      await authService.changePassword(_oldC.text, _newC.text);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _oldError = 'Kata sandi lama salah';
        } else {
          _generalError = authErrorMessage(e);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _generalError = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild saat ada ketikan agar error "lama = baru" ikut real time.
    return ListenableBuilder(
      listenable: Listenable.merge([_oldC, _newC, _confirmC]),
      builder: (context, _) => AlertDialog(
        title: const Text('Ubah kata sandi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: _oldC,
                label: 'Kata sandi lama',
                errorText: _oldFieldError,
                onChanged: (_) {
                  if (_oldError != null) setState(() => _oldError = null);
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _newC,
                label: 'Kata sandi baru',
                showStrength: true,
                errorText: _newFieldError,
              ),
              const SizedBox(height: 16),
              ConfirmPasswordField(
                controller: _confirmC,
                passwordController: _newC,
                label: 'Ulangi kata sandi baru',
                submitted: _submitted,
              ),
              if (_generalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_generalError!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}