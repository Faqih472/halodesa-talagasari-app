// ============================================================
// auth_view.dart — AuthView + LockView
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/core.dart';

// ============================================================
// auth_view.dart — REWRITE
// Halaman Login dan Register, dengan:
// - Animasi masuk (fade + slide) di header & form
// - Checkbox "Ingat saya di perangkat ini" (Login Cepat)
// - Pesan error HANYA muncul saat benar-benar gagal (bug fixed)
// ============================================================

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

  // "Login Cepat" — default aktif, ala Facebook
  bool _ingatSaya = true;

  // Bubble akun tersimpan (Login Cepat di form login)
  final FocusNode _passwordFocus = FocusNode();
  String? _bukaUid; // uid bubble yang sedang dibuka (spinner)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Isi otomatis email akun yang tersimpan (Login Cepat)
    if (LocalStore.hasSavedProfile) {
      _loginEmailCtrl.text = LocalStore.savedEmail ?? '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordFocus.dispose();
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
    FocusScope.of(context).unfocus();

    final bool success = await _authController.login(
      email: _loginEmailCtrl.text,
      password: _loginPasswordCtrl.text,
      rememberMe: _ingatSaya,
    );

    // Hanya tampilkan error jika BENAR-BENAR gagal — AuthController
    // sudah memverifikasi ulang sesi sebelum melaporkan kegagalan,
    // sehingga notifikasi "gagal" palsu padahal login berhasil tidak
    // akan muncul lagi.
    if (!success && _authController.errorMessage.isNotEmpty) {
      _showError(_authController.errorMessage.value);
    }
  }

  // ─────────────────────────────────────────────────────────
  // ACTION: Register
  // ─────────────────────────────────────────────────────────
  Future<void> _doRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final bool success = await _authController.register(
      nama: _regNamaCtrl.text,
      email: _regEmailCtrl.text,
      password: _regPasswordCtrl.text,
      nomorTelepon: _regTeleponCtrl.text,
      rememberMe: _ingatSaya,
    );

    if (success) {
      _showSuccess('Akun berhasil dibuat! Selamat datang di Talagasari Hub.');
    } else if (_authController.errorMessage.isNotEmpty) {
      _showError(_authController.errorMessage.value);
    }
  }

  // ─────────────────────────────────────────────────────────
  // ACTION: Lupa Password (jalur cadangan via email)
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
              'Lupa total password Anda? Masukkan email untuk menerima tautan reset.\n\n'
              'Jika masih ingat password lama, Anda tidak perlu ini — gunakan '
              '"Ubah Password" langsung di menu Pengaturan setelah login.',
              style: TextStyle(fontSize: 13),
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
              FadeSlideIn(duration: const Duration(milliseconds: 550), child: _buildHeader()),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _buildTabBar(),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
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
  // WIDGET: Header dengan lingkaran dekoratif + logo animasi
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.warnaWarga, AppTheme.warnaWargaDark],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_city,
                      size: 40, color: AppTheme.warnaWarga),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Talagasari Hub',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Platform Komunitas Terpadu Desa Talagasari',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Tab Bar (Masuk / Daftar)
  // ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.warnaWarga,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Masuk'),
          Tab(text: 'Daftar'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Checkbox "Ingat saya" (Login Cepat)
  // ─────────────────────────────────────────────────────────
  Widget _buildIngatSaya() {
    return BouncyTap(
      onTap: () => setState(() => _ingatSaya = !_ingatSaya),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _ingatSaya
              ? AppTheme.warnaWarga.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _ingatSaya ? AppTheme.warnaWarga : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _ingatSaya ? AppTheme.warnaWarga : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: _ingatSaya
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ingat saya di perangkat ini (Login Cepat)',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Bubble akun tersimpan (Login Cepat, multi-akun)
  // Ketuk → masuk tanpa mengetik: sesi hidup dibuka langsung, sesi lain
  // login otomatis dengan password tersimpan (terenkripsi). Jika gagal,
  // email terisi dan kursor pindah ke kolom password.
  // ─────────────────────────────────────────────────────────
  Future<void> _masukDariBubble(Map<String, dynamic> akun) async {
    if (_bukaUid != null) return;
    final String uid = (akun['uid'] ?? '').toString();
    setState(() => _bukaUid = uid);

    final bool ok = await _authController.loginAkunTersimpan(uid);
    if (!mounted) return;

    if (ok) {
      // Navigasi ke Home ditangani AuthController; spinner dibiarkan
      // sampai halaman berganti (dengan batas waktu pengaman).
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) setState(() => _bukaUid = null);
      return;
    }

    setState(() {
      _bukaUid = null;
      _loginEmailCtrl.text = (akun['email'] ?? '').toString();
    });
    _passwordFocus.requestFocus();
    if (_authController.errorMessage.isNotEmpty) {
      _showError(_authController.errorMessage.value);
    }
  }

  void _konfirmasiHapusBubble(Map<String, dynamic> akun) {
    final String nama = (akun['nama'] ?? 'akun ini').toString();
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Akun Tersimpan?'),
        content: Text(
          '$nama akan dihapus dari daftar Login Cepat di perangkat ini '
          '(termasuk password tersimpannya). Anda perlu memasukkan email & '
          'password lagi untuk menambahkannya kembali.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await LocalStore.removeAccount((akun['uid'] ?? '').toString());
              if (mounted) setState(() {});
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAkunTersimpan() {
    final akunList = LocalStore.savedAccounts;
    if (akunList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Akun tersimpan di perangkat ini',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary),
          ),
        ),
        ...akunList.map(_buildBubbleAkun),
        const SizedBox(height: 4),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('atau masuk dengan akun lain',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBubbleAkun(Map<String, dynamic> akun) {
    final String uid = (akun['uid'] ?? '').toString();
    final String nama = (akun['nama'] ?? 'Pengguna').toString();
    final String foto = (akun['foto'] ?? '').toString();
    final Color warna =
        AppTheme.primaryColor((akun['role'] ?? 'warga').toString());
    final bool membuka = _bukaUid == uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withOpacity(0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _masukDariBubble(akun),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: warna,
                  backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                  child: foto.isEmpty
                      ? Text(
                          AppUtils.inisial(nama),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membuka
                            ? 'Membuka sesi...'
                            : 'Ketuk untuk masuk sebagai $nama',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                membuka
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Hapus akun tersimpan',
                        onPressed: () => _konfirmasiHapusBubble(akun),
                      ),
              ],
            ),
          ),
        ),
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
              'Selamat Datang Kembali',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masuk untuk mengakses informasi & layanan jasa desa.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Bubble akun tersimpan (ala Facebook) ──
            _buildAkunTersimpan(),
            const SizedBox(height: 8),

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

            TextFormField(
              controller: _loginPasswordCtrl,
              focusNode: _passwordFocus,
              obscureText: !_loginPasswordVisible,
              validator: AppUtils.validatePassword,
              onFieldSubmitted: (_) => _doLogin(),
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
            const SizedBox(height: 14),

            _buildIngatSaya(),
            const SizedBox(height: 4),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPassword,
                child: const Text('Lupa Password?'),
              ),
            ),
            const SizedBox(height: 8),

            Obx(() => BouncyTap(
              onTap: _authController.isLoading.value ? null : _doLogin,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
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
                ),
              ),
            )),
            const SizedBox(height: 16),

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

            TextFormField(
              controller: _regPasswordCtrl,
              obscureText: !_regPasswordVisible,
              validator: AppUtils.validatePassword,
              onChanged: (_) => setState(() {}),
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
            if (_regPasswordCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildKekuatanPassword(_regPasswordCtrl.text),
            ],
            const SizedBox(height: 16),

            TextFormField(
              controller: _regConfirmPassCtrl,
              obscureText: !_regConfirmVisible,
              validator: (v) => AppUtils.validatePasswordBaru(
                v,
                bandingkan: _regPasswordCtrl.text,
              ),
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
            const SizedBox(height: 14),

            _buildIngatSaya(),
            const SizedBox(height: 20),

            Obx(() => SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
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
              ),
            )),
            const SizedBox(height: 16),

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

  Widget _buildKekuatanPassword(String value) {
    final skor = AppUtils.kekuatanPassword(value);
    final Color warna = skor < 0.4
        ? Colors.red
        : (skor < 0.75 ? Colors.orange : Colors.green);
    final String label =
        skor < 0.4 ? 'Lemah' : (skor < 0.75 ? 'Cukup' : 'Kuat');

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: skor),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(warna),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: warna, fontWeight: FontWeight.w600)),
      ],
    );
  }
}


// ============================================================
// lock_view.dart
// Layar "Login Cepat" ala Facebook/Messenger.
//
// Sesi Firebase TIDAK diputus saat logout jika pengguna
// mengaktifkan "Login Cepat" — aplikasi hanya menampilkan layar
// ini dengan avatar yang dikelilingi cincin gelombang animasi.
// Cukup DIKETUK untuk langsung masuk lagi tanpa password.
// ============================================================

class LockView extends StatefulWidget {
  const LockView({super.key});

  @override
  State<LockView> createState() => _LockViewState();
}

class _LockViewState extends State<LockView> {
  bool _membuka = false;

  @override
  void initState() {
    super.initState();
    // Pengaman: kalau ternyata tidak ada snapshot profil tersimpan,
    // layar ini tidak berguna — lempar balik ke login penuh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!LocalStore.hasSavedProfile) {
        Get.offAllNamed('/login');
      }
    });
  }

  Future<void> _bukaKunci() async {
    if (_membuka) return;
    setState(() => _membuka = true);
    final authCtrl = Get.find<AuthController>();
    final ok = await authCtrl.quickUnlock();
    if (!ok && mounted) {
      setState(() => _membuka = false);
    }
    // Jika berhasil, AuthController sudah menavigasikan ke /home.
  }

  void _gantiAkun() {
    Get.dialog(
      AlertDialog(
        title: const Text('Ganti Akun?'),
        content: Text(
          'Anda akan keluar dari akun ${LocalStore.savedNama ?? ''}. '
          'Akun ini tetap tersimpan di perangkat dan bisa dipilih lagi dari layar login.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Get.back();
              Get.find<AuthController>().switchAccount();
            },
            child: const Text('Ya, Ganti Akun', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nama = LocalStore.savedNama ?? 'Pengguna';
    final String foto = LocalStore.savedFoto ?? '';
    final String role = LocalStore.savedRole ?? 'warga';
    final Color warna = AppTheme.primaryColor(role);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.gradient(role)),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              FadeSlideIn(
                child: Column(
                  children: [
                    const Icon(Icons.location_city, color: Colors.white, size: 34),
                    const SizedBox(height: 8),
                    const Text(
                      'Talagasari Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),

              // ── Avatar dengan gelombang animasi ──
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: BouncyTap(
                  onTap: _bukaKunci,
                  child: PulseWave(
                    color: Colors.white,
                    size: 128,
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        image: foto.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(foto),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: foto.isEmpty
                          ? Center(
                              child: Text(
                                AppUtils.inisial(nama),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: warna,
                                ),
                              ),
                            )
                          : (_membuka
                              ? Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black26,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              : null),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  nama,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  AppTheme.labelRole(role),
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 18),

              FadeSlideIn(
                delay: const Duration(milliseconds: 380),
                child: Text(
                  _membuka ? 'Membuka sesi...' : 'Ketuk avatar untuk masuk kembali',
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
              ),

              const Spacer(flex: 3),

              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: TextButton(
                  onPressed: _gantiAkun,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text(
                    'Bukan Anda? Ganti atau tambah akun',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
