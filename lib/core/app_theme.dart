// ============================================================
// app_theme.dart
// Dynamic Theme: warna aplikasi berubah sesuai role pengguna
// Warga = Hijau Teal | Admin = Biru | Kades = Merah Maroon
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ─── Palet Warna per Role ───────────────────────────────
  static const Color warnaWarga = Color(0xFF00796B);       // Teal 700
  static const Color warnaWargaLight = Color(0xFF48A999);
  static const Color warnaWargaDark = Color(0xFF004C40);

  static const Color warnaAdmin = Color(0xFF1565C0);       // Blue 800
  static const Color warnaAdminLight = Color(0xFF5E92F3);
  static const Color warnaAdminDark = Color(0xFF003C8F);

  static const Color warnaKades = Color(0xFF7B1FA2);       // Purple 700 (Maroon-ish)
  static const Color warnaKadesLight = Color(0xFFAE52D4);
  static const Color warnaKadesDark = Color(0xFF4A0072);

  // ─── Warna Netral ────────────────────────────────────────
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);

  // ─── Warna Status ────────────────────────────────────────
  static const Color statusPublished = Color(0xFF388E3C);
  static const Color statusPending = Color(0xFFF57C00);
  static const Color statusDraft = Color(0xFF546E7A);
  static const Color statusDitolak = Color(0xFFC62828);

  // ─────────────────────────────────────────────────────────
  // Ambil warna utama berdasarkan role
  // ─────────────────────────────────────────────────────────
  static Color primaryColor(String role) {
    switch (role) {
      case 'admin':
        return warnaAdmin;
      case 'kades':
        return warnaKades;
      default:
        return warnaWarga;
    }
  }

  static Color primaryColorLight(String role) {
    switch (role) {
      case 'admin':
        return warnaAdminLight;
      case 'kades':
        return warnaKadesLight;
      default:
        return warnaWargaLight;
    }
  }

  static Color primaryColorDark(String role) {
    switch (role) {
      case 'admin':
        return warnaAdminDark;
      case 'kades':
        return warnaKadesDark;
      default:
        return warnaWargaDark;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Buat ThemeData lengkap berdasarkan role
  // ─────────────────────────────────────────────────────────
  static ThemeData buildTheme(String role) {
    final Color primary = primaryColor(role);
    final Color primaryDark = primaryColorDark(role);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: Colors.white,
        secondary: primaryColorLight(role),
        background: background,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        backgroundColor: surface,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      // Card
      // Card
      cardTheme: CardThemeData( // <--- Ubah CardTheme menjadi CardThemeData di sini
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),

      // Chip
      chipTheme: ChipThemeData(
        selectedColor: primary.withOpacity(0.2),
        labelStyle: const TextStyle(fontSize: 12),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),

      fontFamily: 'Poppins',
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: warna badge status konten
  // ─────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'published':
        return statusPublished;
      case 'menunggu_review_admin':
      case 'pending_kades':
        return statusPending;
      case 'ditolak':
        return statusDitolak;
      default:
        return statusDraft;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Helper: label role dalam Bahasa Indonesia
  // ─────────────────────────────────────────────────────────
  static String labelRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin Desa';
      case 'kades':
        return 'Kepala Desa';
      default:
        return 'Warga';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Helper: icon role
  // ─────────────────────────────────────────────────────────
  static IconData iconRole(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'kades':
        return Icons.account_balance;
      default:
        return Icons.person;
    }
  }
}