import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show IconData, Icons;

// ============================================================
// app_models.dart
// Berisi semua model data aplikasi Talagasari Hub
// ============================================================

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
  final String fcmToken;
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
    this.fcmToken = '',
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
      fcmToken: data['fcm_token'] ?? '',
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
      'fcm_token': fcmToken,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Salinan dengan sebagian field diubah (immutable update helper)
  UserModel copyWith({
    String? nama,
    String? nomorTelepon,
    String? fotoUrl,
    bool? isPenyediaJasa,
    double? lokasiLat,
    double? lokasiLng,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      nama: nama ?? this.nama,
      email: email,
      role: role,
      nomorTelepon: nomorTelepon ?? this.nomorTelepon,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      isPenyediaJasa: isPenyediaJasa ?? this.isPenyediaJasa,
      isVerified: isVerified,
      lokasiLat: lokasiLat ?? this.lokasiLat,
      lokasiLng: lokasiLng ?? this.lokasiLng,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
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
  final String status; // 'pending' | 'aktif' | 'nonaktif' | 'ditolak'
  final String? alasanPenolakan;
  final double ratingAvg;
  final int ratingCount;
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
    this.alasanPenolakan,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
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
      status: data['status'] ?? 'pending',
      alasanPenolakan: data['alasan_penolakan'],
      ratingAvg: (data['rating_avg'] ?? 0.0).toDouble(),
      ratingCount: ((data['rating_count'] ?? 0) as num).toInt(),
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
      'alasan_penolakan': alasanPenolakan,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  bool isMilikSaya(String uid) => uidPenyedia == uid;

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
      alasanPenolakan: alasanPenolakan,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
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

// ─────────────────────────────────────────────
// REVIEW MODEL (ulasan penyedia jasa)
// ─────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String idPengguna;
  final String namaPengguna;
  final int rating;
  final String komentar;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.idPengguna,
    required this.namaPengguna,
    required this.rating,
    required this.komentar,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      idPengguna: data['id_pengguna'] ?? '',
      namaPengguna: data['nama_pengguna'] ?? '',
      rating: ((data['rating'] ?? 0) as num).toInt(),
      komentar: data['komentar'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
// CHAT ROOM MODEL
// id room = uidTerkecil_uidTerbesar (deterministik, tanpa query)
// ─────────────────────────────────────────────
class ChatRoomModel {
  final String id;
  final List<String> participants;
  final Map<String, String> namaPengguna;
  final Map<String, String> fotoPengguna;
  final String pesanTerakhir;
  final DateTime? waktuTerakhir;
  final String idPengirimTerakhir;
  final Map<String, int> unreadCount;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.namaPengguna,
    required this.fotoPengguna,
    this.pesanTerakhir = '',
    this.waktuTerakhir,
    this.idPengirimTerakhir = '',
    this.unreadCount = const {},
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      namaPengguna: Map<String, String>.from(data['nama_pengguna'] ?? {}),
      fotoPengguna: Map<String, String>.from(data['foto_pengguna'] ?? {}),
      pesanTerakhir: data['pesan_terakhir'] ?? '',
      waktuTerakhir: (data['waktu_terakhir'] as Timestamp?)?.toDate(),
      idPengirimTerakhir: data['id_pengirim_terakhir'] ?? '',
      unreadCount: (data['unread_count'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  String uidLawan(String myUid) =>
      participants.firstWhere((p) => p != myUid, orElse: () => '');

  String namaLawan(String myUid) => namaPengguna[uidLawan(myUid)] ?? 'Pengguna';

  String fotoLawan(String myUid) => fotoPengguna[uidLawan(myUid)] ?? '';

  int unreadUntuk(String myUid) => unreadCount[myUid] ?? 0;
}

// ─────────────────────────────────────────────
// MESSAGE MODEL (subkoleksi dari chat_rooms)
// ─────────────────────────────────────────────
class MessageModel {
  final String id;
  final String idPengirim;
  final String isi;
  final DateTime waktu;
  final bool sudahDibaca;

  MessageModel({
    required this.id,
    required this.idPengirim,
    required this.isi,
    required this.waktu,
    required this.sudahDibaca,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      idPengirim: data['idPengirim'] ?? '',
      isi: data['isi'] ?? '',
      waktu: (data['waktu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sudahDibaca: data['sudahDibaca'] ?? false,
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION MODEL (subkoleksi users/{uid}/notifications)
// ─────────────────────────────────────────────
class AppNotification {
  final String id;
  final String judul;
  final String isi;
  final String tipe; // info | jasa | chat | sistem
  final String? targetId;
  final bool dibaca;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.judul,
    required this.isi,
    required this.tipe,
    this.targetId,
    required this.dibaca,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      judul: data['judul'] ?? '',
      isi: data['isi'] ?? '',
      tipe: data['tipe'] ?? 'info',
      targetId: data['target_id'],
      dibaca: data['dibaca'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  IconData get icon {
    switch (tipe) {
      case 'jasa':
        return Icons.handyman_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'sistem':
        return Icons.settings_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }
}
