import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/plant_store.dart';
import '../data/profile_store.dart';
import '../services/weather_service.dart';
import 'explore_page.dart';
import 'login_page.dart';
import 'monitoring_page.dart';
import 'recap_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isNotifOn = true;

  @override
  void initState() {
    super.initState();
    weatherStore.init();
  }

  Widget _avatar(double radius) {
    final path = profileStore.photoPath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage: path == null ? null : FileImage(File(path)),
      child: path == null
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : null,
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: profileStore,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _changePhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _avatar(44),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: AppColors.primary, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(profileStore.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(profileStore.email,
                  style: TextStyle(color: context.muted)),
              const SizedBox(height: 16),
              _sheetTile(Icons.person_outline, 'Ubah data diri',
                  'Nama dan email', _editProfile),
              _sheetTile(
                  Icons.lock_outline, 'Ubah kata sandi', null, _changePassword),
              _sheetTile(Icons.logout, 'Keluar', null, _logout, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePhoto() async {
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

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked != null) profileStore.setPhoto(picked.path);
  }

  Future<void> _editProfile() async {
    final nameC = TextEditingController(text: profileStore.name);
    final emailC = TextEditingController(text: profileStore.email);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah data diri'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Format email tidak valid',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      profileStore.updateInfo(
          name: nameC.text.trim(), email: emailC.text.trim());
    }
  }

  Future<void> _changePassword() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah kata sandi'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldC,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Kata sandi lama'),
                  validator: (v) =>
                      v == profileStore.password ? null : 'Kata sandi lama salah',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newC,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Kata sandi baru'),
                  validator: (v) => (v == null || v.length < 5)
                      ? 'Minimal 5 karakter'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmC,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Ulangi kata sandi baru'),
                  validator: (v) =>
                      v == newC.text ? null : 'Kata sandi tidak sama',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true) {
      profileStore.changePassword(newC.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diubah.')),
      );
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu akan kembali ke halaman masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Hapus semua halaman dari tumpukan, lalu buka halaman masuk.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  Widget _settingItem(IconData icon, String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.accent),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 6),
          control,
        ],
      ),
    );
  }

  Widget _settingsDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.5,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pengaturan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _settingItem(
                Icons.dark_mode_outlined,
                'Tema gelap',
                Switch(
                  value: context.isDark,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) =>
                      themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              Divider(color: context.line),
              _settingItem(
                Icons.notifications_none,
                'Notifikasi',
                Switch(
                  value: _isNotifOn,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isNotifOn = v),
                ),
              ),
              Divider(color: context.line),
              _settingItem(
                Icons.language,
                'Bahasa',
                Text('Indonesia', style: TextStyle(color: context.muted)),
              ),
              Divider(color: context.line),
              _settingItem(
                Icons.location_on_outlined,
                'Lokasi cuaca',
                ListenableBuilder(
                  listenable: weatherStore,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weatherStore.usingGps
                            ? '${weatherStore.city} (lokasi HP)'
                            : weatherStore.city,
                        style: TextStyle(color: context.muted, fontSize: 12),
                      ),
                      InkWell(
                        onTap: _useGps,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Pakai lokasi HP',
                            style: TextStyle(
                              color: context.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _changeCity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Cari kota',
                            style: TextStyle(
                              color: context.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : context.accent),
      title: Text(title,
          style: TextStyle(color: danger ? AppColors.danger : null)),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bg,
      endDrawer: _settingsDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListenableBuilder(
                          listenable: profileStore,
                          builder: (context, _) => Text(
                            'Hi ${profileStore.name},',
                            style: TextStyle(color: context.muted),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Mari kita lihat kebunmu',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: context.ink)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showProfileSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListenableBuilder(
                        listenable: profileStore,
                        builder: (context, _) => _avatar(16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: context.ink),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: plantStore,
                builder: (context, _) => _weeklyCard(),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: weatherStore,
                builder: (context, _) => _weatherTile(),
              ),
              const SizedBox(height: 28),
              Text('Lakukan aktivitasmu',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.ink)),
              const SizedBox(height: 12),
              _menuTile(Icons.grass, 'Monitoring Kebun',
                  'Pantau dan kelola semua tanamanmu',
                  () => MonitoringPage(),
                  featured: true),
              _menuTile(Icons.insights_outlined, 'Rekap Kita',
                  'Lihat perkembangan kebunmu', () => RecapPage()),
              _menuTile(Icons.explore_outlined, 'Jelajah',
                  'Pindai tanaman dan belajar berkebun',
                  () => ExplorePage()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useGps() async {
    Navigator.pop(context); // tutup panel pengaturan
    final error = await weatherStore.useDeviceLocation();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _changeCity() async {
    Navigator.pop(context); // tutup panel pengaturan
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi cuaca'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama kota, misalnya Bandung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Cari'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mencari "$name"...')),
    );
    final error = await weatherStore.setCity(name);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _weatherTile() {
    final w = weatherStore.today;
    IconData icon = Icons.cloud_outlined;
    String title = weatherStore.city;
    String detail;
    if (w == null) {
      title = 'Cuaca';
      detail = weatherStore.loading
          ? 'Memuat cuaca...'
          : (weatherStore.error ?? 'Cuaca belum tersedia.');
    } else {
      detail = '${w.tempMax.round()}°C, peluang hujan ${w.rainChance}%';
      if (w.rainy) {
        icon = Icons.water_drop_outlined;
      } else if (w.hot) {
        icon = Icons.wb_sunny_outlined;
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: context.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(color: context.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyCard() {
    const letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
    final today = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final counts = [for (final d in days) plantStore.activityOn(d)];
    final total = counts.fold<int>(0, (a, b) => a + b);

    String summary;
    if (plantStore.totalPlantsEver == 0) {
      summary =
          'Belum ada tanaman. Tambah tanaman di Monitoring Kebun untuk mulai mencatat.';
    } else if (total == 0) {
      summary = 'Belum ada catatan perawatan minggu ini.';
    } else {
      summary = '$total catatan perawatan dalam 7 hari terakhir.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1B4331) : AppColors.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7 hari terakhir',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          const Text('Aktivitas kebunmu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < days.length; i++)
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: counts[i] > 0
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: counts[i] > 0
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: counts[i] > 0
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(letters[days[i].weekday - 1],
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            summary,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
      IconData icon, String title, String subtitle, Widget Function() page,
      {bool featured = false}) {
    final fg = featured ? Colors.white : context.ink;
    final sub = featured ? Colors.white70 : context.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: featured ? AppColors.primary : context.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => page())),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: featured ? AppColors.primary : context.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: featured
                        ? Colors.white.withValues(alpha: 0.18)
                        : context.tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: featured ? Colors.white : context.accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: fg)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(color: sub, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}