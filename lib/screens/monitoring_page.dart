import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/plant.dart';
import 'add_plant_form.dart';
import '../data/plant_store.dart';
import '../widgets/plant_card.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  // State untuk filter grafik
  String _selectedTimeFilter = 'Minggu Ini';
  final List<String> _timeFilters = ['Minggu Ini', 'Bulan Ini', '6 Bulan Ini'];

  // State untuk filter jenis tanaman (null = semua)
  PlantCategory? _categoryFilter;

  /// Data grafik: jumlah aksi perawatan per kelompok waktu.
  List<_Bar> _chartBars() {
    final today = DateTime.now();
    final bars = <_Bar>[];

    if (_selectedTimeFilter == 'Minggu Ini') {
      // Senin sampai Minggu pada minggu ini
      const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final monday = today.subtract(Duration(days: today.weekday - 1));
      for (var i = 0; i < 7; i++) {
        final d = DateTime(monday.year, monday.month, monday.day + i);
        bars.add(_Bar(names[i], plantStore.activityOn(d)));
      }
    } else if (_selectedTimeFilter == 'Bulan Ini') {
      // Per minggu dalam bulan ini
      final dim = DateTime(today.year, today.month + 1, 0).day;
      final weeks = ((dim - 1) ~/ 7) + 1;
      for (var w = 0; w < weeks; w++) {
        final end = (w * 7 + 7) > dim ? dim : (w * 7 + 7);
        var sum = 0;
        for (var d = w * 7 + 1; d <= end; d++) {
          sum += plantStore.activityOn(DateTime(today.year, today.month, d));
        }
        bars.add(_Bar('Mg ${w + 1}', sum));
      }
    } else {
      // 6 bulan terakhir, per bulan
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      for (var k = 5; k >= 0; k--) {
        final first = DateTime(today.year, today.month - k, 1);
        final days = DateTime(first.year, first.month + 1, 0).day;
        var sum = 0;
        for (var d = 1; d <= days; d++) {
          sum += plantStore.activityOn(DateTime(first.year, first.month, d));
        }
        bars.add(_Bar(months[first.month - 1], sum));
      }
    }
    return bars;
  }

  Widget _buildChart() {
    final bars = _chartBars();
    final maxValue = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);

    final boxDecoration = BoxDecoration(
      color: context.bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.line),
    );

    if (maxValue == 0) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: boxDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 60, color: context.line),
            SizedBox(height: 8),
            Text('Belum ada aktivitas di periode ini', style: TextStyle(color: context.muted)),
          ],
        ),
      );
    }

    return Container(
      height: 180,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: boxDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${b.value}', style: TextStyle(fontSize: 11, color: context.muted)),
                  SizedBox(height: 4),
                  Container(
                    height: b.value == 0 ? 4.0 : (90.0 * b.value / maxValue).clamp(4.0, 90.0),
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: b.value > 0 ? AppColors.primary : context.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(b.label, style: TextStyle(fontSize: 11, color: context.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(PlantCategory? category, String label) {
    final selected = _categoryFilter == category;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: category?.color ?? AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : context.ink),
        onSelected: (_) => setState(() => _categoryFilter = category),
      ),
    );
  }

 

  // Fungsi memunculkan pop-up tambah tanaman (Hampir full screen)
  void _showAddPlantModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Wajib di-true agar tinggi bisa diatur lebih dari setengah layar
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85, // Mengambil 85% tinggi layar
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Garis kecil di atas modal (indikator pull down)
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text('Tambah tanaman', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Mau menanam apa?', style: TextStyle(color: context.muted)),
              SizedBox(height: 30),
              
                           _buildCategoryButton(Icons.eco, PlantCategory.sayurBuah),
              SizedBox(height: 15),
              _buildCategoryButton(Icons.local_florist, PlantCategory.hias),
              SizedBox(height: 15),
              _buildCategoryButton(Icons.water_drop, PlantCategory.hidroponik),
            ],
          ),
        );
      },
    );
  }
  // Desain tombol kategori di dalam Modal
  Widget _buildCategoryButton(IconData icon, PlantCategory category) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // tutup popup pilih kategori
        showAddPlantForm(context, category); // buka form
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: category.color.withValues(alpha: 0.1),
              child: Icon(icon, color: category.color),
            ),
            SizedBox(width: 20),
            Expanded(child: Text(category.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Icon(Icons.arrow_forward_ios, size: 16, color: context.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
                title: Text('Monitoring Kebun'), // Tombol back otomatis warna putih
        elevation: 0,
      ),
      
      // Tombol FAB (+) di pojok kanan bawah
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlantModal,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: Colors.white, size: 30),
      ),
      
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BAGIAN ATAS: GRAFIK & FILTER ---
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surface,
                boxShadow: [BoxShadow(color: context.line, blurRadius: 5, spreadRadius: 1)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aktivitas perawatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  
                  // Deretan Filter (Bisa discroll menyamping jika kepanjangan)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _timeFilters.map((filter) {
                        final isSelected = _selectedTimeFilter == filter;
                        return Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : context.ink),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTimeFilter = filter;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Grafik aktivitas perawatan (otomatis diperbarui)
                  ListenableBuilder(
                    listenable: plantStore,
                    builder: (context, _) => _buildChart(),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // --- BAGIAN BAWAH: LIST TANAMAN ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Tanamanmu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _categoryChip(null, 'Semua'),
                  for (final c in PlantCategory.values) _categoryChip(c, c.label),
                ],
              ),
            ),
            
                       // Daftar tanaman: otomatis diperbarui saat plantStore berubah
            ListenableBuilder(
              listenable: plantStore,
              builder: (context, _) {
                final all = plantStore.plants;
                final plants = _categoryFilter == null
                    ? all
                    : all.where((p) => p.category == _categoryFilter).toList();

                if (all.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: 60.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.energy_savings_leaf_outlined, size: 80, color: context.muted),
                          SizedBox(height: 15),
                          Text(
                            'Belum ada tanaman\nKetuk + untuk menambah tanaman pertamamu',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.muted, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (plants.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Belum ada tanaman di kategori ini', style: TextStyle(color: context.muted)),
                    ),
                  );
                }

                // Tanaman terbaru di paling atas
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    children: [
                      for (final plant in plants.reversed) PlantCard(plant: plant),
                    ],
                  ),
                );
              },
            ),
              // Tempat menaruh desain card (jika datanya sudah ada)
              SizedBox(),
              
            SizedBox(height: 100), // Spasi bawah agar tidak tertutup FAB
          ],
        ),
      ),
    );
  }
}

class _Bar {
  final String label;
  final int value;
  const _Bar(this.label, this.value);
}