import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/plant_store.dart';
import '../data/profile_store.dart';
import '../services/auth_service.dart';
import '../services/account_lookup.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/password_input.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _submitted = false;

  // Error dari server, ditampilkan pada kolom yang sesuai.
  String? _emailServerError;
  String? _passwordServerError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Error email: dari server dulu, lalu format real time.
  String? get _emailError {
    if (_emailServerError != null) return _emailServerError;
    if (_emailController.text.isEmpty && !_submitted) return null;
    return emailFormatError(_emailController.text);
  }

  String? get _passwordError {
    if (_passwordServerError != null) return _passwordServerError;
    if (_submitted && _passwordController.text.isEmpty) {
      return 'Kata sandi wajib diisi';
    }
    return null;
  }

  void _clearServerErrors() {
    _emailServerError = null;
    _passwordServerError = null;
    _generalError = null;
  }

  /// Dipanggil setelah login berhasil (email maupun Google).
  Future<void> _afterLogin(User user) async {
    profileStore.loadFromUser(user);

    recordProvider(user); // catat metode masuk (email atau Google)
    await plantStore.load(user.uid); // muat tanaman milik akun ini
    if (!mounted) return;
    await showWelcomeDialog(context, name: profileStore.name);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DashboardPage()),
    );
  }

  Future<void> _loginEmail() async {
    setState(() {
      _submitted = true;
      _clearServerErrors();
    });
    if (emailFormatError(_emailController.text) != null ||
        _passwordController.text.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await authService.signInWithEmail(
          _emailController.text, _passwordController.text);
      if (user == null) {
        setState(() => _generalError = 'Gagal masuk. Coba lagi.');
        return;
      }
      await _afterLogin(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-email':
            _emailServerError = 'Akun tidak ditemukan';
            break;
          case 'wrong-password':
            _passwordServerError = 'Kata sandi salah';
            _generalError =
                'Mendaftar lewat Google? Gunakan tombol "Masuk dengan Google" di bawah.';
            break;
          case 'invalid-credential':
            // Muncul jika "Email enumeration protection" masih aktif:
            // Firebase sengaja tidak membedakan email salah dan sandi salah.
            _generalError = 'Email atau kata sandi salah.';
            break;
          default:
            _generalError = authErrorMessage(e);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _generalError = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _clearServerErrors();
      _loading = true;
    });
    try {
      final user = await authService.signInWithGoogle();
      if (user == null) {
        setState(() => _generalError = 'Login dibatalkan.');
        return;
      }
      await _afterLogin(user);
    } on GoogleSignInException catch (e) {
      setState(() => _generalError = e.code == GoogleSignInExceptionCode.canceled
          ? 'Login dibatalkan.'
          : 'Gagal masuk: ${e.description ?? e.code.name}');
    } catch (e) {
      if (mounted) setState(() => _generalError = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.eco, color: Colors.white, size: 30),
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    'Selamat datang kembali',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Masuk untuk melihat kondisi tanamanmu.',
                    style: TextStyle(color: context.muted),
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _emailServerError = null,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      errorText: _emailError,
                    ),
                  ),
                  SizedBox(height: 16),
                  PasswordField(
                    controller: _passwordController,
                    errorText: _passwordError,
                    onChanged: (_) => _passwordServerError = null,
                  ),
                  if (_generalError != null)
                    Padding(
                      padding: EdgeInsets.only(top: 10, left: 4),
                      child: Text(
                        _generalError!,
                        style:
                            TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => showForgotPasswordDialog(context,
                              initialEmail: _emailController.text.trim()),
                      child: Text('Lupa kata sandi?'),
                    ),
                  ),
                  SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: _loading ? null : _loginEmail,
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Masuk'),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('atau',
                            style: TextStyle(color: context.muted)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loginGoogle,
                    icon: Icon(Icons.login),
                    label: Text('Masuk dengan Google'),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Belum punya akun?',
                          style: TextStyle(color: context.muted)),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RegisterPage()),
                                ),
                        child: Text('Daftar di sini'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}