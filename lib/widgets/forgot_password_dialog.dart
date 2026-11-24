import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import '../services/account_lookup.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'app_dialogs.dart';

/// Dialog lupa kata sandi: validasi email real time, konfirmasi Ya/Tidak,
/// lalu mengirim tautan reset ke email.
Future<void> showForgotPasswordDialog(BuildContext context,
    {String initialEmail = ''}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
  if (sent == true && context.mounted) {
    await showInfoDialog(
      context,
      icon: Icons.mark_email_read_outlined,
      title: 'Tautan terkirim',
      text:
          'Buka email kamu (cek juga folder spam) lalu ikuti tautannya untuk membuat kata sandi baru.',
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailC =
      TextEditingController(text: widget.initialEmail);
  bool _submitted = false;
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  String? get _emailError {
    if (_serverError != null) return _serverError;
    if (_emailC.text.isEmpty && !_submitted) return null;
    return emailFormatError(_emailC.text);
  }

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (emailFormatError(_emailC.text) != null) return;
    final email = _emailC.text.trim();

    setState(() => _loading = true);

    // Akun Google tidak memakai kata sandi, jadi tidak ada yang perlu direset.
    final providers = await lookupProviders(email);
    if (!mounted) return;
    if (providers != null &&
        providers.contains('google') &&
        !providers.contains('email')) {
      setState(() {
        _loading = false;
        _serverError =
            'Email ini terdaftar lewat Google dan tidak memakai kata sandi. Masuk dengan tombol "Masuk dengan Google".';
      });
      return;
    }

    final yes = await showConfirmDialog(
      context,
      icon: Icons.mail_outline,
      title: 'Kirim tautan reset?',
      text: 'Tautan untuk mengatur ulang kata sandi akan dikirim ke:',
      content: Text(email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      yesLabel: 'Ya, kirim',
    );
    if (!yes || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      await authService.sendPasswordReset(email);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _serverError =
          e.code == 'user-not-found' ? 'Akun tidak ditemukan' : authErrorMessage(e));
    } catch (e) {
      if (mounted) setState(() => _serverError = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _emailC,
      builder: (context, _) => AlertDialog(
        title: const Text('Lupa kata sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan email akunmu. Kami akan mengirim tautan untuk mengatur ulang kata sandi.',
              style: TextStyle(color: context.muted, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Hanya untuk akun yang daftar dengan email. Akun Google tidak memakai kata sandi: masuk saja dengan tombol "Masuk dengan Google".',
              style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                if (_serverError != null) setState(() => _serverError = null);
              },
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _emailError,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}