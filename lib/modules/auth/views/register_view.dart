import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    // Memastikan controller sudah ada (di-put oleh LoginView sebelumnya)
    final authC = Get.find<AuthController>();

    final namaC = TextEditingController();
    final noTelpC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Pendaftaran Warga', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header dekoratif kecil
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1, size: 50, color: Colors.teal),
                    const SizedBox(height: 16),
                    const Text(
                      'Lengkapi Data Diri',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Data ini akan digunakan untuk verifikasi layanan jasa dan informasi desa.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Input Nama
                    TextField(
                      controller: namaC,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap (Sesuai KTP)',
                        prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input No HP
                    TextField(
                      controller: noTelpC,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor WhatsApp / HP',
                        prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Email
                    TextField(
                      controller: emailC,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Aktif',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Password
                    TextField(
                      controller: passC,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'Minimal 6 karakter',
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tombol Register
                    Obx(() => authC.isLoading.value
                        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (namaC.text.isEmpty || noTelpC.text.isEmpty || emailC.text.isEmpty || passC.text.isEmpty) {
                          Get.snackbar(
                            'Peringatan',
                            'Semua kolom wajib diisi!',
                            backgroundColor: Colors.red[100],
                            colorText: Colors.red[900],
                          );
                        } else if (passC.text.length < 6) {
                          Get.snackbar(
                            'Password Lemah',
                            'Password harus lebih dari 6 karakter',
                            backgroundColor: Colors.orange[100],
                            colorText: Colors.orange[900],
                          );
                        } else {
                          authC.register(emailC.text, passC.text, namaC.text, noTelpC.text);
                        }
                      },
                      child: const Text('BUAT AKUN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}