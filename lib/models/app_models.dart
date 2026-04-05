// ============================================================
// app_models.dart
// Berisi semua model data aplikasi Talagasari Hub
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
// USER MODEL
// ─────────────────────────────────────────────
class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String role; // 'warga' | 'admin' | 'kades'
  final String nomorTelepon;
  final String fotoUrl;
  final bool isPenyediaJasa;
  final bool isVerified;
  final double lokasiLat;
  final double lokasiLng;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    this.nomorTelepon = '',
    this.fotoUrl = '',
    this.isPenyediaJasa = false,
    this.isVerified = false,
    this.lokasiLat = -6.239265, // Default: Kantor Desa Talagasari
    this.lokasiLng = 106.530200,
    required this.createdAt,
  });

  /// Buat UserModel dari dokumen Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'warga',
      nomorTelepon: data['nomor_telepon'] ?? '',
      fotoUrl: data['foto_url'] ?? '',
      isPenyediaJasa: data['isPenyediaJasa'] ?? false,
      isVerified: data['isVerified'] ?? false,
      lokasiLat: (data['lokasi_lat'] ?? -6.239265).toDouble(),
      lokasiLng: (data['lokasi_lng'] ?? 106.530200).toDouble(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Konversi ke Map untuk disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'role': role,
      'nomor_telepon': nomorTelepon,
      'foto_url': fotoUrl,
      'isPenyediaJasa': isPenyediaJasa,
      'isVerified': isVerified,
      'lokasi_lat': lokasiLat,
      'lokasi_lng': lokasiLng,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Helper: cek apakah user adalah admin atau kades
  bool get isStaff => role == 'admin' || role == 'kades';

  /// Helper: cek apakah user adalah kades
  bool get isKades => role == 'kades';

  /// Helper: cek apakah user adalah admin
  bool get isAdmin => role == 'admin';

  /// Helper: cek apakah user adalah warga biasa
  bool get isWarga => role == 'warga';
}

// ─────────────────────────────────────────────
// NEWS MODEL (Informasi Desa / Announcements)
// ─────────────────────────────────────────────

/// Kategori informasi desa
enum KategoriInfo {
  pengumuman,
  ketenagakerjaan, // Butuh ACC Kades
  kesehatan,       // Butuh ACC Kades
  bantuanSosial,   // Butuh ACC Kades
  kegiatan,
}

/// Status alur persetujuan konten
enum StatusKonten {
  draft,
  menungguReviewAdmin, // Pengajuan warga → Admin
  pendingKades,        // Admin kirim ke Kades / kategori sensitif
  published,
  ditolak,
}

class NewsModel {
  final String id;
  final String judul;
  final String isi;
  final String kategori;
  final String status;
  final String authorId;
  final String fotoUrl;
  final String? alasanPenolakan;
  final DateTime createdAt;
  final DateTime? publishedAt;

  NewsModel({
    required this.id,
    required this.judul,
    required this.isi,
    required this.kategori,
    required this.status,
    required this.authorId,
    this.fotoUrl = '',
    this.alasanPenolakan,
    required this.createdAt,
    this.publishedAt,
  });

  factory NewsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NewsModel(
      id: doc.id,
      judul: data['judul'] ?? '',
      isi: data['isi'] ?? '',
      kategori: data['kategori'] ?? 'pengumuman',
      status: data['status'] ?? 'draft',
      authorId: data['authorId'] ?? '',
      fotoUrl: data['foto_url'] ?? '',
      alasanPenolakan: data['alasan_penolakan'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      publishedAt: (data['published_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'isi': isi,
      'kategori': kategori,
      'status': status,
      'authorId': authorId,
      'foto_url': fotoUrl,
      'alasan_penolakan': alasanPenolakan,
      'created_at': Timestamp.fromDate(createdAt),
      'published_at': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
    };
  }

  /// Kategori yang butuh ACC Kades
  static bool isKategoriSensitif(String kategori) {
    return kategori == 'kesehatan' ||
        kategori == 'ketenagakerjaan' ||
        kategori == 'bantuan_sosial';
  }

  /// Label tampilan untuk setiap kategori
  static String labelKategori(String kategori) {
    switch (kategori) {
      case 'kesehatan':
        return 'Kesehatan';
      case 'ketenagakerjaan':
        return 'Lowongan Kerja';
      case 'bantuan_sosial':
        return 'Bantuan Sosial';
      case 'kegiatan':
        return 'Kegiatan Desa';
      default:
        return 'Pengumuman';
    }
  }

  /// Label tampilan untuk setiap status
  static String labelStatus(String status) {
    switch (status) {
      case 'menunggu_review_admin':
        return 'Menunggu Review';
      case 'pending_kades':
        return 'Menunggu ACC Kades';
      case 'published':
        return 'Dipublikasikan';
      case 'ditolak':
        return 'Ditolak';
      default:
        return 'Draft';
    }
  }
}

// ─────────────────────────────────────────────
// SERVICE MODEL (Penyedia Jasa Lokal)
// ─────────────────────────────────────────────

class ServiceModel {
  final String id;
  final String uidPenyedia;
  final String namaPenyedia;
  final String fotoUrl;
  final String kategori;
  final String deskripsi;
  final List<String> fotoPortofolio;
  final double lokasiLat;
  final double lokasiLng;
  final String status; // 'menunggu_review' | 'aktif' | 'nonaktif' | 'ditolak'
  final DateTime createdAt;

  // Field tambahan (tidak di Firestore, dihitung saat runtime)
  final double? jarakKm;

  ServiceModel({
    required this.id,
    required this.uidPenyedia,
    required this.namaPenyedia,
    this.fotoUrl = '',
    required this.kategori,
    required this.deskripsi,
    this.fotoPortofolio = const [],
    required this.lokasiLat,
    required this.lokasiLng,
    required this.status,
    required this.createdAt,
    this.jarakKm,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      uidPenyedia: data['uid_penyedia'] ?? '',
      namaPenyedia: data['nama_penyedia'] ?? '',
      fotoUrl: data['foto_url'] ?? '',
      kategori: data['kategori'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      fotoPortofolio: List<String>.from(data['foto_portofolio'] ?? []),
      lokasiLat: (data['lokasi_lat'] ?? -6.239265).toDouble(),
      lokasiLng: (data['lokasi_lng'] ?? 106.530200).toDouble(),
      status: data['status'] ?? 'menunggu_review',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid_penyedia': uidPenyedia,
      'nama_penyedia': namaPenyedia,
      'foto_url': fotoUrl,
      'kategori': kategori,
      'deskripsi': deskripsi,
      'foto_portofolio': fotoPortofolio,
      'lokasi_lat': lokasiLat,
      'lokasi_lng': lokasiLng,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Buat salinan dengan jarak yang sudah dihitung
  ServiceModel copyWithJarak(double jarak) {
    return ServiceModel(
      id: id,
      uidPenyedia: uidPenyedia,
      namaPenyedia: namaPenyedia,
      fotoUrl: fotoUrl,
      kategori: kategori,
      deskripsi: deskripsi,
      fotoPortofolio: fotoPortofolio,
      lokasiLat: lokasiLat,
      lokasiLng: lokasiLng,
      status: status,
      createdAt: createdAt,
      jarakKm: jarak,
    );
  }

  static const List<String> daftarKategori = [
    'Tukang / Konstruksi',
    'Teknisi Elektronik',
    'Guru Les / Pengajar',
    'Fotografer / Videografer',
    'Laundry / Kebersihan',
    'Catering / Masak',
  ];
}