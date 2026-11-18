import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/care_rules.dart';
import '../models/plant.dart';

/// Notifikasi terjadwal di layar kunci: siap pindah tanah, bisa panen,
/// mulai pantau buah, dan pengingat harian.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'perawatan',
      'Pengingat perawatan',
      channelDescription: 'Pengingat perawatan dan panen tanaman',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      // Zona waktu tetap WIB. Untuk WITA atau WIT perlu disesuaikan.
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      // Data tanaman belum tersimpan permanen, jadi mulai dari bersih.
      await _plugin.cancelAll();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  // Satu id per tanaman (maksimal satu pengingat yang menunggu).
  int _id(Plant p) => 100 + (p.id.hashCode.abs() % 100000) * 10;

  Future<void> _at(int id, DateTime when, String title, String body) async {
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Menjadwalkan pengingat berikutnya untuk satu tanaman.
  Future<void> schedule(Plant p) async {
    if (!_ready) return;
    try {
      final id = _id(p);
      await _plugin.cancel(id: id);
      final r = p.rules;
      if (r == null) return;

      DateTime? when;
      String? title;
      String? body;
      if (p.stage == PlantStage.semai) {
        when = p.stageStart.add(Duration(days: p.semaiLength));
        title = 'Siap pindah tanah';
        body = '${p.name} sudah selesai masa semai.';
      } else if (r.harvestMode == HarvestMode.cutCycle && !p.mustPull) {
        final days = p.cutCount == 0 ? r.harvestFromDays : r.regrowDays;
        when = (p.lastCutAt ?? p.stageStart).add(Duration(days: days));
        title = 'Bisa dipanen';
        body = '${p.name} sudah siap dipanen.';
      } else if (r.harvestMode == HarvestMode.pick && p.pickCount == 0) {
        when = p.stageStart.add(Duration(days: r.harvestFromDays));
        title = 'Waktunya pantau buah';
        body = '${p.name} sudah bisa dipantau buahnya.';
      }
      if (when == null || title == null || body == null) return;

      // Kirim pukul 08.00 pada harinya.
      await _at(id, DateTime(when.year, when.month, when.day, 8), title, body);
    } catch (_) {}
  }

  Future<void> cancelFor(Plant p) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id(p));
    } catch (_) {}
  }

  /// Pengingat harian pukul 07.00, hanya aktif kalau ada tanaman.
  Future<void> syncDaily(bool hasPlants) async {
    if (!_ready) return;
    try {
      if (!hasPlants) {
        await _plugin.cancel(id: 1);
        return;
      }
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
      if (first.isBefore(now)) first = first.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: 1,
        title: 'Waktunya cek kebunmu',
        body: 'Jangan lupa siram dan rawat tanamanmu hari ini.',
        scheduledDate: first,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  /// Hanya untuk uji coba: notifikasi beberapa detik lagi.
  Future<void> testIn(int seconds) async {
    if (!_ready) return;
    try {
      await _at(
        2,
        DateTime.now().add(Duration(seconds: seconds)),
        'Uji notifikasi',
        'Kalau ini muncul, notifikasi terjadwal berfungsi.',
      );
    } catch (_) {}
  }
}

/// Satu objek yang dipakai bersama oleh seluruh aplikasi.
final notificationService = NotificationService();