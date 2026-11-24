import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Data profil pengguna yang sedang masuk.
/// Nama, email, dan foto berasal dari akun Firebase (email atau Google).
class ProfileStore extends ChangeNotifier {
  String? uid;
  String name = 'User';
  String email = '';
  String? photoUrl; // foto dari akun Google, null untuk akun email
  String? photoPath; // foto pilihan pengguna di perangkat, null = belum ada

  /// Isi profil dari akun Firebase yang baru login.
  void loadFromUser(User user) {
    uid = user.uid;
    name = (user.displayName == null || user.displayName!.trim().isEmpty)
        ? (user.email?.split('@').first ?? 'User')
        : user.displayName!;
    email = user.email ?? '';
    photoUrl = user.photoURL;
    notifyListeners();
  }

  /// Kosongkan profil saat keluar.
  void clear() {
    uid = null;
    name = 'User';
    email = '';
    photoUrl = null;
    photoPath = null;
    notifyListeners();
  }

  void setName(String newName) {
    name = newName;
    notifyListeners();
  }

  void setPhoto(String path) {
    photoPath = path;
    notifyListeners();
  }
}

/// Satu objek yang dipakai bersama oleh seluruh aplikasi.
final profileStore = ProfileStore();