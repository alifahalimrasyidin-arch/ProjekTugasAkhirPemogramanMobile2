import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Kartu utama beranda: "Aktivitas kebunmu".
//
// Isinya: gradasi hijau, maskot yang main ayunan sambil menyiram (ayunan
// bergoyang, mata berkedip, air menetes), kebun kecil di bawah, dan lingkaran
// aktivitas 7 hari terakhir.
//
// Semua gambar dibuat berlapis di assets/mascot dan assets/garden. Mau ganti
// dengan gambar sendiri? Cukup timpa file PNG-nya dengan nama dan ukuran
// kanvas yang sama, kodenya tidak perlu diubah.
//
// Koordinat di file ini memakai "unit": lebar kartu = 1500 unit, jadi gambar
// ikut membesar atau mengecil mengikuti lebar layar.
// ---------------------------------------------------------------------------

const double _unitsWide = 1500;

// Kanvas gambar maskot: x 880..1500, y -80..540 (620 x 620 unit).
const double _canvasX = 880;
const double _canvasY = -80;
const double _canvasSize = 620;

// Titik gantung ayunan (di atas kartu) dan ujung corong penyiram.
const Offset _pivot = Offset(1260, -40);
const Offset _spout = Offset(1005.3, 451.0);

// Satu putaran animasi 6 detik. Ayunan 2 kali goyang, air jatuh 6 kali,
// jadi saat putaran mengulang tidak terlihat lompatan.
const Duration _loop = Duration(seconds: 6);

double _swingAngle(double t) => 0.055 * math.sin(2 * math.pi * 2 * t);

/// Mata menutup sebentar di tiga waktu dalam satu putaran (detik).
bool _blinking(double t) {
  final s = t * 6;
  return (s >= 1.9 && s < 2.05) ||
      (s >= 4.5 && s < 4.65) ||
      (s >= 4.8 && s < 4.95);
}

Offset _rotateAround(Offset p, Offset c, double a) {
  final dx = p.dx - c.dx, dy = p.dy - c.dy;
  final cs = math.cos(a), sn = math.sin(a);
  return Offset(c.dx + dx * cs - dy * sn, c.dy + dx * sn + dy * cs);
}

class GardenHero extends StatefulWidget {
  /// 7 tanggal terakhir, urut dari 6 hari lalu sampai hari ini.
  final List<DateTime> days;

  /// Jumlah catatan perawatan pada tiap tanggal di [days].
  final List<int> counts;

  const GardenHero({super.key, required this.days, required this.counts});

  @override
  State<GardenHero> createState() => _GardenHeroState();
}

class _GardenHeroState extends State<GardenHero>
    with SingleTickerProviderStateMixin {
  static const double _height = 262;
  static const _letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M']; // Senin..Minggu
  static const _layers = [
    'assets/mascot/swing.png',
    'assets/mascot/body.png',
    'assets/mascot/eyes_open.png',
    'assets/mascot/eyes_closed.png',
    'assets/mascot/arm_can.png',
    'assets/garden/garden_front.png',
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _loop)..repeat();
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final path in _layers) {
        precacheImage(AssetImage(path), context);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _layer(String name) => Positioned.fill(
        child: Image.asset(
          'assets/mascot/$name.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF10301F), Color(0xFF1B5A3D)]
          : const [Color(0xFF0E3A29), Color(0xFF248552)],
    );

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final s = w / _unitsWide; // dp per unit
      final size = _canvasSize * s;
      final pivotAlign = Alignment(
        (_pivot.dx - _canvasX) / _canvasSize * 2 - 1,
        (_pivot.dy - _canvasY) / _canvasSize * 2 - 1,
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: _height,
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            children: [
              // Cahaya lembut di belakang maskot.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.62, -0.6),
                      radius: 0.75,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),

              // Maskot di ayunan.
              Positioned(
                left: _canvasX * s,
                top: _canvasY * s,
                width: size,
                height: size,
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final t = _c.value;
                        final closed = _blinking(t);
                        return Transform.rotate(
                          angle: _swingAngle(t),
                          alignment: pivotAlign,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _layer('swing'),
                              _layer('body'),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: closed ? 0 : 1,
                                  child: Image.asset(
                                    'assets/mascot/eyes_open.png',
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: closed ? 1 : 0,
                                  child: Image.asset(
                                    'assets/mascot/eyes_closed.png',
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                              _layer('arm_can'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Kebun di bagian bawah.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/garden/garden_front.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),

              // Judul.
              Positioned(
                left: 20,
                top: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('7 hari terakhir',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    const Text('Aktivitas\nkebunmu',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),

              // Tetes air dari penyiram (di belakang lingkaran hari).
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _DropsPainter(_c, s)),
                  ),
                ),
              ),

              // Lingkaran 7 hari.
              Positioned(
                left: 20,
                right: 20,
                top: 122,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < widget.days.length; i++)
                      _dayDot(
                        letter: _letters[widget.days[i].weekday - 1],
                        active: widget.counts[i] > 0,
                        isToday: i == widget.days.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _dayDot(
      {required String letter, required bool active, required bool isToday}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8BE0A4), Color(0xFF3FA66B)],
                  )
                : null,
            color: active ? null : Colors.black.withValues(alpha: 0.18),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5)
                : Border.all(
                    color: Colors.white.withValues(alpha: isToday ? 0.8 : 0.3),
                    width: isToday ? 1.8 : 1.2),
          ),
          child: active
              ? const Icon(Icons.eco, size: 18, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 5),
        Text(letter,
            style: TextStyle(
                color: Colors.white.withValues(alpha: isToday ? 1 : 0.65),
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}

/// Menggambar tetesan air yang jatuh dari ujung corong penyiram.
class _DropsPainter extends CustomPainter {
  final Animation<double> t;
  final double s; // dp per unit
  _DropsPainter(this.t, this.s) : super(repaint: t);

  static const int _count = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final spout = _rotateAround(_spout, _pivot, _swingAngle(t.value)) * s;
    // Air jatuh sampai ke puncak tanaman di bawah.
    final endY = size.height - 150 * s;
    final fall = math.max(40.0, endY - spout.dy);
    final paint = Paint();

    for (var i = 0; i < _count; i++) {
      final p = (t.value * 6 + i / _count) % 1.0; // umur tetes, 0..1
      final sway = ((i % 3) - 1) * 10 * s * p;
      final x = spout.dx - 22 * s * p + sway;
      final y = spout.dy + (0.25 * p + 0.75 * p * p) * fall;
      final double alpha =
          (p < 0.12 ? p / 0.12 : 1 - math.pow(p, 3)).clamp(0.0, 1.0).toDouble();
      paint.color = const Color(0xFFBFE8FF).withValues(alpha: 0.9 * alpha);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 4, height: 7), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DropsPainter old) => old.s != s;
}