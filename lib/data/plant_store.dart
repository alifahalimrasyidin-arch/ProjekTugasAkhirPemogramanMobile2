import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/care_rules.dart';
import '../models/plant.dart';
import '../services/notification_service.dart';

/// Catatan panen, dipakai untuk statistik dan Rekap.
class HarvestRecord {
  final String id;
  final String name;
  final String type;
  final PlantCategory category;
  final DateTime at;
  final String how; // cara panen: panen potong, cabut akar, atau petik buah

  HarvestRecord(this.name, this.type, this.category, this.how,
      {DateTime? at, String? id})
      : at = at ?? DateTime.now(),
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'category': category.name,
        'how': how,
        'at': at.millisecondsSinceEpoch,
      };

  factory HarvestRecord.fromMap(Map<String, dynamic> m) => HarvestRecord(
        m['name'] as String,
        m['type'] as String,
        PlantCategory.values.byName(m['category'] as String),
        m['how'] as String,
        at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt()),
        id: m['id'] as String?,
      );
}

/// Menyimpan daftar tanaman milik user dan menyinkronkannya ke Firestore.
/// Data tiap user ada di: users/{uid}/plants, users/{uid}/harvests,
/// dan users/{uid}/meta/stats.
/// Setiap kali data berubah, layar yang mendengarkan ikut diperbarui.
class PlantStore extends ChangeNotifier {
  final List<Plant> _plants = [];
  final List<HarvestRecord> _harvests = [];
  final List<DateTime> _activity = []; // waktu setiap aksi perawatan
  int _totalAdded = 0;
  String? _uid; // null = belum login, data tidak disimpan ke cloud

  List<Plant> get plants => List.unmodifiable(_plants);
  List<HarvestRecord> get harvests => List.unmodifiable(_harvests);

  // Statistik untuk beranda dan Rekap
  int get totalPlantsEver => _totalAdded;
  int get totalCareActions => _activity.length;
  int get totalHarvests => _harvests.length;

  /// Jumlah aksi perawatan pada satu hari.
  int activityOn(DateTime day) => _activity
      .where((d) => d.year == day.year && d.month == day.month && d.day == day.day)
      .length;

  // ---------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>>? get _userDoc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  void _report(Object e) => debugPrint('Firestore: $e');

  /// Muat semua data milik [uid] dari Firestore. Dipanggil setelah login.
  Future<void> load(String uid) async {
    _uid = uid;
    _plants.clear();
    _harvests.clear();
    _activity.clear();
    _totalAdded = 0;

    const wait = Duration(seconds: 10);
    try {
      final doc = _userDoc!;
      final plantsSnap = await doc.collection('plants').get().timeout(wait);
      final harvestSnap = await doc.collection('harvests').get().timeout(wait);
      final statsSnap =
          await doc.collection('meta').doc('stats').get().timeout(wait);

      for (final d in plantsSnap.docs) {
        try {
          _plants.add(Plant.fromMap(d.data()));
        } catch (e) {
          _report('tanaman ${d.id} dilewati: $e');
        }
      }
      for (final d in harvestSnap.docs) {
        try {
          _harvests.add(HarvestRecord.fromMap(d.data()));
        } catch (e) {
          _report('panen ${d.id} dilewati: $e');
        }
      }
      _harvests.sort((a, b) => a.at.compareTo(b.at));

      final stats = statsSnap.data();
      if (stats != null) {
        _totalAdded = (stats['totalAdded'] as num?)?.toInt() ?? 0;
        for (final ms in (stats['activity'] as List?) ?? const []) {
          _activity.add(
              DateTime.fromMillisecondsSinceEpoch((ms as num).toInt()));
        }
      }
      if (_totalAdded < _plants.length) _totalAdded = _plants.length;

      for (final p in _plants) {
        notificationService.schedule(p);
      }
      notificationService.syncDaily(_plants.isNotEmpty);
    } catch (e) {
      _report('gagal memuat data: $e');
    }
    notifyListeners();
  }

  /// Kosongkan data di memori saat logout (data di cloud tetap aman).
  void clear() {
    for (final p in _plants) {
      notificationService.cancelFor(p);
    }
    notificationService.syncDaily(false);
    _plants.clear();
    _harvests.clear();
    _activity.clear();
    _totalAdded = 0;
    _uid = null;
    notifyListeners();
  }

  // Penyimpanan sengaja tidak di-await agar layar tidak menunggu jaringan.
  // Firestore menyimpan antrean saat offline dan mengirimnya ketika online.

  void _savePlant(Plant p) {
    _userDoc
        ?.collection('plants')
        .doc(p.id)
        .set(p.toMap())
        .catchError(_report);
  }

  void _deletePlant(Plant p) {
    _userDoc?.collection('plants').doc(p.id).delete().catchError(_report);
  }

  void _addHarvest(Plant p, String how) {
    final h = HarvestRecord(p.name, p.type, p.category, how);
    _harvests.add(h);
    _userDoc
        ?.collection('harvests')
        .doc(h.id)
        .set(h.toMap())
        .catchError(_report);
  }

  void _logActivity() {
    final now = DateTime.now();
    _activity.add(now);
    _userDoc?.collection('meta').doc('stats').set({
      'activity': FieldValue.arrayUnion([now.millisecondsSinceEpoch]),
      'totalAdded': _totalAdded,
    }, SetOptions(merge: true)).catchError(_report);
  }

  void _saveTotalAdded() {
    _userDoc
        ?.collection('meta')
        .doc('stats')
        .set({'totalAdded': _totalAdded}, SetOptions(merge: true))
        .catchError(_report);
  }

  // ---------------------------------------------------------------------
  // Aksi pengguna
  // ---------------------------------------------------------------------

  void add(Plant plant) {
    final r = careRulesOf(plant.careType);
    if (r != null && r.hasSemai) plant.withSemai = true;
    plant.stage = plant.withSemai ? PlantStage.semai : PlantStage.tumbuh;
    plant.stageStart = plant.plantedAt;
    _plants.add(plant);
    _totalAdded++;
    _savePlant(plant);
    _saveTotalAdded();
    notificationService.schedule(plant);
    notificationService.syncDaily(true);
    notifyListeners();
  }

  void logCare(Plant plant, CareKind kind) {
    plant.logs.add(CareLog(kind));
    _logActivity();
    _savePlant(plant);
    notifyListeners();
  }

  /// Dipakai saat user pindah tanah, atau melewati masa semai.
  void startGrowing(Plant plant) {
    plant.stage = PlantStage.tumbuh;
    plant.stageStart = DateTime.now();
    _savePlant(plant);
    notificationService.schedule(plant);
    notifyListeners();
  }

  /// Panen potong: tanaman tumbuh lagi, siklus berulang.
  void harvestCut(Plant plant) {
    plant.cutCount++;
    plant.lastCutAt = DateTime.now();
    plant.logs.add(CareLog(CareKind.panenPotong));
    _logActivity();
    _addHarvest(plant, 'panen potong');
    _savePlant(plant);
    notificationService.schedule(plant);
    notifyListeners();
  }

  /// Tanaman buah: mencatat satu kali petik buah (bisa berkali-kali).
  void pickFruit(Plant plant) {
    plant.logs.add(CareLog(CareKind.petikBuah));
    _logActivity();
    _addHarvest(plant, 'petik buah');
    _savePlant(plant);
    notifyListeners();
  }

  /// Panen cabut akar: panen berhasil, card tanaman dihapus.
  void harvestPull(Plant plant) {
    _addHarvest(plant, 'cabut akar');
    _logActivity();
    _plants.remove(plant);
    _deletePlant(plant);
    notificationService.cancelFor(plant);
    notificationService.syncDaily(_plants.isNotEmpty);
    notifyListeners();
  }

  /// Tanaman mati atau tidak layak dirawat: datanya dihapus.
  void remove(Plant plant) {
    _plants.remove(plant);
    _deletePlant(plant);
    notificationService.cancelFor(plant);
    notificationService.syncDaily(_plants.isNotEmpty);
    notifyListeners();
  }

  void addNote(Plant plant, String text) {
    plant.notes.add(PlantNote(text));
    _savePlant(plant);
    notifyListeners();
  }

  void addPhoto(Plant plant, String path) {
    plant.photoPaths.add(path);
    _savePlant(plant);
    notifyListeners();
  }

  /// Hanya untuk uji coba: memajukan waktu tanaman.
  void debugShift(Plant plant, int days) {
    final d = Duration(days: days);
    plant.stageStart = plant.stageStart.subtract(d);
    if (plant.lastCutAt != null) {
      plant.lastCutAt = plant.lastCutAt!.subtract(d);
    }
    final shifted =
        plant.logs.map((l) => CareLog(l.kind, l.at.subtract(d))).toList();
    plant.logs
      ..clear()
      ..addAll(shifted);
    _savePlant(plant);
    notifyListeners();
  }
}

/// Satu objek yang dipakai bersama oleh seluruh aplikasi.
final plantStore = PlantStore();