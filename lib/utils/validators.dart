/// Aturan validasi yang dipakai bersama oleh halaman daftar, masuk,
/// lupa kata sandi, dan ubah kata sandi.

final RegExp _emailRegex =
    RegExp(r'^[^@\s]+@[^@\s]+\.com$', caseSensitive: false);

/// Mengembalikan pesan error, atau null jika format email benar.
/// Aturan: wajib ada @ dan diakhiri .com.
String? emailFormatError(String raw) {
  final email = raw.trim();
  if (email.isEmpty) return 'Email wajib diisi';
  if (!email.contains('@')) return 'Email harus mengandung @';
  if (!email.toLowerCase().endsWith('.com')) return 'Email harus diakhiri .com';
  if (!_emailRegex.hasMatch(email)) return 'Format email tidak valid';
  return null;
}

/// Tingkat kekuatan kata sandi.
enum PasswordLevel {
  empty, // belum diisi
  tooShort, // kurang dari 8 karakter
  weak, // 8+ karakter, tetapi tanpa huruf kapital atau angka
  ok, // memenuhi syarat wajib (8+, kapital, angka)
  strong, // memenuhi syarat wajib + mengandung simbol
}

bool hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
bool hasDigit(String p) => RegExp(r'\d').hasMatch(p);
bool hasSymbol(String p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p);

PasswordLevel evaluatePassword(String p) {
  if (p.isEmpty) return PasswordLevel.empty;
  if (p.length < 8) return PasswordLevel.tooShort;
  if (!hasUpper(p) || !hasDigit(p)) return PasswordLevel.weak;
  return hasSymbol(p) ? PasswordLevel.strong : PasswordLevel.ok;
}

/// Kata sandi boleh dipakai jika memenuhi syarat wajib.
bool isPasswordAcceptable(String p) {
  final l = evaluatePassword(p);
  return l == PasswordLevel.ok || l == PasswordLevel.strong;
}