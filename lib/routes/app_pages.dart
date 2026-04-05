import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';

// Import Controller
import '../modules/auth/controllers/auth_controller.dart';

// Import Views (Halaman Utama)
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/dashboard_warga/views/warga_home_view.dart';
import '../modules/dashboard_admin/views/admin_home_view.dart';
import '../modules/dashboard_kades/views/kades_home_view.dart';

class AppPages {
  // Rute awal saat aplikasi dibuka (akan diproses oleh AuthController)
  static const INITIAL = Routes.LOGIN;

  static final routes = [
    // Halaman Login
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
    ),

    // Halaman Registrasi
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterView(),
    ),

    // Dashboard Warga (Melihat Berita)
    GetPage(
      name: Routes.DASHBOARD_WARGA,
      page: () => WargaHomeView(),
    ),

    // Dashboard Admin (Input Berita)
    GetPage(
      name: Routes.DASHBOARD_ADMIN,
      page: () => AdminHomeView(),
    ),

    // Dashboard Kades (Persetujuan/Approval Berita)
    GetPage(
      name: Routes.DASHBOARD_KADES,
      page: () => KadesHomeView(),
    ),
  ];
}
