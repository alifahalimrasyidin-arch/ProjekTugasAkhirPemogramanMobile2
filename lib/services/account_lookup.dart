import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Mencatat metode masuk tiap email di Firestore: emailProviders/{email}.
/// Dipakai halaman "Lupa kata sandi" untuk tahu apakah sebuah email
/// terdaftar lewat Register (sandi) atau lewat Google (tanpa sandi).
///
/// Nilai providers: 'email' = daftar lewat Register, 'google' = akun Google.

/// Catat metode masuk akun yang baru login. Tidak ditunggu oleh pemanggil.
Future<void> recordProvider(User user) async {
  final email = user.email?.trim().toLowerCase();
  if (email == null || email.isEmpty) return;

  final providers = <String>[
    if (user.providerData.any((p) => p.providerId == 'password')) 'email',
    if (user.providerData.any((p) => p.providerId == 'google.com')) 'google',
  ];
  if (providers.isEmpty) return;

  try {
    await FirebaseFirestore.instance
        .collection('emailProviders')
        .doc(email)
        .set({
      'providers': FieldValue.arrayUnion(providers),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Gagal mencatat metode masuk: $e');
  }
}

/// Daftar metode masuk untuk [email], atau null jika belum tercatat.
Future<List<String>?> lookupProviders(String email) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('emailProviders')
        .doc(email.trim().toLowerCase())
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists) return null;
    final list = doc.data()?['providers'];
    if (list is! List) return null;
    return list.map((e) => e.toString()).toList();
  } catch (e) {
    debugPrint('Gagal membaca metode masuk: $e');
    return null; // tidak diketahui: biarkan Firebase yang menentukan
  }
}