// ============================================================
// main_layout_view.dart
// Kerangka utama: Dynamic Navbar + Dynamic Theme berdasarkan Role
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/main_controller.dart';
import '../core/app_theme.dart';

// Import semua tab views
import 'tab_home_view.dart';
import 'tab_manage_view.dart';
import 'tab_pending_view.dart';
import 'tab_myrequest_view.dart';
import 'tab_settings_view.dart';

class MainLayoutView extends StatelessWidget {
  const MainLayoutView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final MainController mainCtrl = Get.find<MainController>();

    return Obx(() {
      final String role = authCtrl.role;
      final bool isStaff = authCtrl.isStaff;

      // ── Ambil daftar halaman sesuai role ──
      final List<Widget> pages = isStaff
          ? _staffPages()
          : _wargaPages();

      return Theme(
        // Dynamic theme berdasarkan role
        data: AppTheme.buildTheme(role),
        child: Scaffold(
          // ── Body: Halaman aktif sesuai tab ──
          body: Obx(
                () => IndexedStack(
              index: mainCtrl.currentIndex.value,
              children: pages,
            ),
          ),

          // ── Bottom Navigation Bar (Dynamic) ──
          bottomNavigationBar: _buildBottomNav(mainCtrl, role, isStaff),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // Halaman untuk Warga (3 tab)
  // ─────────────────────────────────────────────────────────
  List<Widget> _wargaPages() => [
    const TabHomeView(),       // Tab 0: Beranda
    const TabMyRequestView(),  // Tab 1: Pengajuan Saya
    const TabSettingsView(),   // Tab 2: Pengaturan
  ];

  // ─────────────────────────────────────────────────────────
  // Halaman untuk Admin & Kades (4 tab)
  // ─────────────────────────────────────────────────────────
  List<Widget> _staffPages() => [
    const TabHomeView(),     // Tab 0: Beranda
    const TabManageView(),   // Tab 1: Kelola Pengajuan
    const TabPendingView(),  // Tab 2: Draft & Tertunda
    const TabSettingsView(), // Tab 3: Pengaturan
  ];

  // ─────────────────────────────────────────────────────────
  // Bottom Navigation Bar
  // ─────────────────────────────────────────────────────────
  Widget _buildBottomNav(
      MainController mainCtrl,
      String role,
      bool isStaff,
      ) {
    final Color primaryColor = AppTheme.primaryColor(role);

    return Obx(
          () => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: mainCtrl.currentIndex.value,
          onTap: mainCtrl.changeTab,
          selectedItemColor: primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: mainCtrl.currentNavItems,
        ),
      ),
    );
  }
}