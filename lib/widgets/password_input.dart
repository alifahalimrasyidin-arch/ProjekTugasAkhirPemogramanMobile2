import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

const _orange = Color(0xFFE08A1E);
const _lime = Color(0xFF8DB63C);

Color _levelColor(PasswordLevel l) {
  switch (l) {
    case PasswordLevel.tooShort:
      return AppColors.danger;
    case PasswordLevel.weak:
      return _orange;
    case PasswordLevel.ok:
      return _lime;
    case PasswordLevel.strong:
      return AppColors.primary;
    case PasswordLevel.empty:
      return AppColors.line;
  }
}

int _levelBars(PasswordLevel l) {
  switch (l) {
    case PasswordLevel.tooShort:
      return 1;
    case PasswordLevel.weak:
      return 2;
    case PasswordLevel.ok:
      return 3;
    case PasswordLevel.strong:
      return 4;
    case PasswordLevel.empty:
      return 0;
  }
}

String _levelMessage(String p, PasswordLevel l) {
  switch (l) {
    case PasswordLevel.tooShort:
      return 'Harus memiliki 8 karakter (${p.length}/8)';
    case PasswordLevel.weak:
      final missing = <String>[
        if (!hasUpper(p)) 'huruf kapital',
        if (!hasDigit(p)) 'angka',
      ];
      return 'Sandi lemah, belum ada ${missing.join(' dan ')}';
    case PasswordLevel.ok:
      return 'Sandi cukup. Tambahkan simbol agar lebih kuat';
    case PasswordLevel.strong:
      return 'Sandi kuat';
    case PasswordLevel.empty:
      return '';
  }
}

/// Kolom kata sandi dengan tombol lihat/sembunyikan.
/// Jika [showStrength] aktif, border dan keterangan kekuatan berubah
/// secara real time saat pengguna mengetik.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText; // error dari luar (mis. kata sandi salah)
  final bool showStrength;
  final ValueChanged<String>? onChanged;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Kata sandi',
    this.errorText,
    this.showStrength = false,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final p = value.text;
        final level =
            widget.showStrength ? evaluatePassword(p) : PasswordLevel.empty;
        final color = _levelColor(level);
        final showLevel = widget.showStrength &&
            level != PasswordLevel.empty &&
            widget.errorText == null;

        OutlineInputBorder? border(double w) => showLevel
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: w),
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.controller,
              obscureText: _obscure,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: widget.errorText,
                enabledBorder: border(1.6),
                focusedBorder: border(1.8),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (showLevel) ...[
              const SizedBox(height: 8),
              Row(
                children: List.generate(4, (i) {
                  final filled = i < _levelBars(level);
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled ? color : context.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                _levelMessage(p, level),
                style: TextStyle(
                    color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Kolom "Ulangi kata sandi": error real time jika berbeda.
class ConfirmPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController passwordController;
  final String label;
  final bool submitted; // true setelah tombol ditekan, agar kosong ikut diberi error

  const ConfirmPasswordField({
    super.key,
    required this.controller,
    required this.passwordController,
    this.label = 'Ulangi kata sandi',
    this.submitted = false,
  });

  @override
  State<ConfirmPasswordField> createState() => _ConfirmPasswordFieldState();
}

class _ConfirmPasswordFieldState extends State<ConfirmPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([widget.controller, widget.passwordController]),
      builder: (context, _) {
        final c = widget.controller.text;
        final p = widget.passwordController.text;
        String? error;
        String? helper;
        if (c.isEmpty) {
          if (widget.submitted) error = 'Konfirmasi kata sandi wajib diisi';
        } else if (c != p) {
          error = 'Kata sandi berbeda';
        } else {
          helper = 'Kata sandi sama';
        }
        return TextField(
          controller: widget.controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.lock_outline),
            errorText: error,
            helperText: helper,
            helperStyle: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        );
      },
    );
  }
}