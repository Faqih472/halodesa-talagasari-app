import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Pastikan Anda sudah menjalankan flutterfire configure
import 'routes/app_pages.dart';
import 'modules/auth/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Talagasari Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Mendaftarkan AuthController di awal agar langsung mengecek status login
      initialBinding: BindingsBuilder(() {
        Get.put(AuthController());
      }),
      // Tampilan loading sementara sebelum diarahkan oleh AuthController
      home: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      ),
      // Mendaftarkan semua rute halaman
      getPages: AppPages.routes,
    );
  }
}
