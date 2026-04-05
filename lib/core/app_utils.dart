// ============================================================
// app_utils.dart
// Berisi: Haversine Formula, Date Formatter, dan helper umum
// ============================================================

import 'dart:math';
import 'package:intl/intl.dart';

class AppUtils {
  // ─────────────────────────────────────────────────────────
  // HAVERSINE FORMULA
  // Menghitung jarak terpendek antara dua titik di permukaan bumi
  // ─────────────────────────────────────────────────────────

  /// Jari-jari rata-rata bumi dalam kilometer
  static const double _radiusBumi = 6371.0;

  /// Hitung jarak antara dua koordinat (hasil dalam km, 2 desimal)
  ///
  /// [lat1], [lng1] = koordinat pengguna
  /// [lat2], [lng2] = koordinat penyedia jasa
  static double hitungJarak(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {
    // Konversi derajat ke radian
    final double lat1Rad = _toRadian(lat1);
    final double lng1Rad = _toRadian(lng1);
    final double lat2Rad = _toRadian(lat2);
    final double lng2Rad = _toRadian(lng2);

    // Selisih koordinat
    final double dLat = lat2Rad - lat1Rad;
    final double dLng = lng2Rad - lng1Rad;

    // Rumus Haversine:
    // a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlng/2)
    final double a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLng / 2), 2);

    // c = 2 × atan2(√a, √(1−a))
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // d = R × c
    final double jarak = _radiusBumi * c;

    return double.parse(jarak.toStringAsFixed(2));
  }

  /// Hitung jarak dan tampilkan dalam format string
  /// Jika < 1 km → tampilkan dalam meter (misal: "850 m")
  /// Jika >= 1 km → tampilkan dalam km (misal: "2.35 km")
  static String hitungJarakFormatted(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {
    final double jarak = hitungJarak(lat1, lng1, lat2, lng2);

    if (jarak < 1.0) {
      final int meter = (jarak * 1000).round();
      return '$meter m';
    } else {
      return '$jarak km';
    }
  }

  /// Konversi derajat ke radian
  static double _toRadian(double degree) {
    return degree * pi / 180.0;
  }

  // ─────────────────────────────────────────────────────────
  // DATE & TIME FORMATTER
  // ─────────────────────────────────────────────────────────

  /// Format tanggal: "15 Maret 2025"
  static String formatTanggal(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id').format(date);
  }

  /// Format tanggal & waktu: "15 Maret 2025, 14:30"
  static String formatTanggalWaktu(DateTime date) {
    return DateFormat('d MMMM yyyy, HH:mm', 'id').format(date);
  }

  /// Format relatif: "2 jam lalu", "3 hari lalu"
  static String formatRelatif(DateTime date) {
    final Duration selisih = DateTime.now().difference(date);

    if (selisih.inMinutes < 1) {
      return 'Baru saja';
    } else if (selisih.inMinutes < 60) {
      return '${selisih.inMinutes} menit lalu';
    } else if (selisih.inHours < 24) {
      return '${selisih.inHours} jam lalu';
    } else if (selisih.inDays < 7) {
      return '${selisih.inDays} hari lalu';
    } else {
      return formatTanggal(date);
    }
  }

  // ─────────────────────────────────────────────────────────
  // LOGIKA KATEGORI BERITA (Rule-Based Approval)
  // ─────────────────────────────────────────────────────────

  /// Tentukan status awal konten berdasarkan kategori
  ///
  /// Kategori sensitif (Kesehatan, Ketenagakerjaan, Bantuan Sosial)
  /// → langsung ke 'pending_kades'
  ///
  /// Kategori biasa → ke 'menunggu_review_admin'
  static String tentukanStatusAwal(String kategori) {
    if (kategori == 'kesehatan' ||
        kategori == 'ketenagakerjaan' ||
        kategori == 'bantuan_sosial') {
      return 'pending_kades';
    }
    return 'menunggu_review_admin';
  }

  /// Apakah kategori ini butuh ACC Kepala Desa?
  static bool isKategoriSensitif(String kategori) {
    return kategori == 'kesehatan' ||
        kategori == 'ketenagakerjaan' ||
        kategori == 'bantuan_sosial';
  }

  // ─────────────────────────────────────────────────────────
  // VALIDATOR
  // ─────────────────────────────────────────────────────────

  /// Validasi format email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
    final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  /// Validasi password (minimal 6 karakter)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  /// Validasi field tidak boleh kosong
  static String? validateRequired(String? value, {String label = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label tidak boleh kosong';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // DAFTAR KATEGORI INFORMASI DESA
  // ─────────────────────────────────────────────────────────
  static const List<Map<String, String>> daftarKategoriInfo = [
    {'value': 'pengumuman', 'label': 'Pengumuman'},
    {'value': 'kegiatan', 'label': 'Kegiatan Desa'},
    {'value': 'kesehatan', 'label': 'Kesehatan ⚠️'},
    {'value': 'ketenagakerjaan', 'label': 'Lowongan Kerja ⚠️'},
    {'value': 'bantuan_sosial', 'label': 'Bantuan Sosial ⚠️'},
  ];

  // ─────────────────────────────────────────────────────────
  // DAFTAR KATEGORI JASA
  // ─────────────────────────────────────────────────────────
  static const List<Map<String, String>> daftarKategoriJasa = [
    {'value': 'tukang', 'label': 'Tukang / Konstruksi'},
    {'value': 'teknisi', 'label': 'Teknisi Elektronik'},
    {'value': 'guru_les', 'label': 'Guru Les / Pengajar'},
    {'value': 'fotografer', 'label': 'Fotografer / Videografer'},
    {'value': 'laundry', 'label': 'Laundry / Kebersihan'},
    {'value': 'catering', 'label': 'Catering / Masak'},
  ];
}