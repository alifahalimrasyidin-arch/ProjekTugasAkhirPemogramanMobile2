import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import '../data/plant_store.dart';
import '../data/profile_store.dart';
import '../services/auth_service.dart';
import '../services/account_lookup.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/password_input.dart';
import 'dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _submitted = false; // true setelah tombol Daftar ditekan
  bool _loading = false;
  String? _error;

  // Email yang sudah diketahui terdaftar (dari jawaban server).
  final Set<String> _takenEmails = {};

  @override
  void initState() {
    super.initState();
    for (final c in [_nameC, _emailC, _passC, _confirmC]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  // ---- Validasi real time ------------------------------------------------

  String? get _nameError {
    final t = _nameC.text.trim();
    if (t.isEmpty) return _submitted ? 'Nama wajib diisi' : null;
    if (t.length < 2) return 'Nama terlalu pendek';
    return null;
  }

  String? get _emailError {
    final t = _emailC.text.trim();
    if (t.isEmpty && !_submitted) return null;
    final format = emailFormatError(t);
    if (format != null) return format;
    if (_takenEmails.contains(t.toLowerCase())) return 'Email sudah terdaftar';
    return null;
  }

  String? get _passwordRequiredError =>
      (_submitted && _passC.text.isEmpty) ? 'Kata sandi wajib diisi' : null;

  bool get _formValid =>
      _nameC.text.trim().length >= 2 &&
      emailFormatError(_emailC.text) == null &&
      !_takenEmails.contains(_emailC.text.trim().toLowerCase()) &&
      isPasswordAcceptable(_passC.text) &&
      _confirmC.text.isNotEmpty &&
      _confirmC.text == _passC.text;

  // ---- Aksi --------------------------------------------------------------

  Future<void> _onRegisterPressed() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formValid) return;

    final name = _nameC.text.trim();
    final email = _emailC.text.trim();

    // Konfirmasi data sebelum akun dibuat.
    final yes = await showConfirmDialog(
      context,
      icon: Icons.person_add_alt_1,
      title: 'Konfirmasi pendaftaran',
      text: 'Pastikan data berikut sudah benar.',
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            DialogInfoRow('Nama', name),
            DialogInfoRow('Email', email),
          ],
        ),
      ),
      yesLabel: 'Ya, daftar',
      noLabel: 'Tidak',
    );
    if (!yes || !mounted) return; // "Tidak": kembali mengedit formulir

    setState(() => _loading = true);
    try {
      final user = await authService.registerWithEmail(
        name: name,
        email: email,
        password: _passC.text,
      );
      if (user == null) {
        setState(() => _error = 'Pendaftaran gagal. Coba lagi.');
        return;
      }
      profileStore.loadFromUser(user);
      recordProvider(user); // catat: akun ini daftar lewat Register
      await plantStore.load(user.uid); // akun baru: data masih kosong
      if (!mounted) return;
      await showWelcomeDialog(context, name: profileStore.name, isNew: true);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'email-already-in-use') {
          _takenEmails.add(email.toLowerCase()); // tampil sebagai error email
        } else {
          _error = authErrorMessage(e);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.person_add_alt_1, size: 64, color: context.accent),
              SizedBox(height: 16),
              Text(
                'Buat akun',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: context.accent),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                'Data kebunmu tersimpan di akun ini dan bisa dibuka di perangkat lain.',
                style: TextStyle(color: context.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28),
              TextField(
                controller: _nameC,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.person_outline),
                  errorText: _nameError,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  errorText: _emailError,
                ),
              ),
              SizedBox(height: 16),
              PasswordField(
                controller: _passC,
                showStrength: true,
                errorText: _passwordRequiredError,
              ),
              SizedBox(height: 16),
              ConfirmPasswordField(
                controller: _confirmC,
                passwordController: _passC,
                submitted: _submitted,
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(top: 12, left: 4),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _onRegisterPressed,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Daftar'),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}