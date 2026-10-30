// ============================================================
// models_extra.dart — Model untuk fitur lanjutan:
// aktivitas pengaduan, SOS, polling, agenda, surat online,
// audit log, laporan jasa.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons;

DateTime? _ts(dynamic v) => (v as Timestamp?)?.toDate();

// ─────────────────────────────────────────────
// AKTIVITAS PENGADUAN (timeline status + balasan dua arah)
// pengaduan/{id}/aktivitas/{id}
// ─────────────────────────────────────────────
class ActivityModel {
  final String id;
  final String tipe; // 'status' | 'komentar'
  final String isi;
  final String status; // untuk tipe status
  final String oleh;
  final String peran; // 'warga' | 'admin' | 'kades'
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.tipe,
    required this.isi,
    this.status = '',
    required this.oleh,
    required this.peran,
    required this.createdAt,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      tipe: d['tipe'] ?? 'komentar',
      isi: d['isi'] ?? '',
      status: d['status'] ?? '',
      oleh: d['oleh'] ?? '',
      peran: d['peran'] ?? 'warga',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
// SOS  — sos/{id}
// ─────────────────────────────────────────────
class SosModel {
  final String id;
  final String uid;
  final String nama;
  final String peran; // 'warga' | 'admin' | 'kades'
  final String telepon;
  final double lat;
  final double lng;
  final String status; // 'baru' | 'ditangani'
  final DateTime createdAt;

  SosModel({
    required this.id,
    required this.uid,
    required this.nama,
    this.peran = 'warga',
    this.telepon = '',
    required this.lat,
    required this.lng,
    this.status = 'baru',
    required this.createdAt,
  });

  factory SosModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SosModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      nama: d['nama'] ?? '',
      peran: d['peran'] ?? 'warga',
      telepon: d['telepon'] ?? '',
      lat: (d['lat'] ?? 0).toDouble(),
      lng: (d['lng'] ?? 0).toDouble(),
      status: d['status'] ?? 'baru',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
// POLLING — polling/{id}, suara di polling/{id}/suara/{uid}
// ─────────────────────────────────────────────
class PollModel {
  final String id;
  final String pertanyaan;
  final List<String> opsi;
  final DateTime tutup;
  final String dibuatOleh;
  final DateTime createdAt;
  final String fotoUrl; // gambar pendukung (opsional)

  PollModel({
    required this.id,
    required this.pertanyaan,
    required this.opsi,
    required this.tutup,
    this.dibuatOleh = '',
    required this.createdAt,
    this.fotoUrl = '',
  });

  factory PollModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PollModel(
      id: doc.id,
      pertanyaan: d['pertanyaan'] ?? '',
      opsi: List<String>.from(d['opsi'] ?? const []),
      tutup: _ts(d['tutup']) ?? DateTime.now(),
      dibuatOleh: d['dibuat_oleh'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
      fotoUrl: d['foto_url'] ?? '',
    );
  }

  bool get ditutup => DateTime.now().isAfter(tutup);
}

// ─────────────────────────────────────────────
// AGENDA — agenda/{id}, peserta di agenda/{id}/hadir/{uid}
// ─────────────────────────────────────────────
class AgendaModel {
  final String id;
  final String judul;
  final String deskripsi;
  final String lokasi;
  final DateTime waktu;
  final String dibuatOleh;
  final DateTime createdAt;
  final String fotoUrl; // poster / gambar acara (opsional)

  AgendaModel({
    required this.id,
    required this.judul,
    this.deskripsi = '',
    this.lokasi = '',
    required this.waktu,
    this.dibuatOleh = '',
    required this.createdAt,
    this.fotoUrl = '',
  });

  factory AgendaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AgendaModel(
      id: doc.id,
      judul: d['judul'] ?? '',
      deskripsi: d['deskripsi'] ?? '',
      lokasi: d['lokasi'] ?? '',
      waktu: _ts(d['waktu']) ?? DateTime.now(),
      dibuatOleh: d['dibuat_oleh'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
      fotoUrl: d['foto_url'] ?? '',
    );
  }

  bool get lewat => waktu.isBefore(DateTime.now());
}

// ─────────────────────────────────────────────
// SURAT ONLINE — surat/{id}
// Alur: menunggu_review (Admin) → pending_kades → terbit
//       atau ditolak (dengan alasan)
// ─────────────────────────────────────────────
class LetterModel {
  final String id;
  final String uid;
  final String nama;
  final String nik;
  final String jenis;
  final String keperluan;
  final String alamat;
  final String jenisKelamin;
  final DateTime? tanggalLahir;
  final String status;
  final String? alasan;
  final String nomor;
  final String kode;
  final String penandatangan;
  final DateTime createdAt;
  final DateTime? terbitAt;
  final String tempatLahir;
  final DateTime? ttdAt;
  final DateTime? berlakuSampai;

  LetterModel({
    required this.id,
    required this.uid,
    required this.nama,
    this.nik = '',
    required this.jenis,
    this.keperluan = '',
    this.alamat = '',
    this.jenisKelamin = '',
    this.tanggalLahir,
    required this.status,
    this.alasan,
    this.nomor = '',
    this.kode = '',
    this.penandatangan = '',
    required this.createdAt,
    this.terbitAt,
    this.tempatLahir = '',
    this.ttdAt,
    this.berlakuSampai,
  });

  factory LetterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LetterModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      nama: d['nama'] ?? '',
      nik: d['nik'] ?? '',
      jenis: d['jenis'] ?? 'domisili',
      keperluan: d['keperluan'] ?? '',
      alamat: d['alamat'] ?? '',
      jenisKelamin: d['jenis_kelamin'] ?? '',
      tanggalLahir: _ts(d['tanggal_lahir']),
      status: d['status'] ?? 'menunggu_review',
      alasan: d['alasan'],
      nomor: d['nomor'] ?? '',
      kode: d['kode'] ?? '',
      penandatangan: d['penandatangan'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
      terbitAt: _ts(d['terbit_at']),
      tempatLahir: d['tempat_lahir'] ?? '',
      ttdAt: _ts(d['ttd_at']),
      berlakuSampai: _ts(d['berlaku_sampai']),
    );
  }

  /// Disetujui Kades, menunggu tanda tangan basah di kantor desa
  bool get menungguTtd => status == 'terbit';

  /// Sudah ditandatangani → sah
  bool get sah => status == 'ditandatangani';

  /// PDF boleh dicetak (setelah disetujui)
  bool get bisaCetak => menungguTtd || sah;

  bool get kadaluarsa =>
      sah && berlakuSampai != null && DateTime.now().isAfter(berlakuSampai!);

  /// value, label, kode singkat untuk nomor surat
  static const List<Map<String, String>> daftarJenis = [
    {'value': 'domisili', 'label': 'Surat Keterangan Domisili', 'kode': 'SKD', 'bulan': '6'},
    {'value': 'pengantar', 'label': 'Surat Pengantar', 'kode': 'SPR', 'bulan': '3'},
    {'value': 'tidak_mampu', 'label': 'Surat Keterangan Tidak Mampu', 'kode': 'SKTM', 'bulan': '3'},
    {'value': 'usaha', 'label': 'Surat Keterangan Usaha', 'kode': 'SKU', 'bulan': '3'},
  ];

  /// Masa berlaku (bulan) sejak tanggal tanda tangan
  static int masaBulan(String v) => int.parse(daftarJenis.firstWhere(
      (j) => j['value'] == v,
      orElse: () => {'bulan': '3'})['bulan']!);

  static String labelJenis(String v) => daftarJenis.firstWhere(
      (j) => j['value'] == v,
      orElse: () => {'label': 'Surat Keterangan'})['label']!;

  static String kodeJenis(String v) => daftarJenis.firstWhere(
      (j) => j['value'] == v,
      orElse: () => {'kode': 'SK'})['kode']!;

  static String labelStatus(String s) {
    switch (s) {
      case 'menunggu_review':
        return 'Menunggu Admin';
      case 'pending_kades':
        return 'Menunggu Kades';
      case 'terbit':
        return 'Menunggu Tanda Tangan';
      case 'ditandatangani':
        return 'Sah';
      case 'ditolak':
        return 'Ditolak';
      default:
        return s;
    }
  }

  static Color warnaStatus(String s) {
    switch (s) {
      case 'menunggu_review':
        return const Color(0xFFE65100);
      case 'pending_kades':
        return const Color(0xFF6A1B9A);
      case 'terbit':
        return const Color(0xFF1565C0);
      case 'ditandatangani':
        return const Color(0xFF2E7D32);
      case 'ditolak':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF616161);
    }
  }
}

// ─────────────────────────────────────────────
// AUDIT LOG — audit_log/{id}
// ─────────────────────────────────────────────
class AuditModel {
  final String id;
  final String aktorNama;
  final String aktorPeran;
  final String aksi;
  final String targetTipe;
  final String targetId;
  final String detail;
  final String alasan; // alasan penolakan (bila ada)
  final DateTime createdAt;

  AuditModel({
    required this.id,
    required this.aktorNama,
    required this.aktorPeran,
    required this.aksi,
    this.targetTipe = '',
    this.targetId = '',
    this.detail = '',
    this.alasan = '',
    required this.createdAt,
  });

  factory AuditModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AuditModel(
      id: doc.id,
      aktorNama: d['aktor_nama'] ?? '',
      aktorPeran: d['aktor_peran'] ?? '',
      aksi: d['aksi'] ?? '',
      targetTipe: d['target_tipe'] ?? '',
      targetId: d['target_id'] ?? '',
      detail: d['detail'] ?? '',
      alasan: d['alasan'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  bool get penolakan => aksi.startsWith('Menolak') || alasan.isNotEmpty;

  IconData get ikon {
    switch (targetTipe) {
      case 'pengaduan':
        return Icons.report_gmailerrorred_outlined;
      case 'ktp':
        return Icons.badge_outlined;
      case 'surat':
        return Icons.description_outlined;
      case 'jasa':
        return Icons.handyman_outlined;
      case 'informasi':
        return Icons.campaign_outlined;
      case 'sos':
        return Icons.sos;
      case 'polling':
        return Icons.how_to_vote_outlined;
      case 'agenda':
        return Icons.event_outlined;
      case 'umpan_balik':
        return Icons.rate_review_outlined;
      default:
        return Icons.history;
    }
  }
}

// ─────────────────────────────────────────────
// LAPORAN JASA BERMASALAH — laporan_jasa/{idJasa_uidPelapor}
// Satu pelapor hanya bisa punya satu laporan aktif per jasa.
// ─────────────────────────────────────────────
class ServiceReportModel {
  final String id;
  final String serviceId;
  final String namaPenyedia;
  final String uidPenyedia;
  final String namaPelapor;
  final String uidPelapor;
  final String jenis; // kunci di jenisLabel
  final String alasan;
  final String orderId;
  final String status; // 'baru' | 'selesai'
  final String tindakan; // 'abaikan' | 'peringatan' | 'nonaktif' | 'blokir'
  final String catatanAdmin;
  final DateTime createdAt;

  ServiceReportModel({
    required this.id,
    required this.serviceId,
    required this.namaPenyedia,
    this.uidPenyedia = '',
    required this.namaPelapor,
    this.uidPelapor = '',
    this.jenis = 'lainnya',
    required this.alasan,
    this.orderId = '',
    this.status = 'baru',
    this.tindakan = '',
    this.catatanAdmin = '',
    required this.createdAt,
  });

  factory ServiceReportModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ServiceReportModel(
      id: doc.id,
      serviceId: d['service_id'] ?? '',
      namaPenyedia: d['nama_penyedia'] ?? '',
      uidPenyedia: d['uid_penyedia'] ?? '',
      namaPelapor: d['nama_pelapor'] ?? '',
      uidPelapor: d['uid_pelapor'] ?? '',
      jenis: d['jenis'] ?? 'lainnya',
      alasan: d['alasan'] ?? '',
      orderId: d['order_id'] ?? '',
      status: d['status'] ?? 'baru',
      tindakan: d['tindakan'] ?? '',
      catatanAdmin: d['catatan_admin'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  static const Map<String, String> jenisLabel = {
    'penipuan': 'Penipuan / tidak sesuai kesepakatan',
    'tidak_datang': 'Tidak datang / tidak menepati janji',
    'kasar': 'Sikap kasar / tidak sopan',
    'harga': 'Harga tidak sesuai kesepakatan',
    'palsu': 'Data profil palsu / menyesatkan',
    'lainnya': 'Lainnya',
  };

  String get labelJenis => jenisLabel[jenis] ?? jenis;
}



// ─────────────────────────────────────────────
// UMPAN BALIK / KRITIK & SARAN — umpan_balik/{id}
// target: 'aplikasi' | 'admin' | 'kades'
//   • aplikasi → dibaca Admin & Kades
//   • admin    → dibaca Kades (agar Admin tidak menilai dirinya sendiri)
//   • kades    → dibaca Admin
// ─────────────────────────────────────────────
class FeedbackModel {
  final String id;
  final String uid;
  final String nama; // "Anonim" bila anonim
  final bool anonim;
  final String target;
  final int rating;
  final List<String> aspek;
  final String komentar;
  final String status; // 'baru' | 'ditinjau'
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.uid,
    required this.nama,
    this.anonim = false,
    required this.target,
    required this.rating,
    this.aspek = const [],
    this.komentar = '',
    this.status = 'baru',
    required this.createdAt,
  });

  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FeedbackModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      nama: d['nama'] ?? 'Warga',
      anonim: d['anonim'] ?? false,
      target: d['target'] ?? 'aplikasi',
      rating: ((d['rating'] ?? 0) as num).toInt(),
      aspek: List<String>.from(d['aspek'] ?? const []),
      komentar: d['komentar'] ?? '',
      status: d['status'] ?? 'baru',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  static String labelTarget(String t) {
    switch (t) {
      case 'admin':
        return 'Pelayanan Admin Desa';
      case 'kades':
        return 'Pelayanan Kepala Desa';
      default:
        return 'Aplikasi';
    }
  }

  static IconData ikonTarget(String t) {
    switch (t) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'kades':
        return Icons.account_balance_outlined;
      default:
        return Icons.phone_android_outlined;
    }
  }

  /// Pilihan aspek per target (bisa dipilih lebih dari satu)
  static const Map<String, List<String>> daftarAspek = {
    'aplikasi': [
      'Sering error / force close',
      'Lambat / loading lama',
      'Fitur tidak berguna',
      'Sulit dipakai / membingungkan',
      'Tampilan kurang nyaman',
      'Data tidak muncul / salah',
      'Saya suka aplikasinya',
    ],
    'admin': [
      'Respons lambat',
      'Pengajuan ditolak tanpa alasan jelas',
      'Kurang ramah / tidak sopan',
      'Informasi kurang jelas',
      'Terindikasi pilih kasih / tidak adil',
      'Pelayanan sudah baik',
    ],
    'kades': [
      'Respons lambat',
      'Laporan tidak ditindaklanjuti',
      'Kurang transparan',
      'Terindikasi pilih kasih / tidak adil',
      'Pelayanan sudah baik',
    ],
  };
}



// ─────────────────────────────────────────────
// PESANAN JASA — pesanan_jasa/{id}
// Alur: menunggu → (nego) → diterima → dikerjakan → menunggu_konfirmasi
//       → selesai (+ ulasan).  Cabang: ditolak, dibatalkan.
// Pembayaran dilakukan langsung di luar aplikasi.
// ─────────────────────────────────────────────
class OrderLog {
  final String status;
  final DateTime waktu;
  final String oleh;
  final String catatan;

  OrderLog({
    required this.status,
    required this.waktu,
    this.oleh = '',
    this.catatan = '',
  });

  factory OrderLog.fromMap(Map<String, dynamic> m) => OrderLog(
        status: (m['status'] ?? '').toString(),
        waktu: _ts(m['waktu']) ?? DateTime.now(),
        oleh: (m['oleh'] ?? '').toString(),
        catatan: (m['catatan'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'status': status,
        'waktu': Timestamp.fromDate(waktu),
        'oleh': oleh,
        'catatan': catatan,
      };
}

class OrderModel {
  final String id;
  final String serviceId;
  final String uidPenyedia;
  final String namaPenyedia; // nama usaha / penyedia
  final String uidPemesan;
  final String namaPemesan;
  final String telpPemesan;
  final String kategori;
  final String namaLayanan;
  final String paketId;
  final int harga; // harga satuan paket (0 = nego)
  final String satuan;
  final int jumlah;
  final int estimasiBiaya;
  final String deskripsi;
  final List<String> foto;
  final DateTime tanggal;
  final String jam; // 'HH:mm' atau ''
  final String mode; // 'datang' (ke rumah warga) | 'tempat'
  final String alamat;
  final double lat;
  final double lng;
  final String status;
  final int? hargaFinal;
  final DateTime? tanggalFinal;
  final String catatanPenyedia;
  final String alasanBatal;
  final String dibatalkanOleh; // 'pemesan' | 'penyedia' | ''
  final bool lunas;
  final bool sudahDiulas;
  final List<OrderLog> log;
  final DateTime createdAt;
  final DateTime? diperbaruiAt;
  final DateTime? selesaiAt;

  OrderModel({
    required this.id,
    required this.serviceId,
    required this.uidPenyedia,
    required this.namaPenyedia,
    required this.uidPemesan,
    required this.namaPemesan,
    this.telpPemesan = '',
    this.kategori = '',
    this.namaLayanan = '',
    this.paketId = '',
    this.harga = 0,
    this.satuan = '',
    this.jumlah = 1,
    this.estimasiBiaya = 0,
    this.deskripsi = '',
    this.foto = const [],
    required this.tanggal,
    this.jam = '',
    this.mode = 'datang',
    this.alamat = '',
    this.lat = 0,
    this.lng = 0,
    this.status = 'menunggu',
    this.hargaFinal,
    this.tanggalFinal,
    this.catatanPenyedia = '',
    this.alasanBatal = '',
    this.dibatalkanOleh = '',
    this.lunas = false,
    this.sudahDiulas = false,
    this.log = const [],
    required this.createdAt,
    this.diperbaruiAt,
    this.selesaiAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final logs = <OrderLog>[];
    final raw = d['log'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) logs.add(OrderLog.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    return OrderModel(
      id: doc.id,
      serviceId: d['service_id'] ?? '',
      uidPenyedia: d['uid_penyedia'] ?? '',
      namaPenyedia: d['nama_penyedia'] ?? '',
      uidPemesan: d['uid_pemesan'] ?? '',
      namaPemesan: d['nama_pemesan'] ?? '',
      telpPemesan: d['telp_pemesan'] ?? '',
      kategori: d['kategori'] ?? '',
      namaLayanan: d['nama_layanan'] ?? '',
      paketId: d['paket_id'] ?? '',
      harga: ((d['harga'] ?? 0) as num).toInt(),
      satuan: d['satuan'] ?? '',
      jumlah: ((d['jumlah'] ?? 1) as num).toInt(),
      estimasiBiaya: ((d['estimasi_biaya'] ?? 0) as num).toInt(),
      deskripsi: d['deskripsi'] ?? '',
      foto: List<String>.from(d['foto'] ?? const []),
      tanggal: _ts(d['tanggal']) ?? DateTime.now(),
      jam: d['jam'] ?? '',
      mode: d['mode'] ?? 'datang',
      alamat: d['alamat'] ?? '',
      lat: (d['lat'] ?? 0).toDouble(),
      lng: (d['lng'] ?? 0).toDouble(),
      status: d['status'] ?? 'menunggu',
      hargaFinal: d['harga_final'] == null ? null : (d['harga_final'] as num).toInt(),
      tanggalFinal: _ts(d['tanggal_final']),
      catatanPenyedia: d['catatan_penyedia'] ?? '',
      alasanBatal: d['alasan_batal'] ?? '',
      dibatalkanOleh: d['dibatalkan_oleh'] ?? '',
      lunas: d['lunas'] ?? false,
      sudahDiulas: d['sudah_diulas'] ?? false,
      log: logs,
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
      diperbaruiAt: _ts(d['diperbarui_at']),
      selesaiAt: _ts(d['selesai_at']),
    );
  }

  /// Biaya yang berlaku: harga kesepakatan bila ada, jika tidak estimasi.
  int get biayaAkhir => hargaFinal ?? estimasiBiaya;
  DateTime get tanggalAkhir => tanggalFinal ?? tanggal;

  /// Masih berjalan (belum selesai / batal / ditolak)
  bool get berjalan =>
      status != 'selesai' && status != 'ditolak' && status != 'dibatalkan';

  bool get bisaDibatalkan =>
      status == 'menunggu' ||
      status == 'nego' ||
      status == 'diterima';

  /// Perlu tindakan penyedia (badge)
  bool get perluTindakanPenyedia => status == 'menunggu';

  /// Perlu tindakan pemesan (badge)
  bool get perluTindakanPemesan =>
      status == 'nego' ||
      status == 'menunggu_konfirmasi' ||
      (status == 'selesai' && !sudahDiulas);

  static String labelStatus(String s) {
    switch (s) {
      case 'menunggu':
        return 'Menunggu Konfirmasi';
      case 'nego':
        return 'Menunggu Persetujuan Anda';
      case 'diterima':
        return 'Diterima';
      case 'dikerjakan':
        return 'Sedang Dikerjakan';
      case 'menunggu_konfirmasi':
        return 'Menunggu Konfirmasi Selesai';
      case 'selesai':
        return 'Selesai';
      case 'ditolak':
        return 'Ditolak';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return s;
    }
  }

  /// Label dari sisi penyedia (status "nego" = menunggu jawaban pemesan)
  static String labelStatusPenyedia(String s) {
    if (s == 'nego') return 'Menunggu Jawaban Pemesan';
    if (s == 'menunggu_konfirmasi') return 'Menunggu Konfirmasi Pemesan';
    return labelStatus(s);
  }

  static Color warnaStatus(String s) {
    switch (s) {
      case 'menunggu':
        return const Color(0xFFF57C00);
      case 'nego':
        return const Color(0xFF6A1B9A);
      case 'diterima':
        return const Color(0xFF1565C0);
      case 'dikerjakan':
        return const Color(0xFF00838F);
      case 'menunggu_konfirmasi':
        return const Color(0xFFEF6C00);
      case 'selesai':
        return const Color(0xFF2E7D32);
      case 'ditolak':
      case 'dibatalkan':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF546E7A);
    }
  }

  static IconData ikonStatus(String s) {
    switch (s) {
      case 'menunggu':
        return Icons.hourglass_top_outlined;
      case 'nego':
        return Icons.handshake_outlined;
      case 'diterima':
        return Icons.check_circle_outline;
      case 'dikerjakan':
        return Icons.build_circle_outlined;
      case 'menunggu_konfirmasi':
        return Icons.fact_check_outlined;
      case 'selesai':
        return Icons.task_alt;
      case 'ditolak':
        return Icons.block;
      case 'dibatalkan':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
