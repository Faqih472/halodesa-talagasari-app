// ============================================================
// profile_view.dart — TabSettingsView + TabMyRequestView
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import 'home_view.dart';

// ============================================================
// tab_settings_view.dart — REWRITE
// - Edit profil + ganti foto profil (Firebase Storage)
// - UBAH PASSWORD LANGSUNG (realtime, tanpa email verifikasi)
// - Switch "Login Cepat" (ingat saya, ala Facebook)
// - Akses Notifikasi & Profil Jasa Saya
// - Logout (otomatis kunci-cepat bila Login Cepat aktif)
// ============================================================

class TabSettingsView extends StatelessWidget {
  const TabSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final NotificationController notifCtrl = Get.find<NotificationController>();

    return Obx(() {
      final user = authCtrl.currentUser.value;
      final String role = user?.role ?? 'warga';
      final Color primaryColor = AppTheme.primaryColor(role);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengaturan'),
          backgroundColor: primaryColor,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              FadeSlideIn(
                child: _buildProfileHeader(
                  context,
                  authCtrl,
                  user?.nama ?? '-',
                  user?.email ?? '-',
                  user?.fotoUrl ?? '',
                  role,
                  primaryColor,
                ),
              ),

              const SectionTitle('INFORMASI AKUN'),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  children: [
                    _infoTile(Icons.person_outlined, 'Nama Lengkap',
                        user?.nama ?? '-', primaryColor),
                    _infoTile(Icons.email_outlined, 'Email', user?.email ?? '-',
                        primaryColor),
                    _infoTile(
                        Icons.phone_outlined,
                        'Nomor Telepon',
                        (user?.nomorTelepon.isEmpty ?? true)
                            ? '-'
                            : user!.nomorTelepon,
                        primaryColor),
                    _infoTile(AppTheme.iconRole(role), 'Peran',
                        AppTheme.labelRole(role), primaryColor),
                    _infoTile(
                        Icons.calendar_today_outlined,
                        'Bergabung Sejak',
                        user?.createdAt != null
                            ? AppUtils.formatTanggal(user!.createdAt)
                            : '-',
                        primaryColor),
                  ],
                ),
              ),

              const SectionTitle('AKUN & KEAMANAN'),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: Column(
                  children: [
                    _actionTile(Icons.edit_outlined, 'Edit Profil',
                        'Ubah nama dan nomor telepon', primaryColor,
                        onTap: () => _showEditProfil(context, authCtrl, primaryColor)),
                    _actionTile(Icons.lock_reset_outlined, 'Ubah Password',
                        'Langsung aktif, tanpa verifikasi email', primaryColor,
                        onTap: () => _showUbahPassword(context, authCtrl, primaryColor)),
                    _switchTile(authCtrl, primaryColor),
                    _actionTile(
                      Icons.notifications_outlined,
                      'Notifikasi',
                      'Pemberitahuan pengajuan, jasa, dan pesan',
                      primaryColor,
                      trailing: Obx(() {
                        final n = notifCtrl.unreadCount.value;
                        if (n == 0) {
                          return const Icon(Icons.chevron_right,
                              color: AppTheme.textSecondary);
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$n',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        );
                      }),
                      onTap: () => Get.to(() => const NotificationView()),
                    ),
                    if (role == 'warga')
                      _actionTile(
                        Icons.handyman_outlined,
                        'Profil Jasa Saya',
                        'Daftar atau kelola layanan jasa Anda',
                        primaryColor,
                        onTap: () => Get.find<MainController>().goToJasa(),
                      ),
                  ],
                ),
              ),

              const SectionTitle('TENTANG APLIKASI'),
              _infoTile(Icons.info_outline, 'Versi', '2.0.0 — Platform Terpadu',
                  primaryColor),
              _infoTile(Icons.location_on_outlined, 'Wilayah',
                  'Desa Talagasari, Kec. Cikupa, Kab. Tangerang', primaryColor),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _konfirmasiLogout(authCtrl),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Keluar',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // Header profil + ganti foto
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(BuildContext context, AuthController authCtrl,
      String nama, String email, String fotoUrl, String role, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(gradient: AppTheme.gradient(role)),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                backgroundImage:
                    fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                child: fotoUrl.isEmpty
                    ? Text(AppUtils.inisial(nama),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: primary))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: BouncyTap(
                  onTap: () => _gantiFoto(authCtrl),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2), blurRadius: 6),
                      ],
                    ),
                    child: Icon(Icons.camera_alt, size: 17, color: primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(nama,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(email,
              style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppTheme.iconRole(role), size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(AppTheme.labelRole(role),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _gantiFoto(AuthController authCtrl) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 900);
    if (picked == null) return;
    final u = authCtrl.currentUser.value;
    if (u == null) return;

    Get.snackbar('Mengunggah...', 'Foto profil sedang diperbarui',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));

    final ok = await authCtrl.updateProfil(
      nama: u.nama,
      nomorTelepon: u.nomorTelepon,
      fotoFile: File(picked.path),
    );
    Get.snackbar(
      ok ? 'Berhasil ✅' : 'Gagal',
      ok ? 'Foto profil diperbarui.' : authCtrl.errorMessage.value,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tile builders
  // ─────────────────────────────────────────────────────────
  Widget _infoTile(IconData icon, String label, String value, Color primary) {
    return Container(
      color: Colors.white,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: primary, size: 22),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color primary,
      {required VoidCallback onTap, Widget? trailing}) {
    return Container(
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: primary.withOpacity(0.1),
          child: Icon(icon, color: primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _switchTile(AuthController authCtrl, Color primary) {
    return Obx(() => Container(
          color: Colors.white,
          child: SwitchListTile(
            value: authCtrl.rememberMeEnabled.value,
            onChanged: (v) => authCtrl.toggleRememberMe(v),
            activeColor: primary,
            secondary: CircleAvatar(
              radius: 19,
              backgroundColor: primary.withOpacity(0.1),
              child: Icon(Icons.bolt, color: primary, size: 20),
            ),
            title: const Text('Login Cepat',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Setelah keluar, cukup ketuk avatar untuk masuk lagi tanpa password',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ));
  }

  // ─────────────────────────────────────────────────────────
  // Sheet: Edit Profil
  // ─────────────────────────────────────────────────────────
  void _showEditProfil(
      BuildContext context, AuthController authCtrl, Color primary) {
    final u = authCtrl.currentUser.value;
    if (u == null) return;
    final formKey = GlobalKey<FormState>();
    final namaCtrl = TextEditingController(text: u.nama);
    final telpCtrl = TextEditingController(text: u.nomorTelepon);

    Get.bottomSheet(
      _sheetContainer(
        context,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: namaCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => AppUtils.validateRequired(v, label: 'Nama'),
                decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: telpCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    AppUtils.validateRequired(v, label: 'Nomor telepon'),
                decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 20),
              Obx(() => SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authCtrl.isLoading.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final ok = await authCtrl.updateProfil(
                                nama: namaCtrl.text,
                                nomorTelepon: telpCtrl.text,
                              );
                              if (ok) Get.back();
                              Get.snackbar(
                                ok ? 'Berhasil ✅' : 'Gagal',
                                ok
                                    ? 'Profil berhasil diperbarui.'
                                    : authCtrl.errorMessage.value,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: ok
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 12,
                              );
                            },
                      child: authCtrl.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  )),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Sheet: UBAH PASSWORD LANGSUNG (tanpa email verifikasi)
  // ─────────────────────────────────────────────────────────
  void _showUbahPassword(
      BuildContext context, AuthController authCtrl, Color primary) {
    final formKey = GlobalKey<FormState>();
    final lamaCtrl = TextEditingController();
    final baruCtrl = TextEditingController();
    final konfCtrl = TextEditingController();
    bool lamaVis = false, baruVis = false, konfVis = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheet) => _sheetContainer(
          ctx,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ubah Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Masukkan password lama, lalu password baru. Perubahan langsung aktif tanpa perlu membuka email.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lamaCtrl,
                  obscureText: !lamaVis,
                  validator: AppUtils.validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Password Lama',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(lamaVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => lamaVis = !lamaVis),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: baruCtrl,
                  obscureText: !baruVis,
                  onChanged: (_) => setSheet(() {}),
                  validator: (v) => AppUtils.validatePasswordBaru(v),
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(baruVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => baruVis = !baruVis),
                    ),
                  ),
                ),
                if (baruCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _kekuatanBar(baruCtrl.text),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: konfCtrl,
                  obscureText: !konfVis,
                  validator: (v) =>
                      AppUtils.validatePasswordBaru(v, bandingkan: baruCtrl.text),
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(konfVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => konfVis = !konfVis),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authCtrl.isLoading.value
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final ok = await authCtrl.ubahPasswordLangsung(
                                  passwordLama: lamaCtrl.text,
                                  passwordBaru: baruCtrl.text,
                                );
                                if (ok) Get.back();
                                Get.snackbar(
                                  ok ? 'Password Diubah ✅' : 'Gagal',
                                  ok
                                      ? 'Password baru Anda sudah aktif sekarang juga.'
                                      : authCtrl.errorMessage.value,
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: ok
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  colorText: Colors.white,
                                  margin: const EdgeInsets.all(16),
                                  borderRadius: 12,
                                );
                              },
                        child: authCtrl.isLoading.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Ubah Password Sekarang'),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _kekuatanBar(String value) {
    final skor = AppUtils.kekuatanPassword(value);
    final Color warna =
        skor < 0.4 ? Colors.red : (skor < 0.75 ? Colors.orange : Colors.green);
    final String label = skor < 0.4 ? 'Lemah' : (skor < 0.75 ? 'Cukup' : 'Kuat');
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: skor),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(warna),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: warna, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _sheetContainer(BuildContext ctx, {required Widget child}) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(child: child),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────────────────
  void _konfirmasiLogout(AuthController authCtrl) {
    final bool loginCepat = authCtrl.rememberMeEnabled.value;
    Get.dialog(
      AlertDialog(
        title: const Text('Keluar dari Aplikasi?'),
        content: Text(
          loginCepat
              ? 'Login Cepat aktif: Anda akan diarahkan ke layar avatar. Cukup ketuk avatar untuk masuk lagi tanpa password.'
              : 'Anda perlu login kembali dengan email dan password untuk mengakses aplikasi.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Get.back();
              authCtrl.logout();
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// tab_myrequest_view.dart - TAHAP 2
// Status pengajuan informasi milik warga
// ==========================================================

class TabMyRequestView extends StatelessWidget {
  const TabMyRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    if (!Get.isRegistered<DataController>()) {
      Get.put(DataController());
    }
    final DataController dataCtrl = Get.find<DataController>();

    const Color primaryColor = AppTheme.warnaWarga;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Saya'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => dataCtrl.fetchMyRequests(),
          ),
        ],
      ),
      body: Obx(() {
        if (dataCtrl.isLoadingMyReq.value) {
          return const Center(
              child: CircularProgressIndicator(color: primaryColor));
        }

        final requests = dataCtrl.myRequests;

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 72, color: primaryColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('Belum ada pengajuan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text(
                      'Pengajuan informasi yang Anda kirim akan muncul di sini.\nTap tombol + di Beranda untuk mengajukan.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () => dataCtrl.fetchMyRequests(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _buildRequestCard(requests[index], primaryColor),
          ),
        );
      }),
    );
  }

  Widget _buildRequestCard(NewsModel news, Color primaryColor) {
    final statusColor = AppTheme.statusColor(news.status);
    final statusLabel = NewsModel.labelStatus(news.status);
    final statusIcon = _statusIcon(news.status);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: kategori + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  NewsModel.labelKategori(news.kategori),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Judul
            Text(news.judul,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),

            // Isi preview
            Text(news.isi,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            // Alasan penolakan (jika ditolak)
            if (news.status == 'ditolak' &&
                news.alasanPenolakan != null &&
                news.alasanPenolakan!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alasan: ${news.alasanPenolakan}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Diajukan ${AppUtils.formatRelatif(news.createdAt)}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'published':
        return Icons.check_circle_outline;
      case 'menunggu_review_admin':
        return Icons.hourglass_top_outlined;
      case 'pending_kades':
        return Icons.pending_outlined;
      case 'ditolak':
        return Icons.cancel_outlined;
      default:
        return Icons.edit_outlined;
    }
  }
}
