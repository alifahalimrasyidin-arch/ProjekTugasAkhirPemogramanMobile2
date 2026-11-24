import 'dart:async';
import 'package:flutter/material.dart';
import '../data/plant_store.dart';
import '../data/profile_store.dart';
import '../services/auth_service.dart';
import '../services/account_lookup.dart';
import '../theme/app_theme.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _next);
  }

  /// Jika sudah pernah login, muat data lalu langsung ke menu utama.
  /// Jika belum, buka halaman login.
  Future<void> _next() async {
    final user = authService.currentUser;
    if (user != null) {
      profileStore.loadFromUser(user);
      recordProvider(user); // melengkapi catatan untuk akun yang sudah ada
      await plantStore.load(user.uid);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            user != null ? DashboardPage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.eco, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Plant Monitoring',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pantau kebunmu dari mana saja',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}