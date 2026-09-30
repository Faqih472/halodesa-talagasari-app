// ============================================================
// core.dart — Inti: LocalStore, AppUtils, AppTheme, Widgets
// ============================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage, AndroidOptions;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

// ============================================================
// app_theme.dart
// Dynamic Theme: warna aplikasi berubah sesuai role pengguna
// Warga = Hijau Teal | Admin = Biru | Kades = Merah Maroon
// ============================================================

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

  // ─────────────────────────────────────────────────────────
  // Gradient utama berdasarkan role (dipakai header/banner)
  // ─────────────────────────────────────────────────────────
  static LinearGradient gradient(String role) {
    return LinearGradient(
      colors: [primaryColor(role), primaryColorDark(role)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: warna status verifikasi penyedia jasa
  // ─────────────────────────────────────────────────────────
  static Color statusJasaColor(String status) {
    switch (status) {
      case 'aktif':
        return statusPublished;
      case 'pending':
        return statusPending;
      case 'ditolak':
        return statusDitolak;
      default: // nonaktif
        return statusDraft;
    }
  }

  static String labelStatusJasa(String status) {
    switch (status) {
      case 'aktif':
        return 'Aktif';
      case 'pending':
        return 'Menunggu Verifikasi';
      case 'ditolak':
        return 'Ditolak';
      default:
        return 'Nonaktif';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Warna & ikon per kategori jasa (dipakai chip, marker, kartu)
  // ─────────────────────────────────────────────────────────
  static Color kategoriJasaColor(String kategori) {
    switch (kategori) {
      case 'tukang':
        return const Color(0xFFE65100);
      case 'teknisi':
        return const Color(0xFF1565C0);
      case 'guru_les':
        return const Color(0xFF2E7D32);
      case 'fotografer':
        return const Color(0xFF6A1B9A);
      case 'laundry':
        return const Color(0xFF00838F);
      case 'catering':
        return const Color(0xFFC2185B);
      default:
        return warnaWarga;
    }
  }

  static IconData kategoriJasaIcon(String kategori) {
    switch (kategori) {
      case 'tukang':
        return Icons.construction;
      case 'teknisi':
        return Icons.build_circle_outlined;
      case 'guru_les':
        return Icons.school_outlined;
      case 'fotografer':
        return Icons.camera_alt_outlined;
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      case 'catering':
        return Icons.restaurant_outlined;
      default:
        return Icons.handyman_outlined;
    }
  }
}


// ============================================================
// app_utils.dart
// Berisi: Haversine Formula, Date Formatter, dan helper umum
// ============================================================

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

  /// Format jarak (km) yang sudah dihitung menjadi teks singkat
  static String formatJarakKm(double? km) {
    if (km == null) return '-';
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
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

  static String labelKategoriJasa(String value) {
    final found = daftarKategoriJasa.firstWhere(
      (k) => k['value'] == value,
      orElse: () => {'label': value},
    );
    return found['label'] ?? value;
  }

  /// Hue marker Google Maps (0-360) per kategori, agar pin mudah dibedakan
  static double hueKategoriJasa(String kategori) {
    switch (kategori) {
      case 'tukang':
        return 30; // oranye
      case 'teknisi':
        return 210; // biru
      case 'guru_les':
        return 120; // hijau
      case 'fotografer':
        return 270; // ungu
      case 'laundry':
        return 180; // cyan
      case 'catering':
        return 330; // pink
      default:
        return 0; // merah
    }
  }

  // ─────────────────────────────────────────────────────────
  // INISIAL NAMA (fallback avatar tanpa foto)
  // ─────────────────────────────────────────────────────────
  static String inisial(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  // ─────────────────────────────────────────────────────────
  // VALIDASI PASSWORD BARU (dipakai form ubah password)
  // ─────────────────────────────────────────────────────────
  static String? validatePasswordBaru(String? value, {String? bandingkan}) {
    if (value == null || value.isEmpty) return 'Password baru tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
    if (bandingkan != null && value != bandingkan) return 'Konfirmasi password tidak cocok';
    return null;
  }

  /// Skor kekuatan password 0.0 - 1.0 (untuk indikator visual)
  static double kekuatanPassword(String value) {
    double skor = 0;
    if (value.length >= 6) skor += 0.25;
    if (value.length >= 10) skor += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(value)) skor += 0.15;
    if (RegExp(r'[0-9]').hasMatch(value)) skor += 0.15;
    if (RegExp(r'[!@#\$&*~%^_\-+=]').hasMatch(value)) skor += 0.20;
    return skor.clamp(0.0, 1.0);
  }
}


// ============================================================
// widgets.dart
// Kumpulan widget animasi & komponen UI yang dipakai berulang
// di seluruh aplikasi. Disatukan di sini supaya struktur folder
// tetap ramping (tidak ada 1 file per animasi kecil).
// ============================================================

// ─────────────────────────────────────────────────────────────
// FadeSlideIn — animasi masuk (fade + slide-up) untuk konten,
// bisa diberi delay agar list terasa "staggered" satu-satu.
// ─────────────────────────────────────────────────────────────
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.dy = 24,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.dy / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PulseWave — cincin "gelombang" yang memancar berulang di
// belakang sebuah widget (dipakai di avatar Login Cepat & FAB).
// ─────────────────────────────────────────────────────────────
class PulseWave extends StatefulWidget {
  final Widget child;
  final Color color;
  final double size;
  final int rings;

  const PulseWave({
    super.key,
    required this.child,
    required this.color,
    this.size = 140,
    this.rings = 3,
  });

  @override
  State<PulseWave> createState() => _PulseWaveState();
}

class _PulseWaveState extends State<PulseWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.9,
      height: widget.size * 1.9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(widget.rings, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = (_ctrl.value + (i / widget.rings)) % 1.0;
                return Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0) * 0.55,
                  child: Container(
                    width: widget.size * (1 + t * 0.9),
                    height: widget.size * (1 + t * 0.9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2.2),
                    ),
                  ),
                );
              },
            );
          }),
          widget.child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BouncyTap — micro-interaction: mengecil sedikit saat ditekan
// ─────────────────────────────────────────────────────────────
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncyTap({super.key, required this.child, this.onTap});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  double _scale = 1.0;

  void _set(double s) => setState(() => _scale = s);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1.0),
      onTapCancel: () => _set(1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ShimmerBox — placeholder loading berkilau (pengganti spinner)
// ─────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius radius;

  const ShimmerBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + _ctrl.value * 3, 0),
              end: Alignment(0 + _ctrl.value * 3, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kartu shimmer siap pakai untuk list yang sedang loading
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ShimmerBox(height: 12, width: 90),
            SizedBox(height: 12),
            ShimmerBox(height: 16, width: 200),
            SizedBox(height: 8),
            ShimmerBox(height: 12),
            SizedBox(height: 6),
            ShimmerBox(height: 12, width: 240),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EmptyState — tampilan kosong yang konsisten di seluruh app
// ─────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: FadeSlideIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 72, color: color.withOpacity(0.35)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// StatusBadge — pil kecil berwarna untuk status/kategori
// ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RatingStars — bintang rating (tampilan & mode input)
// ─────────────────────────────────────────────────────────────
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;
  final int max;
  final ValueChanged<int>? onChanged; // jika diisi = mode input

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = const Color(0xFFFFA726),
    this.max = 5,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < rating.round();
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: color,
        );
        if (onChanged == null) return star;
        return BouncyTap(
          onTap: () => onChanged!(i + 1),
          child: Padding(padding: const EdgeInsets.all(2), child: star),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SectionTitle — judul kecil untuk mengelompokkan pengaturan
// ─────────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
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
}


// ============================================================
// local_store.dart
// Penyimpanan lokal ringan (GetStorage) untuk fitur "Login Cepat"
// ala Facebook: setelah logout, sesi Firebase TIDAK diputus,
// aplikasi hanya dikunci (soft-lock) dan menyimpan snapshot
// profil ringan supaya layar kunci bisa langsung menampilkan
// avatar + nama tanpa perlu ke server terlebih dulu.
//
// TIDAK ADA password/kredensial yang pernah disimpan di sini.
// ============================================================

class LocalStore {
  static final GetStorage _box = GetStorage();

  /// Password akun tersimpan disimpan terenkripsi (Android Keystore / iOS Keychain)
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    await GetStorage.init();
  }

  // ─── Status "Login Cepat" ─────────────────────────────────
  static bool get rememberMe => _box.read('remember_me') ?? false;
  static bool get appLocked => _box.read('app_locked') ?? false;

  // ─── Snapshot profil tersimpan (untuk layar kunci) ───────
  static String? get savedUid => _box.read('saved_uid');
  static String? get savedNama => _box.read('saved_nama');
  static String? get savedEmail => _box.read('saved_email');
  static String? get savedFoto => _box.read('saved_foto');
  static String? get savedRole => _box.read('saved_role');

  static bool get hasSavedProfile =>
      rememberMe && savedUid != null && savedUid!.isNotEmpty;

  // ─── Daftar akun tersimpan (multi-akun, permanen) ─────────
  /// Semua akun yang pernah disimpan di perangkat ini. Data ini TIDAK ikut
  /// terhapus saat logout / ganti akun — hanya lewat removeAccount().
  static List<Map<String, dynamic>> get savedAccounts {
    final raw = _box.read('saved_accounts');
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Future<void> _upsertAccount({
    required String uid,
    required String nama,
    required String email,
    required String foto,
    required String role,
  }) async {
    final list = savedAccounts;
    final Map<String, dynamic> entry = {
      'uid': uid,
      'nama': nama,
      'email': email,
      'foto': foto,
      'role': role,
    };
    final i = list.indexWhere((a) => a['uid'] == uid);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.add(entry);
    }
    await _box.write('saved_accounts', list);
  }

  static Future<String?> savedPassword(String uid) async {
    try {
      return await _secure.read(key: 'pwd_$uid');
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePassword(String uid, String password) async {
    try {
      await _secure.write(key: 'pwd_$uid', value: password);
    } catch (_) {}
  }

  /// Hapus SATU akun tersimpan beserta password-nya
  static Future<void> removeAccount(String uid) async {
    final list = savedAccounts..removeWhere((a) => a['uid'] == uid);
    await _box.write('saved_accounts', list);
    try {
      await _secure.delete(key: 'pwd_$uid');
    } catch (_) {}
    if (savedUid == uid) await clearSavedProfile();
  }

  /// Simpan snapshot profil + aktifkan Login Cepat.
  /// Akun juga dimasukkan/diperbarui di daftar akun tersimpan; jika
  /// [password] diberikan, disimpan terenkripsi untuk login cepat antar-akun.
  static Future<void> saveProfileSnapshot({
    required String uid,
    required String nama,
    required String email,
    String foto = '',
    String role = 'warga',
    String? password,
  }) async {
    await _box.write('remember_me', true);
    await _box.write('saved_uid', uid);
    await _box.write('saved_nama', nama);
    await _box.write('saved_email', email);
    await _box.write('saved_foto', foto);
    await _box.write('saved_role', role);
    await _upsertAccount(
        uid: uid, nama: nama, email: email, foto: foto, role: role);
    if (password != null && password.isNotEmpty) {
      await savePassword(uid, password);
    }
  }

  static Future<void> setAppLocked(bool value) async {
    await _box.write('app_locked', value);
  }

  static Future<void> setRememberMe(bool value) async {
    await _box.write('remember_me', value);
  }

  /// Reset akun AKTIF saja (dipakai saat "Gunakan Akun Lain" / sesi berakhir).
  /// Daftar akun tersimpan (savedAccounts) TIDAK disentuh.
  static Future<void> clearSavedProfile() async {
    await _box.remove('remember_me');
    await _box.remove('saved_uid');
    await _box.remove('saved_nama');
    await _box.remove('saved_email');
    await _box.remove('saved_foto');
    await _box.remove('saved_role');
    await _box.remove('app_locked');
  }

  // ─── Preferensi kecil lainnya ─────────────────────────────
  static bool get onboardingSeen => _box.read('onboarding_seen') ?? false;
  static Future<void> setOnboardingSeen() async =>
      await _box.write('onboarding_seen', true);
}
