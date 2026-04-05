import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // Akan aktif setelah Anda menjalankan 'flutterfire configure'

void main() async {
  // Wajib dipanggil sebelum inisialisasi plugin native (seperti Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Hapus komentar pada 3 baris di bawah ini setelah Anda menjalankan 'flutterfire configure' di terminal
  /*
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  */

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Kita menggunakan GetMaterialApp sebagai pengganti MaterialApp
    // agar fitur routing dan state management dari GetX bisa berjalan.
    return GetMaterialApp(
      title: 'Talagasari Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Menggunakan warna dominan hijau (identik dengan instansi desa/alam)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto', // Bisa diganti jika ada font spesifik
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: Colors.teal),
              SizedBox(height: 20),
              Text(
                'Setup Tahap 1 Berhasil!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Menunggu integrasi Firebase & Halaman Login...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}