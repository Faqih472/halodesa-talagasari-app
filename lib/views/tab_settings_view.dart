// ============================================================
// tab_settings_view.dart
// Tab Pengaturan: Profil pengguna + Logout
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';

class TabSettingsView extends StatelessWidget {
  const TabSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();

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
              // ── Profil Header ──
              _buildProfileHeader(user?.nama ?? '-', user?.email ?? '-',
                  user?.fotoUrl ?? '', role, primaryColor),

              const SizedBox(height: 8),

              // ── Info Akun ──
              _buildSectionTitle('Informasi Akun'),
              _buildInfoTile(
                Icons.person_outlined,
                'Nama Lengkap',
                user?.nama ?? '-',
                primaryColor,
              ),
              _buildInfoTile(
                Icons.email_outlined,
                'Email',
                user?.email ?? '-',
                primaryColor,
              ),
              _buildInfoTile(
                Icons.phone_outlined,
                'Nomor Telepon',
                user?.nomorTelepon.isEmpty == true
                    ? '-'
                    : user?.nomorTelepon ?? '-',
                primaryColor,
              ),
              _buildInfoTile(
                AppTheme.iconRole(role),
                'Peran',
                AppTheme.labelRole(role),
                primaryColor,
              ),
              _buildInfoTile(
                Icons.calendar_today_outlined,
                'Bergabung Sejak',
                user?.createdAt != null
                    ? AppUtils.formatTanggal(user!.createdAt)
                    : '-',
                primaryColor,
              ),

              const SizedBox(height: 8),

              // ── Akun ──
              _buildSectionTitle('Akun'),
              _buildActionTile(
                Icons.edit_outlined,
                'Edit Profil',
                'Ubah nama, telepon, dan foto profil',
                primaryColor,
                onTap: () {
                  // TODO: Navigate ke edit profil
                  Get.snackbar(
                    'Segera Hadir',
                    'Fitur edit profil akan tersedia di pembaruan berikutnya.',
                    snackPosition: SnackPosition.BOTTOM,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                },
              ),
              _buildActionTile(
                Icons.lock_outline,
                'Ubah Password',
                'Reset password melalui email',
                primaryColor,
                onTap: () async {
                  if (user?.email != null) {
                    final bool ok = await authCtrl.resetPassword(
                      email: user!.email,
                    );
                    if (ok) {
                      Get.snackbar(
                        'Email Terkirim',
                        'Link reset password sudah dikirim ke ${user.email}',
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(16),
                        borderRadius: 12,
                        backgroundColor: Colors.green.shade700,
                        colorText: Colors.white,
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 8),

              // ── Aplikasi ──
              _buildSectionTitle('Aplikasi'),
              _buildInfoTile(
                Icons.info_outline,
                'Versi Aplikasi',
                'v1.0.0 (Tahap 1)',
                primaryColor,
              ),
              _buildInfoTile(
                Icons.location_city,
                'Studi Kasus',
                'Desa Talagasari, Kec. Cikupa, Kab. Tangerang',
                primaryColor,
              ),

              const SizedBox(height: 16),

              // ── Tombol Logout ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(authCtrl),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
  // WIDGET: Profile Header
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(
      String nama,
      String email,
      String fotoUrl,
      String role,
      Color primaryColor,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white,
            backgroundImage:
            fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
            child: fotoUrl.isEmpty
                ? Icon(
              AppTheme.iconRole(role),
              size: 48,
              color: primaryColor,
            )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            nama,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppTheme.labelRole(role),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Section Title
  // ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Info Tile (read-only)
  // ─────────────────────────────────────────────────────────
  Widget _buildInfoTile(
      IconData icon,
      String title,
      String value,
      Color primaryColor,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: primaryColor, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        dense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // WIDGET: Action Tile (clickable)
  // ─────────────────────────────────────────────────────────
  Widget _buildActionTile(
      IconData icon,
      String title,
      String subtitle,
      Color primaryColor, {
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: primaryColor, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
        dense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Dialog Konfirmasi Logout
  // ─────────────────────────────────────────────────────────
  void _confirmLogout(AuthController authCtrl) {
    Get.dialog(
      AlertDialog(
        title: const Text('Keluar dari Akun'),
        content: const Text(
          'Apakah Anda yakin ingin keluar? Anda perlu login kembali untuk mengakses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              authCtrl.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}