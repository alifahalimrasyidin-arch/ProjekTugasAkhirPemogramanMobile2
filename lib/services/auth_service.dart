import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web client ID dari Firebase Console (bukan rahasia).
const String _webClientId = '741606540462-p6s21sehle8qife0gpocm5gstb4uv4o9.apps.googleusercontent.com';

/// Layanan autentikasi: email + kata sandi dan login Google,
/// semuanya lewat Firebase Authentication.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _initialized = false;

  User? get currentUser => _auth.currentUser;

  /// True jika akun yang sedang masuk punya kata sandi (daftar lewat email).
  /// Akun yang hanya memakai Google tidak punya kata sandi di aplikasi ini.
  bool get hasPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _google.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  // ---------------------------------------------------------------------
  // Email + kata sandi
  // ---------------------------------------------------------------------

  /// Daftar akun baru, otomatis langsung masuk.
  Future<User?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user?.updateDisplayName(name.trim());
    await result.user?.reload();
    final user = _auth.currentUser;
    if (user != null) _saveProfile(user);
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user != null) _saveProfile(user);
    return user;
  }

  /// Kirim email berisi tautan untuk mengatur ulang kata sandi.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Ubah kata sandi. Kata sandi lama diverifikasi dulu (re-autentikasi).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-user');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Ubah nama tampilan akun.
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
    _saveProfile(_auth.currentUser!);
  }

  // ---------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------

  Future<User?> signInWithGoogle() async {
    await _ensureInit();
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Token Google tidak diterima.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) _saveProfile(user);
    return user;
  }

  // ---------------------------------------------------------------------
  // Umum
  // ---------------------------------------------------------------------

  /// Simpan/perbarui profil dasar di Firestore: users/{uid}.
  /// Sengaja tidak di-await oleh pemanggil agar login tidak menunggu jaringan.
  Future<void> _saveProfile(User user) async {
    try {
      await _db.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Gagal simpan profil: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInit();
      await _google.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Google signOut gagal: $e');
    }
    await _auth.signOut();
  }
}

/// Satu objek yang dipakai bersama oleh seluruh aplikasi.
final authService = AuthService();

/// Ubah error Firebase menjadi pesan Bahasa Indonesia yang mudah dipahami.
String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'requires-recent-login':
        return 'Demi keamanan, silakan keluar lalu masuk lagi.';
      case 'account-exists-with-different-credential':
        return 'Email ini sudah terdaftar dengan metode masuk lain.';
      default:
        return 'Terjadi kesalahan (${e.code}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}