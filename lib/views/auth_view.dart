// ============================================================
// auth_view.dart
// Halaman Login dan Register untuk semua pengguna
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView>
    with SingleTickerProviderStateMixin {
  final AuthController _authController = Get.find<AuthController>();

  late TabController _tabController;

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Register controllers
  final _regNamaCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regTeleponCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController();

  // Visibility toggles
  bool _loginPasswordVisible = false;
  bool _regPasswordVisible = false;
  bool _regConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNamaCtrl.dispose();
    _regEmailCtrl.dispose();
    _regTeleponCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // ACTION: Login
  // ─────────────────────────────────────────────────────────
  Future<void> _doLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final bool success = await _authController.login(
      email: _loginEmailCtrl.text,
      password: _loginPasswordCtrl.text,
    );

    if (!success && _authController.errorMessage.isNotEmpty) {
      _showError(_authController.errorMessage.value);
    }
  }

  // ─────────────────────────────────────────────────────────
  // ACTION: Register
  // ─────────────────────────────────────────────────────────
  Future<void> _doRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final bool success = await _authController.register(
      nama: _regNamaCtrl.text,
      email: _regEmailCtrl.text,
      password: _regPasswordCtrl.text,
      nomorTelepon: _regTeleponCtrl.text,
    );

    if (success) {
      _showSuccess('Akun berhasil dibuat! Selamat datang di Talagasari Hub.');
    } else if (_authController.errorMessage.isNotEmpty) {
      _showError(_authController.errorMessage.value);
    }
  }

  // ─────────────────────────────────────────────────────────
  // ACTION: Lupa Password
  // ─────────────────────────────────────────────────────────
  void _showForgotPassword() {
    final TextEditingController emailCtrl = TextEditingController(
      text: _loginEmailCtrl.text,
    );

    Get.dialog(
      AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email Anda. Kami akan kirimkan tautan untuk reset password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          Obx(() => ElevatedButton(
            onPressed: _authController.isLoading.value
                ? null
                : () async {
              if (emailCtrl.text.isEmpty) return;
              final bool ok = await _authController.resetPassword(
                email: emailCtrl.text,
              );
              Get.back();
              if (ok) {
                _showSuccess('Email reset password telah dikirim!');
              } else {
                _showError(_authController.errorMessage.value);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            child: _authController.isLoading.value
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('Kirim'),
          )),
        ],
      ),
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'Gagal',
      message,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Berhasil',
      message,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header / Logo ──
              _buildHeader(),

              // ── Tab Bar ──
              _buildTabBar(),

              // ── Tab Content ──
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(),
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Header
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.warnaWarga,
            AppTheme.warnaWargaDark,
          ],
        ),
      ),
      child: Column(
        children: [
          // Icon Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_city,
              size: 48,
              color: AppTheme.warnaWarga,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Talagasari Hub',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Platform Komunitas Desa Talagasari',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Tab Bar (Login / Daftar)
  // ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.warnaWarga,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.warnaWarga,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        tabs: const [
          Tab(text: 'Masuk'),
          Tab(text: 'Daftar'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Form Login
  // ─────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Selamat Datang!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masuk untuk mengakses informasi dan layanan desa.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),

            // Email
            TextFormField(
              controller: _loginEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AppUtils.validateEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contoh@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _loginPasswordCtrl,
              obscureText: !_loginPasswordVisible,
              validator: AppUtils.validatePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Masukkan password Anda',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _loginPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _loginPasswordVisible = !_loginPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Lupa Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPassword,
                child: const Text('Lupa Password?'),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Masuk
            Obx(() => ElevatedButton(
              onPressed: _authController.isLoading.value ? null : _doLogin,
              child: _authController.isLoading.value
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Masuk'),
            )),
            const SizedBox(height: 16),

            // Link ke Register
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Belum punya akun?',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Daftar sekarang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Form Register
  // ─────────────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Buat Akun Baru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daftarkan diri sebagai warga Desa Talagasari.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),

            // Nama Lengkap
            TextFormField(
              controller: _regNamaCtrl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => AppUtils.validateRequired(v, label: 'Nama'),
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                hintText: 'Masukkan nama lengkap Anda',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _regEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AppUtils.validateEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contoh@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Nomor Telepon
            TextFormField(
              controller: _regTeleponCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  AppUtils.validateRequired(v, label: 'Nomor telepon'),
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon / WhatsApp',
                hintText: '08xxxxxxxxxx',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _regPasswordCtrl,
              obscureText: !_regPasswordVisible,
              validator: AppUtils.validatePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Minimal 6 karakter',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _regPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _regPasswordVisible = !_regPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Konfirmasi Password
            TextFormField(
              controller: _regConfirmPassCtrl,
              obscureText: !_regConfirmVisible,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Konfirmasi password tidak boleh kosong';
                if (v != _regPasswordCtrl.text) return 'Password tidak cocok';
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password',
                hintText: 'Ulangi password Anda',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _regConfirmVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _regConfirmVisible = !_regConfirmVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Tombol Daftar
            Obx(() => ElevatedButton(
              onPressed:
              _authController.isLoading.value ? null : _doRegister,
              child: _authController.isLoading.value
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Daftar Sekarang'),
            )),
            const SizedBox(height: 16),

            // Link ke Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sudah punya akun?',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Masuk'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}