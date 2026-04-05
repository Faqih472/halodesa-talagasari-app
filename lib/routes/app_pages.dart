import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_routes.dart';

// --- IMPORT INI YANG TADI KURANG ---
import '../modules/auth/controllers/auth_controller.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';

// Halaman dummy/sementara agar tidak error saat dipanggil oleh AuthController
class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 100, color: Colors.teal.withOpacity(0.5)),
            const SizedBox(height: 20),
            Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text("Berhasil Login & Role Terdeteksi"),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Get.find<AuthController>().logout(),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class AppPages {
  static const INITIAL = Routes.LOGIN;

  static final routes = [
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
    ),
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterView(),
    ),
    GetPage(
      name: Routes.DASHBOARD_WARGA,
      page: () => const DummyPage(title: 'Dashboard Warga'),
    ),
    GetPage(
      name: Routes.DASHBOARD_ADMIN,
      page: () => const DummyPage(title: 'Dashboard Admin'),
    ),
    GetPage(
      name: Routes.DASHBOARD_KADES,
      page: () => const DummyPage(title: 'Dashboard Kepala Desa'),
    ),
  ];
}