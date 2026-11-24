import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Widget _badge(IconData icon, Color color) => Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 28),
    );

/// Popup konfirmasi seragam (Ya / Tidak). Mengembalikan true jika memilih Ya.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? text,
  Widget? content,
  Color color = AppColors.primary,
  String yesLabel = 'Ya',
  String noLabel = 'Tidak',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: _badge(icon, color),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text != null)
            Text(text,
                textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
          if (content != null) ...[
            const SizedBox(height: 12),
            content,
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(noLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(yesLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Popup informasi dengan satu tombol.
Future<void> showInfoDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String text,
  Color color = AppColors.primary,
  String okLabel = 'OK',
  bool barrierDismissible = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: _badge(icon, color),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(text,
          textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 44),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(okLabel),
        ),
      ],
    ),
  );
}

/// Popup "Selamat datang, Nama" setelah daftar atau masuk berhasil.
Future<void> showWelcomeDialog(
  BuildContext context, {
  required String name,
  bool isNew = false,
}) {
  return showInfoDialog(
    context,
    icon: Icons.waving_hand,
    title: 'Selamat datang, $name!',
    text: isNew
        ? 'Pendaftaran berhasil. Yuk mulai pantau kebunmu.'
        : 'Kamu berhasil masuk. Senang melihatmu kembali.',
    okLabel: 'Lanjut',
    barrierDismissible: false,
  );
}

/// Baris "Label: nilai" untuk isi popup.
class DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const DialogInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: TextStyle(color: context.muted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}