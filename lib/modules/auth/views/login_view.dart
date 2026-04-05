import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final authC = Get.put(AuthController());
    final emailC = TextEditingController();
    final passC = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header dengan desain melengkung
            Container(
              height: 250,
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_city, size: 80, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      'Talagasari Hub',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Platform Komunitas Terpadu',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Form Login Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                    const Text(
                      'Masuk ke Akun Anda',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Input Email
                    TextField(
                      controller: emailC,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Masukkan email Anda',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        hintText: 'Masukkan password',
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Tombol Login
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
                        if (emailC.text.isNotEmpty && passC.text.isNotEmpty) {
                          authC.login(emailC.text, passC.text);
                        } else {
                          Get.snackbar(
                            'Peringatan',
                            'Email dan password harus diisi',
                            backgroundColor: Colors.red[100],
                            colorText: Colors.red[900],
                          );
                        }
                      },
                      child: const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Area Register Button yang lebih menarik
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Belum menjadi warga terdaftar?', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => Get.toNamed(Routes.REGISTER),
                  child: const Text(
                    'Daftar Sekarang',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}