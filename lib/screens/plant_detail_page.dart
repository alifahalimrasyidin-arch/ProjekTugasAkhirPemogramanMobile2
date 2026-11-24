import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/plant_store.dart';
import '../models/care_rules.dart';
import '../models/plant.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

/// Halaman detail satu tanaman: status, tugas hari ini, panen,
/// catatan, foto, dan tanaman mati.
///
/// Centang tugas, catatan, dan foto ditampung dulu sebagai draf.
/// Semuanya baru tersimpan ke data tanaman saat tombol "Simpan" ditekan.
class PlantDetailPage extends StatefulWidget {
  final Plant plant;
  const PlantDetailPage({super.key, required this.plant});

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  Plant get plant => widget.plant;

  // Draf yang belum disimpan.
  final Set<CareKind> _draftTasks = {};
  final List<String> _draftPhotos = [];
  final TextEditingController _noteC = TextEditingController();
  bool _discard = false; // true = user sudah setuju membuang draf

  static const _noteMax = 300;

  bool get _hasNote => _noteC.text.trim().isNotEmpty;
  int get _draftCount =>
      _draftTasks.length + (_hasNote ? 1 : 0) + _draftPhotos.length;
  bool get _dirty => _draftCount > 0;

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _discard,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDialog(
          context,
          icon: Icons.edit_off_outlined,
          color: AppColors.harvest,
          title: 'Buang perubahan?',
          text: 'Ada perawatan, catatan, atau foto yang belum disimpan. '
              'Kalau keluar sekarang, semuanya hilang.',
          okLabel: 'Buang',
          cancelLabel: 'Lanjut mengisi',
        );
        if (ok != true || !mounted) return;
        setState(() => _discard = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      },
      child: Scaffold(
        appBar: AppBar(title: Text(plant.name)),
        bottomNavigationBar: _saveBar(context),
        body: ListenableBuilder(
          listenable: Listenable.merge([plantStore, weatherStore]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _header(),
              const SizedBox(height: 20),
              ..._careSection(context),
              const SizedBox(height: 24),
              ..._notesSection(context),
              const SizedBox(height: 24),
              ..._photoSection(context),
              const SizedBox(height: 28),
              _deadCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _header() {
    final day = DateTime.now().difference(plant.plantedAt).inDays + 1;
    final stageText = plant.stage == PlantStage.semai ? 'Masa semai' : 'Tumbuh';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: plant.category.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(plant.category.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${plant.type}, ${plant.category.label}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
                Text(
                  stageText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Hari ke-$day',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  // ---------- Perawatan ----------
  List<Widget> _careSection(BuildContext context) {
    final rules = plant.rules;
    if (rules == null) {
      return [
        _info(context, Icons.construction_outlined,
            'Fitur perawatan untuk jenis ini segera hadir.'),
      ];
    }

    if (plant.stage == PlantStage.semai) {
      final total = plant.semaiLength;
      final progress =
          total == 0 ? 0.0 : ((plant.daysInStage + 1) / total).clamp(0.0, 1.0);
      return [
        _title('Masa semai'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: context.line,
                  color: plant.category.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('Hari ke-${plant.daysInStage + 1} dari $total',
                style: TextStyle(color: context.muted, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),
        if (plant.semaiReady)
          _alert(
            context,
            Icons.notifications_active_outlined,
            'Siap pindah tanah',
            'Masa semai sudah selesai. Pindahkan bibit ke tanah.',
            action: 'Sudah pindah tanah',
            onTap: () => _confirmStartGrowing(context, early: false),
          ),
        _checklist(context, rules.semaiTasks),
        if (!plant.semaiReady) ...[
          const SizedBox(height: 4),
          _skipSemaiCard(context),
        ],
      ];
    }

    final hasHarvest = rules.harvestMode != HarvestMode.none;
    return [
      _title(hasHarvest ? 'Perawatan hari ini' : 'Perawatan'),
      const SizedBox(height: 8),
      if (rules.lightNote != null) ...[
        _info(context, Icons.wb_sunny_outlined, rules.lightNote!),
        const SizedBox(height: 12),
      ],
      if (plant.category != PlantCategory.hidroponik)
        ..._weatherNotes(context),
      if (plant.mustPull)
        _alert(
          context,
          Icons.warning_amber_rounded,
          'Wajib cabut akar',
          'Sudah ${rules.maxCuts} kali panen potong. Tanaman perlu dicabut akarnya.',
        )
      else if (plant.canHarvest)
        _alert(
          context,
          Icons.notifications_active_outlined,
          'Sudah bisa dipanen',
          plant.cutCount == 0
              ? 'Tanaman sudah cukup umur untuk dipanen.'
              : 'Tanaman tumbuh lagi dan siap dipanen.',
        )
      else if (plant.canPick && plant.pickCount == 0)
        _alert(
          context,
          Icons.notifications_active_outlined,
          'Waktunya pantau buah',
          'Mulai sekarang kamu bisa memangkas dan memantau buah. Catat setiap kali memetik.',
        ),
      _checklist(context, rules.tasks),
      if (plant.canHarvest || plant.mustPull) ...[
        const SizedBox(height: 16),
        _title('Panen'),
        const SizedBox(height: 8),
        if (!plant.mustPull)
          ElevatedButton.icon(
            onPressed: () => _confirmCut(context),
            icon: const Icon(Icons.content_cut),
            label: Text(
                'Panen potong (${plant.cutCount + 1} dari ${rules.maxCuts})'),
          ),
        if (!plant.mustPull) const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _confirmPull(context),
          icon: const Icon(Icons.eco),
          label: const Text('Panen cabut akar'),
        ),
      ],
      if (plant.canPick) ...[
        const SizedBox(height: 16),
        _title('Panen'),
        const SizedBox(height: 4),
        Text('Sudah dipetik ${plant.pickCount} kali',
            style: TextStyle(color: context.muted)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _confirmPick(context),
          icon: const Icon(Icons.shopping_basket_outlined),
          label: const Text('Catat petik buah'),
        ),
      ],
    ];
  }

  /// Catatan cuaca: hujan menunda penyiraman, panas memicu peringatan.
  List<Widget> _weatherNotes(BuildContext context) {
    final w = weatherStore.today;
    if (w == null) return [];
    final hasSiram =
        plant.rules?.tasks.any((t) => t.kind == CareKind.siram) ?? false;
    final siramSaved = plant.doneToday(CareKind.siram);
    final siramDraft = _draftTasks.contains(CareKind.siram);
    return [
      if (w.rainy && hasSiram)
        _weatherBanner(
          context,
          icon: Icons.water_drop,
          title: 'Diperkirakan hujan hari ini',
          text:
              'Penyiraman bisa ditunda kalau tanamanmu ada di luar ruangan.',
          badgeIcon: Icons.umbrella_outlined,
          badge: '${w.rainChance}%',
          colors: const [Color(0xFF1F5F99), Color(0xFF4DA8DA)],
          actionLabel: siramSaved ? null : 'Anggap sudah disiram hujan',
          active: siramDraft,
          activeLabel: 'Dicatat sudah disiram hujan',
          onTap: () => setState(() {
            if (siramDraft) {
              _draftTasks.remove(CareKind.siram);
            } else {
              _draftTasks.add(CareKind.siram);
            }
          }),
        ),
      if (w.hot && plant.careType == CareType.hiasSulit)
        _weatherBanner(
          context,
          icon: Icons.wb_sunny,
          title: 'Panas tinggi hari ini',
          text: 'Pindahkan tanaman ke tempat teduh supaya tidak layu.',
          badgeIcon: Icons.thermostat,
          badge: '${w.tempMax.round()}°C',
          colors: const [Color(0xFFD9741E), Color(0xFFF0A63C)],
        ),
    ];
  }

  /// Banner cuaca berwarna gradasi, dengan lencana angka dan tombol opsional.
  Widget _weatherBanner(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
    required IconData badgeIcon,
    required String badge,
    required List<Color> colors,
    String? actionLabel,
    String activeLabel = '',
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -20,
              child: Icon(icon,
                  size: 120, color: Colors.white.withValues(alpha: 0.13)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(badge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(text,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4)),
                  if (actionLabel != null && onTap != null) ...[
                    const SizedBox(height: 14),
                    if (active)
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(activeLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: onTap,
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white),
                            child: const Text('Batalkan'),
                          ),
                        ],
                      )
                    else
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.water_drop_outlined,
                                    size: 18, color: colors.first),
                                const SizedBox(width: 8),
                                Text(actionLabel,
                                    style: TextStyle(
                                        color: colors.first,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Daftar tugas rutin. Centang masuk ke draf, baru tersimpan lewat tombol Simpan.
  Widget _checklist(BuildContext context, List<RoutineTask> tasks) {
    final visible = tasks
        .where((t) =>
            t.fromDay <= plant.daysInStage &&
            (plant.doneToday(t.kind) || plant.dueNow(t)))
        .toList();
    if (visible.isEmpty) {
      return _info(context, Icons.check_circle_outline, 'Tidak ada tugas hari ini.');
    }
    return Column(
      children: [for (final t in visible) _taskTile(context, t)],
    );
  }

  Widget _taskTile(BuildContext context, RoutineTask t) {
    final saved = plant.doneToday(t.kind);
    final drafted = _draftTasks.contains(t.kind);
    final on = saved || drafted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: on ? context.tint : context.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: saved
              ? null
              : () => setState(() {
                    if (drafted) {
                      _draftTasks.remove(t.kind);
                    } else {
                      _draftTasks.add(t.kind);
                    }
                  }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? context.accent.withValues(alpha: 0.5) : context.line),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? context.accent : Colors.transparent,
                    border: Border.all(
                        color: on ? context.accent : context.muted, width: 2),
                  ),
                  child: on
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          t.everyDays <= 1
                              ? 'Setiap hari'
                              : 'Setiap ${t.everyDays} hari',
                          style: TextStyle(color: context.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (saved)
                  _pill('Tersimpan', context.accent)
                else if (drafted)
                  _pill('Belum disimpan', const Color(0xFFB7791F)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  /// Kartu "Lewati masa semai" (pengganti tombol teks lama).
  Widget _skipSemaiCard(BuildContext context) {
    final c = plant.category.color;
    return Material(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _confirmStartGrowing(context, early: true),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c, c.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fast_forward_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lewati masa semai',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Langsung ke tahap tumbuh',
                        style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStartGrowing(BuildContext context,
      {required bool early}) async {
    final ok = await _confirmDialog(
      context,
      icon: Icons.fast_forward_rounded,
      color: plant.category.color,
      title: early ? 'Lewati masa semai?' : 'Sudah pindah ke tanah?',
      text: early
          ? 'Masa semai belum selesai (baru hari ke-${plant.daysInStage + 1} '
              'dari ${plant.semaiLength}). Tanaman langsung dianggap masuk '
              'tahap tumbuh. Ini tidak bisa dibatalkan.'
          : 'Tanaman akan masuk ke tahap tumbuh. Ini tidak bisa dibatalkan.',
      okLabel: early ? 'Ya, lewati' : 'Ya, sudah',
    );
    if (ok != true || !mounted) return;
    plantStore.startGrowing(plant);
  }

  Future<void> _confirmCut(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      icon: Icons.content_cut,
      color: AppColors.primary,
      title: 'Panen potong?',
      text:
          'Panen ke-${plant.cutCount + 1} akan dicatat dan tanaman tumbuh lagi.',
      okLabel: 'Ya, panen',
      cancelLabel: 'Tidak',
    );
    if (ok != true || !mounted) return;
    plantStore.harvestCut(plant);
  }

  Future<void> _confirmPick(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      icon: Icons.shopping_basket_outlined,
      color: AppColors.primary,
      title: 'Catat petik buah?',
      text: 'Satu kali petik buah akan dicatat untuk tanaman ini.',
      okLabel: 'Ya, catat',
      cancelLabel: 'Tidak',
    );
    if (ok != true || !mounted) return;
    plantStore.pickFruit(plant);
  }

  Future<void> _confirmPull(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      icon: Icons.eco,
      color: AppColors.primary,
      title: 'Panen dan cabut akar?',
      text: 'Tanaman dianggap berhasil dipanen dan kartunya dihapus dari daftar.',
      okLabel: 'Panen',
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    plantStore.harvestPull(plant);
    setState(() => _discard = true);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Panen berhasil dicatat.')),
    );
  }

  // ---------- Catatan (formulir) ----------
  List<Widget> _notesSection(BuildContext context) {
    return [
      Row(
        children: [
          _title('Catatan'),
          const SizedBox(width: 8),
          _pill('Opsional', context.muted),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _noteC,
        maxLines: 4,
        minLines: 3,
        maxLength: _noteMax,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tulis kondisi tanamanmu hari ini...',
          alignLabelWithHint: true,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(bottom: 44),
            child: Icon(Icons.edit_note_rounded),
          ),
        ),
      ),
      if (plant.notes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Catatan sebelumnya',
            style: TextStyle(
                color: context.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final n in plant.notes.reversed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmt(n.at),
                    style: TextStyle(color: context.muted, fontSize: 11.5)),
                const SizedBox(height: 4),
                Text(n.text, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
      ],
    ];
  }

  String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}.${two(d.minute)}';
  }

  // ---------- Foto (opsional) ----------
  List<Widget> _photoSection(BuildContext context) {
    return [
      Row(
        children: [
          _title('Foto'),
          const SizedBox(width: 8),
          _pill('Opsional', context.muted),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _addPhotoTile(context),
            for (final path in _draftPhotos) _photoTile(path, draft: true),
            for (final path in plant.photoPaths.reversed)
              _photoTile(path, draft: false),
          ],
        ),
      ),
    ];
  }

  Widget _addPhotoTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: context.tint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickPhoto,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.accent.withValues(alpha: 0.45)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: context.accent),
                const SizedBox(height: 6),
                Text('Tambah',
                    style: TextStyle(
                        color: context.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoTile(String path, {required bool draft}) {
    final image = kIsWeb
        ? Image.network(path, width: 92, height: 92, fit: BoxFit.cover)
        : Image.file(File(path), width: 92, height: 92, fit: BoxFit.cover);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(18), child: image),
          if (draft) ...[
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB7791F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Baru',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => setState(() => _draftPhotos.remove(path)),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: context.accent),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: context.accent),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _draftPhotos.add(picked.path));
    }
  }

  // ---------- Tanaman mati ----------
  Widget _deadCard(BuildContext context) {
    const red = AppColors.danger;
    return Material(
      color: red.withValues(alpha: context.isDark ? 0.16 : 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _confirmDead(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.heart_broken_outlined, color: red),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tanaman mati atau tidak layak?',
                        style: TextStyle(
                            color: red,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Hapus tanaman ini dari kebunmu',
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: red),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDead(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      icon: Icons.delete_forever_outlined,
      color: AppColors.danger,
      title: 'Hapus "${plant.name}"?',
      text: 'Tanaman dihapus dari kebunmu bersama datanya. '
          'Tindakan ini tidak bisa dibatalkan.',
      extra: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${plant.logs.length} catatan perawatan, '
          '${plant.notes.length} catatan tulisan, '
          '${plant.photoPaths.length} foto',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
      okLabel: 'Ya, hapus',
    );
    if (ok != true || !mounted) return;
    plantStore.remove(plant);
    setState(() => _discard = true);
    Navigator.pop(context);
  }

  // ---------- Tombol simpan ----------
  Widget _saveBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Color(0xFFB7791F)),
                      const SizedBox(width: 6),
                      Text('$_draftCount perubahan belum disimpan',
                          style: TextStyle(color: context.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _dirty ? () => _save(context) : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan perawatan hari ini'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelOf(CareKind kind) {
    final r = plant.rules;
    if (r != null) {
      for (final t in [...r.semaiTasks, ...r.tasks]) {
        if (t.kind == kind) return t.label;
      }
    }
    return kind.name;
  }

  Future<void> _save(BuildContext context) async {
    final note = _noteC.text.trim();
    final ok = await _confirmDialog(
      context,
      icon: Icons.save_outlined,
      color: AppColors.primary,
      title: 'Simpan perawatan hari ini?',
      text: 'Yang akan disimpan:',
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in _draftTasks) _summaryLine(Icons.check_circle, _labelOf(k)),
          if (note.isNotEmpty) _summaryLine(Icons.edit_note_rounded, '1 catatan'),
          if (_draftPhotos.isNotEmpty)
            _summaryLine(Icons.photo_outlined, '${_draftPhotos.length} foto'),
        ],
      ),
      okLabel: 'Simpan',
      cancelLabel: 'Cek lagi',
    );
    if (ok != true || !mounted) return;

    for (final k in _draftTasks) {
      plantStore.logCare(plant, k);
    }
    if (note.isNotEmpty) plantStore.addNote(plant, note);
    for (final p in _draftPhotos) {
      plantStore.addPhoto(plant, p);
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _draftTasks.clear();
      _draftPhotos.clear();
      _noteC.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perawatan hari ini tersimpan.')),
    );
  }

  Widget _summaryLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  // ---------- Komponen kecil ----------
  Widget _title(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      );

  Widget _info(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  Widget _alert(
    BuildContext context,
    IconData icon,
    String title,
    String text, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.harvest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(height: 1.4)),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onTap, child: Text(action)),
          ],
        ],
      ),
    );
  }

  /// Dialog konfirmasi seragam: ikon bulat, judul, keterangan, tombol batal dan ya.
  Future<bool?> _confirmDialog(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    required String okLabel,
    String cancelLabel = 'Batal',
    Widget? extra,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
            if (extra != null) ...[
              const SizedBox(height: 12),
              extra,
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}