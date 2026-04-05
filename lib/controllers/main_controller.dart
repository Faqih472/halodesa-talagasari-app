// ============================================================
// main_controller.dart
// Logic: Dynamic Navbar berdasarkan Role Pengguna
// Warga → 3 tab | Admin & Kades → 4 tab
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';

class MainController extends GetxController {
  // ─── Reactive State ──────────────────────────────────────
  final RxInt currentIndex = 0.obs;

  // ─── Dependency ──────────────────────────────────────────
  final AuthController _authController = Get.find<AuthController>();

  // ─── Getters ─────────────────────────────────────────────
  String get role => _authController.role;
  bool get isStaff => _authController.isStaff;

  // ─────────────────────────────────────────────────────────
  // Ganti tab aktif
  // ─────────────────────────────────────────────────────────
  void changeTab(int index) {
    currentIndex.value = index;
  }

  // ─────────────────────────────────────────────────────────
  // Reset ke tab pertama (Beranda)
  // ─────────────────────────────────────────────────────────
  void resetToHome() {
    currentIndex.value = 0;
  }

  // ─────────────────────────────────────────────────────────
  // KONFIGURASI NAVBAR WARGA (3 tab)
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get navItemsWarga => [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Beranda',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.assignment_outlined),
      activeIcon: Icon(Icons.assignment),
      label: 'Pengajuan Saya',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Pengaturan',
    ),
  ];

  // ─────────────────────────────────────────────────────────
  // KONFIGURASI NAVBAR ADMIN & KADES (4 tab)
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get navItemsStaff => [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Beranda',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.inbox_outlined),
      activeIcon: Icon(Icons.inbox),
      label: 'Pengajuan',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.pending_actions_outlined),
      activeIcon: Icon(Icons.pending_actions),
      label: 'Tertunda',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Pengaturan',
    ),
  ];

  // ─────────────────────────────────────────────────────────
  // Pilih list navbar sesuai role
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get currentNavItems =>
      isStaff ? navItemsStaff : navItemsWarga;

  // ─────────────────────────────────────────────────────────
  // Jumlah tab berdasarkan role
  // ─────────────────────────────────────────────────────────
  int get tabCount => isStaff ? 4 : 3;

  // ─────────────────────────────────────────────────────────
  // Label tab aktif (untuk AppBar title)
  // ─────────────────────────────────────────────────────────
  String get currentTabTitle {
    if (isStaff) {
      switch (currentIndex.value) {
        case 0:
          return 'Talagasari Hub';
        case 1:
          return 'Kelola Pengajuan';
        case 2:
          return 'Draft & Tertunda';
        case 3:
          return 'Pengaturan';
        default:
          return 'Talagasari Hub';
      }
    } else {
      switch (currentIndex.value) {
        case 0:
          return 'Talagasari Hub';
        case 1:
          return 'Pengajuan Saya';
        case 2:
          return 'Pengaturan';
        default:
          return 'Talagasari Hub';
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // Navigasi ke tab tertentu dari luar (misal dari notifikasi)
  // ─────────────────────────────────────────────────────────
  void goToManage() {
    if (isStaff) changeTab(1);
  }

  void goToPending() {
    if (isStaff) changeTab(2);
  }

  void goToSettings() {
    changeTab(isStaff ? 3 : 2);
  }

  void goToMyRequest() {
    if (!isStaff) changeTab(1);
  }
}