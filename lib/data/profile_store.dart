import 'package:flutter/foundation.dart';

/// Data profil pengguna yang sedang masuk (disimpan di memori).
/// Akun awal adalah akun uji.
class ProfileStore extends ChangeNotifier {
  String name = 'User';
  String email = 'admin@mail.com';
  String password = '12345';
  String? photoPath; // lokasi foto profil di perangkat, null = belum ada

  void updateInfo({required String name, required String email}) {
    this.name = name;
    this.email = email;
    notifyListeners();
  }

  void changePassword(String newPassword) {
    password = newPassword;
    notifyListeners();
  }

  void setPhoto(String path) {
    photoPath = path;
    notifyListeners();
  }
}

/// Satu objek yang dipakai bersama oleh seluruh aplikasi.
final profileStore = ProfileStore();