import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pil kecil berisi info singkat, misalnya "3 tanaman".
class FeatureChip {
  final IconData icon;
  final String text;
  const FeatureChip(this.icon, this.text);
}

/// Tombol fitur di beranda: berwarna gradasi, ada ikon, judul, keterangan,
/// dan info singkat yang diambil dari data kebun.
///
/// [foreground] = warna teks. Pakai gelap untuk latar terang (misalnya kuning).
/// [compact] = versi kecil untuk dipasang berdampingan dua kolom.
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color foreground;
  final List<FeatureChip> chips;
  final bool compact;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
    this.foreground = Colors.white,
    this.chips = const [],
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 20 : 24);
    final pad = compact ? 16.0 : 20.0;
    final badge = compact ? 40.0 : 48.0;
    final glass = foreground.withValues(alpha: 0.16);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Ikon besar samar sebagai hiasan.
                Positioned(
                  right: compact ? -12 : -6,
                  bottom: compact ? -14 : -22,
                  child: Transform.rotate(
                    angle: -math.pi / 14,
                    child: Icon(icon,
                        size: compact ? 92 : 128,
                        color: foreground.withValues(alpha: 0.12)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: badge,
                            height: badge,
                            decoration: BoxDecoration(
                              color: glass,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: foreground),
                          ),
                          const Spacer(),
                          Container(
                            width: 30,
                            height: 30,
                            decoration:
                                BoxDecoration(color: glass, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 18, color: foreground),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Text(title,
                          style: TextStyle(
                              color: foreground,
                              fontSize: compact ? 16 : 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: foreground.withValues(alpha: 0.85),
                              fontSize: 13)),
                      if (chips.isNotEmpty) ...[
                        SizedBox(height: compact ? 12 : 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in chips) _chip(c, foreground, glass),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(FeatureChip c, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(c.text,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}