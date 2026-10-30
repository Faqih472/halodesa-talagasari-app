import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons;

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

  // ─── Data profil tambahan ────────────────────────────────
  final String bio;
  final String jenisKelamin; // 'laki-laki' | 'perempuan' | ''
  final DateTime? tanggalLahir;

  // ─── Alamat tempat tinggal ───────────────────────────────
  final String alamatLengkap;
  final String alamatRt;
  final String alamatRw;
  final String alamatDusun;
  final String alamatPatokan;

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
    this.bio = '',
    this.jenisKelamin = '',
    this.tanggalLahir,
    this.alamatLengkap = '',
    this.alamatRt = '',
    this.alamatRw = '',
    this.alamatDusun = '',
    this.alamatPatokan = '',
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
      bio: data['bio'] ?? '',
      jenisKelamin: data['jenis_kelamin'] ?? '',
      tanggalLahir: (data['tanggal_lahir'] as Timestamp?)?.toDate(),
      alamatLengkap: data['alamat_lengkap'] ?? '',
      alamatRt: data['alamat_rt'] ?? '',
      alamatRw: data['alamat_rw'] ?? '',
      alamatDusun: data['alamat_dusun'] ?? '',
      alamatPatokan: data['alamat_patokan'] ?? '',
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
      'bio': bio,
      'jenis_kelamin': jenisKelamin,
      if (tanggalLahir != null) 'tanggal_lahir': Timestamp.fromDate(tanggalLahir!),
      'alamat_lengkap': alamatLengkap,
      'alamat_rt': alamatRt,
      'alamat_rw': alamatRw,
      'alamat_dusun': alamatDusun,
      'alamat_patokan': alamatPatokan,
    };
  }

  /// Alamat sudah diisi?
  bool get punyaAlamat => alamatLengkap.trim().isNotEmpty;

  /// Alamat lengkap satu baris: alamat, dusun, RT/RW, patokan.
  String get alamatPenuh {
    final a = alamatLengkap.trim();
    if (a.isEmpty) return '';
    final up = a.toUpperCase();
    final bagian = <String>[a];
    if (alamatDusun.trim().isNotEmpty &&
        !up.contains(alamatDusun.trim().toUpperCase())) {
      bagian.add(alamatDusun.trim());
    }
    if (!RegExp(r'\bRT\b').hasMatch(up) &&
        (alamatRt.trim().isNotEmpty || alamatRw.trim().isNotEmpty)) {
      bagian.add('RT ${alamatRt.trim()}/RW ${alamatRw.trim()}');
    }
    if (alamatPatokan.trim().isNotEmpty) {
      bagian.add('Patokan: ${alamatPatokan.trim()}');
    }
    return bagian.join(', ');
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

  /// Identitas (KTP) sudah diverifikasi Admin → lencana "Terverifikasi"
  bool get ktpVerified => isVerified;

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
  final DateTime? berlakuSampai; // WAJIB untuk informasi baru; null = data lama (akan dihapus otomatis)

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
    this.berlakuSampai,
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
      berlakuSampai: (data['berlaku_sampai'] as Timestamp?)?.toDate(),
    );
  }

  /// Sudah lewat batas berlaku → tidak ditampilkan di beranda
  bool get kadaluarsa =>
      berlakuSampai != null && DateTime.now().isAfter(berlakuSampai!);

  /// Data lama tanpa masa berlaku (permanen) → tidak lagi diizinkan;
  /// dihapus otomatis oleh RetensiService dan disembunyikan dari beranda.
  bool get permanen => berlakuSampai == null;

  /// Sisa hari tayang (untuk label "berakhir x hari lagi")
  int get sisaHari => berlakuSampai == null
      ? 0
      : berlakuSampai!.difference(DateTime.now()).inDays;

  /// Kategori sensitif (butuh persetujuan Kades)
  bool get sensitif => isKategoriSensitif(kategori);

  Map<String, dynamic> toMap() {
    return {
      'berlaku_sampai':
          berlakuSampai != null ? Timestamp.fromDate(berlakuSampai!) : null,
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
// JASA LOKAL — jam operasional, paket layanan, profil penyedia
// penyedia_jasa/{id}  (+ subkoleksi reviews, portofolio)
// ─────────────────────────────────────────────

/// Format rupiah tanpa paket tambahan: 150000 → "Rp 150.000"
String rupiah(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}Rp $b';
}

/// Jam operasional satu hari. Menit dihitung dari tengah malam (08:00 = 480).
class JamHari {
  final bool aktif;
  final int mulai;
  final int selesai;

  const JamHari({this.aktif = true, this.mulai = 480, this.selesai = 1020});

  factory JamHari.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const JamHari();
    return JamHari(
      aktif: m['aktif'] ?? true,
      mulai: ((m['mulai'] ?? 480) as num).toInt(),
      selesai: ((m['selesai'] ?? 1020) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() =>
      {'aktif': aktif, 'mulai': mulai, 'selesai': selesai};

  JamHari copyWith({bool? aktif, int? mulai, int? selesai}) => JamHari(
        aktif: aktif ?? this.aktif,
        mulai: mulai ?? this.mulai,
        selesai: selesai ?? this.selesai,
      );

  static String format(int menit) =>
      '${(menit ~/ 60).toString().padLeft(2, '0')}:${(menit % 60).toString().padLeft(2, '0')}';

  String get label => aktif ? '${format(mulai)} – ${format(selesai)}' : 'Libur';

  bool bukaPada(int menitSekarang) =>
      aktif && menitSekarang >= mulai && menitSekarang < selesai;
}

/// Satu paket / jenis layanan di katalog penyedia (maks. 10).
class PaketJasa {
  final String id;
  final String nama;
  final String deskripsi;
  final int harga; // 0 = harga dinegosiasikan
  final String satuan; // contoh: 'per jam', 'per kg'

  const PaketJasa({
    required this.id,
    required this.nama,
    this.deskripsi = '',
    this.harga = 0,
    this.satuan = 'per paket',
  });

  factory PaketJasa.fromMap(Map<String, dynamic> m) => PaketJasa(
        id: (m['id'] ?? '').toString(),
        nama: (m['nama'] ?? '').toString(),
        deskripsi: (m['deskripsi'] ?? '').toString(),
        harga: ((m['harga'] ?? 0) as num).toInt(),
        satuan: (m['satuan'] ?? 'per paket').toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'deskripsi': deskripsi,
        'harga': harga,
        'satuan': satuan,
      };

  String get labelHarga => harga <= 0 ? 'Nego' : '${rupiah(harga)} $satuan';
}

/// Foto portofolio (subkoleksi penyedia_jasa/{id}/portofolio)
class PortofolioFoto {
  final String id;
  final String foto;
  const PortofolioFoto({required this.id, required this.foto});
}

/// Isian formulir profil jasa (dipakai saat daftar & edit).
class ProfilJasaInput {
  String namaUsaha;
  String kategori;
  List<String> tag;
  String deskripsi;
  int pengalamanTahun;
  String whatsapp;
  String alamatUsaha;
  double lat;
  double lng;
  String modeLayanan; // 'datang' | 'tempat' | 'keduanya'
  double areaKm;
  String tarifSatuan;
  int tarifMulai;
  int tarifMaks;
  int kapasitasAktif; // 0 = tanpa batas
  Map<int, JamHari> jadwal;
  List<DateTime> tanggalLibur;
  List<PaketJasa> paket;

  ProfilJasaInput({
    this.namaUsaha = '',
    this.kategori = 'tukang',
    List<String>? tag,
    this.deskripsi = '',
    this.pengalamanTahun = 0,
    this.whatsapp = '',
    this.alamatUsaha = '',
    this.lat = -6.239265,
    this.lng = 106.530200,
    this.modeLayanan = 'keduanya',
    this.areaKm = 5,
    this.tarifSatuan = 'per hari',
    this.tarifMulai = 0,
    this.tarifMaks = 0,
    this.kapasitasAktif = 0,
    Map<int, JamHari>? jadwal,
    List<DateTime>? tanggalLibur,
    List<PaketJasa>? paket,
  })  : tag = tag ?? <String>[],
        jadwal = jadwal ?? ServiceModel.jadwalBawaan(),
        tanggalLibur = tanggalLibur ?? <DateTime>[],
        paket = paket ?? <PaketJasa>[];

  Map<String, dynamic> toMap() => {
        'nama_usaha': namaUsaha.trim(),
        'kategori': kategori,
        'tag': tag,
        'deskripsi': deskripsi.trim(),
        'pengalaman_tahun': pengalamanTahun,
        'whatsapp': whatsapp.trim(),
        'alamat_usaha': alamatUsaha.trim(),
        'lokasi_lat': lat,
        'lokasi_lng': lng,
        'mode_layanan': modeLayanan,
        'area_km': areaKm,
        'tarif_satuan': tarifSatuan,
        'tarif_mulai': tarifMulai,
        'tarif_maks': tarifMaks,
        'kapasitas_aktif': kapasitasAktif,
        'jadwal': {for (final e in jadwal.entries) '${e.key}': e.value.toMap()},
        'tanggal_libur': tanggalLibur
            .map((d) => Timestamp.fromDate(DateTime(d.year, d.month, d.day)))
            .toList(),
        'layanan': paket.map((p) => p.toMap()).toList(),
      };
}

class ServiceModel {
  final String id;
  final String uidPenyedia;
  final String namaPenyedia; // nama pemilik akun
  final String namaUsaha; // nama usaha / panggilan jasa (opsional)
  final String fotoUrl; // foto profil pemilik
  final String fotoSampul; // miniatur kecil untuk kartu daftar
  final String kategori;
  final List<String> tag;
  final String deskripsi;
  final List<String> fotoPortofolio; // data lama (sebelum subkoleksi)
  final double lokasiLat;
  final double lokasiLng;
  final String alamatUsaha;
  final String status; // 'pending' | 'aktif' | 'nonaktif' | 'ditolak' | 'diblokir'
  final String? alasanPenolakan;
  final bool dikunci; // dinonaktifkan/diblokir Admin → pemilik tak bisa mengaktifkan
  final DateTime createdAt;
  final DateTime? diperbaruiAt;
  final bool ktpOk;

  // ─── Rating ─────────────────────────────────────────────
  final double ratingAvg;
  final int ratingCount;
  final Map<int, int> ratingDist; // bintang → jumlah
  final Map<String, double> aspekSum; // kualitas, ketepatan, komunikasi
  final int aspekN;

  // ─── Ketersediaan ───────────────────────────────────────
  final String ketersediaan; // 'buka' | 'penuh' | 'tutup'
  final String ketersediaanCatatan;
  final DateTime? tutupSampai;
  final bool penuhOtomatis;
  final Map<int, JamHari> jadwal; // 1 = Senin … 7 = Minggu (kosong = 24 jam)
  final List<DateTime> tanggalLibur;
  final int kapasitasAktif; // 0 = tanpa batas

  //UPDATE
  // ─── Tarif & layanan ────────────────────────────────────
  final int tarifMulai;
  final int tarifMaks;
  final String tarifSatuan;
  final String modeLayanan;
  final double areaKm;
  final int pengalamanTahun;
  final String whatsapp;
  final List<PaketJasa> paket;

  // ─── Statistik & kurasi ─────────────────────────────────
  final bool unggulan; // "Pilihan Desa" (ditetapkan Admin)
  final int peringatan;
  final int dilihat;
  final int dihubungi;
  final int pesananTotal;
  final int pesananSelesai;

  // Dihitung saat runtime (tidak di Firestore)
  double? jarakKm;

  ServiceModel({
    required this.id,
    required this.uidPenyedia,
    required this.namaPenyedia,
    this.namaUsaha = '',
    this.fotoUrl = '',
    this.fotoSampul = '',
    required this.kategori,
    this.tag = const [],
    required this.deskripsi,
    this.fotoPortofolio = const [],
    required this.lokasiLat,
    required this.lokasiLng,
    this.alamatUsaha = '',
    required this.status,
    this.alasanPenolakan,
    this.dikunci = false,
    required this.createdAt,
    this.diperbaruiAt,
    this.ktpOk = false,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.ratingDist = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    this.aspekSum = const {},
    this.aspekN = 0,
    this.ketersediaan = 'buka',
    this.ketersediaanCatatan = '',
    this.tutupSampai,
    this.penuhOtomatis = false,
    this.jadwal = const {},
    this.tanggalLibur = const [],
    this.kapasitasAktif = 0,
    this.tarifMulai = 0,
    this.tarifMaks = 0,
    this.tarifSatuan = 'per hari',
    this.modeLayanan = 'keduanya',
    this.areaKm = 5,
    this.pengalamanTahun = 0,
    this.whatsapp = '',
    this.paket = const [],
    this.unggulan = false,
    this.peringatan = 0,
    this.dilihat = 0,
    this.dihubungi = 0,
    this.pesananTotal = 0,
    this.pesananSelesai = 0,
    this.jarakKm,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final jd = <int, JamHari>{};
    final rawJ = data['jadwal'];
    if (rawJ is Map) {
      rawJ.forEach((k, v) {
        final h = int.tryParse('$k');
        if (h != null && v is Map) {
          jd[h] = JamHari.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final rawD = data['rating_dist'];
    if (rawD is Map) {
      rawD.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && dist.containsKey(i) && v is num) dist[i] = v.toInt();
      });
    }

    final asp = <String, double>{};
    final rawA = data['aspek_sum'];
    if (rawA is Map) {
      rawA.forEach((k, v) {
        if (v is num) asp['$k'] = v.toDouble();
      });
    }

    final paket = <PaketJasa>[];
    final rawP = data['layanan'];
    if (rawP is List) {
      for (final p in rawP) {
        if (p is Map) paket.add(PaketJasa.fromMap(Map<String, dynamic>.from(p)));
      }
    }

    final libur = <DateTime>[];
    final rawL = data['tanggal_libur'];
    if (rawL is List) {
      for (final t in rawL) {
        if (t is Timestamp) libur.add(t.toDate());
      }
    }

    int n(String k) => ((data[k] ?? 0) as num).toInt();

    return ServiceModel(
      id: doc.id,
      uidPenyedia: data['uid_penyedia'] ?? '',
      namaPenyedia: data['nama_penyedia'] ?? '',
      namaUsaha: data['nama_usaha'] ?? '',
      fotoUrl: data['foto_url'] ?? '',
      fotoSampul: data['foto_sampul'] ?? '',
      kategori: data['kategori'] ?? '',
      tag: List<String>.from(data['tag'] ?? const []),
      deskripsi: data['deskripsi'] ?? '',
      fotoPortofolio: List<String>.from(data['foto_portofolio'] ?? const []),
      lokasiLat: (data['lokasi_lat'] ?? -6.239265).toDouble(),
      lokasiLng: (data['lokasi_lng'] ?? 106.530200).toDouble(),
      alamatUsaha: data['alamat_usaha'] ?? '',
      status: data['status'] ?? 'pending',
      alasanPenolakan: data['alasan_penolakan'],
      dikunci: data['dikunci'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      diperbaruiAt: (data['diperbarui_at'] as Timestamp?)?.toDate(),
      ktpOk: data['ktp_ok'] ?? false,
      ratingAvg: (data['rating_avg'] ?? 0.0).toDouble(),
      ratingCount: n('rating_count'),
      ratingDist: dist,
      aspekSum: asp,
      aspekN: n('aspek_n'),
      ketersediaan: data['ketersediaan'] ?? 'buka',
      ketersediaanCatatan: data['ketersediaan_catatan'] ?? '',
      tutupSampai: (data['tutup_sampai'] as Timestamp?)?.toDate(),
      penuhOtomatis: data['penuh_otomatis'] ?? false,
      jadwal: jd,
      tanggalLibur: libur,
      kapasitasAktif: n('kapasitas_aktif'),
      tarifMulai: n('tarif_mulai'),
      tarifMaks: n('tarif_maks'),
      tarifSatuan: data['tarif_satuan'] ?? 'per hari',
      modeLayanan: data['mode_layanan'] ?? 'keduanya',
      areaKm: (data['area_km'] ?? 5).toDouble(),
      pengalamanTahun: n('pengalaman_tahun'),
      whatsapp: data['whatsapp'] ?? '',
      paket: paket,
      unggulan: data['unggulan'] ?? false,
      peringatan: n('peringatan'),
      dilihat: n('dilihat'),
      dihubungi: n('dihubungi'),
      pesananTotal: n('pesanan_total'),
      pesananSelesai: n('pesanan_selesai'),
    );
  }

  /// Salin data profil ke bentuk isian formulir (untuk mode edit).
  ProfilJasaInput keInput() => ProfilJasaInput(
        namaUsaha: namaUsaha,
        kategori: kategori,
        tag: List<String>.from(tag),
        deskripsi: deskripsi,
        pengalamanTahun: pengalamanTahun,
        whatsapp: whatsapp,
        alamatUsaha: alamatUsaha,
        lat: lokasiLat,
        lng: lokasiLng,
        modeLayanan: modeLayanan,
        areaKm: areaKm,
        tarifSatuan: tarifSatuan,
        tarifMulai: tarifMulai,
        tarifMaks: tarifMaks,
        kapasitasAktif: kapasitasAktif,
        jadwal: jadwal.isEmpty
            ? jadwalBawaan()
            : Map<int, JamHari>.from(jadwal),
        tanggalLibur: List<DateTime>.from(tanggalLibur),
        paket: List<PaketJasa>.from(paket),
      );

  // ─── Nama & foto yang ditampilkan ───────────────────────
  String get nama => namaUsaha.trim().isNotEmpty ? namaUsaha.trim() : namaPenyedia;
  String get fotoKartu => fotoSampul.isNotEmpty ? fotoSampul : fotoUrl;
  bool get diblokir => status == 'diblokir';
  bool isMilikSaya(String uid) => uidPenyedia == uid;

  // ─── Ketersediaan ───────────────────────────────────────
  /// Status manual yang BERLAKU. Bila tanggal "buka lagi" sudah lewat,
  /// otomatis dianggap buka kembali.
  String get ketersediaanEfektif {
    if (ketersediaan == 'buka') return 'buka';
    if (tutupSampai != null && DateTime.now().isAfter(tutupSampai!)) {
      return 'buka';
    }
    return ketersediaan;
  }

  bool sedangLibur(DateTime d) => tanggalLibur
      .any((t) => t.year == d.year && t.month == d.month && t.day == d.day);

  bool dalamJamKerja(DateTime n) {
    if (jadwal.isEmpty) return true; // belum diatur = dianggap selalu buka
    final j = jadwal[n.weekday];
    if (j == null) return false;
    return j.bukaPada(n.hour * 60 + n.minute);
  }

  /// 'buka' | 'di_luar_jam' | 'penuh' | 'libur' | 'tutup'
  String statusSekarang([DateTime? sekarang]) {
    final n = sekarang ?? DateTime.now();
    final ket = ketersediaanEfektif;
    if (ket == 'tutup') return 'tutup';
    if (ket == 'penuh') return 'penuh';
    if (sedangLibur(n)) return 'libur';
    if (!dalamJamKerja(n)) return 'di_luar_jam';
    return 'buka';
  }

  bool get sedangBuka => statusSekarang() == 'buka';

  /// Alasan jasa tidak bisa dipesan pada tanggal tertentu (null = bisa).
  String? alasanTidakBisaDipesan(DateTime tanggal) {
    if (status != 'aktif') return 'Penyedia jasa sedang tidak aktif.';
    final t = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final sk = DateTime.now();
    final h0 = DateTime(sk.year, sk.month, sk.day);
    if (t.isBefore(h0)) return 'Tanggal sudah lewat.';
    if (ketersediaan != 'buka' &&
        (tutupSampai == null || !t.isAfter(tutupSampai!))) {
      return ketersediaan == 'penuh'
          ? 'Penyedia sedang penuh dan belum menerima pesanan baru.'
          : 'Penyedia sedang tutup / libur pada tanggal itu.';
    }
    if (sedangLibur(t)) return 'Penyedia libur pada tanggal itu.';
    if (jadwal.isNotEmpty) {
      final j = jadwal[t.weekday];
      if (j == null || !j.aktif) {
        return 'Penyedia tidak beroperasi pada hari ${namaHari(t.weekday)}.';
      }
    }
    return null;
  }

  // ─── Rating ─────────────────────────────────────────────
  /// Rating terbobot (Bayesian) agar 1 ulasan bintang 5 tidak langsung
  /// mengalahkan penyedia dengan puluhan ulasan bagus.
  double get ratingTerbobot =>
      (ratingAvg * ratingCount + 4.0 * 3) / (ratingCount + 3);

  double aspekRata(String kunci) =>
      aspekN > 0 ? (aspekSum[kunci] ?? 0) / aspekN : 0;

  /// Skor urutan "Rekomendasi".
  double get skorRekomendasi {
    double skor = 0;
    final st = statusSekarang();
    if (st == 'buka') {
      skor += 100;
    } else if (st == 'di_luar_jam') {
      skor += 40;
    } else if (st == 'libur') {
      skor += 10;
    }
    if (unggulan) skor += 30;
    skor += ratingTerbobot * 12;
    skor += (pesananSelesai > 40 ? 40 : pesananSelesai) * 0.5;
    if (ktpOk) skor += 10;
    if (jarakKm != null) skor -= (jarakKm! > 20 ? 20 : jarakKm!) * 3;
    return skor;
  }

  // ─── Tarif ──────────────────────────────────────────────
  String get labelTarif {
    if (tarifMulai <= 0) return 'Tarif nego';
    if (tarifMaks > tarifMulai) {
      return '${rupiah(tarifMulai)} – ${rupiah(tarifMaks)} $tarifSatuan';
    }
    return 'Mulai ${rupiah(tarifMulai)} $tarifSatuan';
  }

  // ─── Pencarian teks ─────────────────────────────────────
  bool cocokKata(String q) {
    final k = q.trim().toLowerCase();
    if (k.isEmpty) return true;
    final gudang = [
      nama,
      namaPenyedia,
      deskripsi,
      AppUtilsLabel.kategori(kategori),
      ...tag,
      ...paket.map((p) => p.nama),
      alamatUsaha,
    ].join(' ').toLowerCase();
    return k.split(RegExp(r'\s+')).every((w) => gudang.contains(w));
  }

  // ─── Label & warna ──────────────────────────────────────
  static String labelKetersediaan(String k) {
    switch (k) {
      case 'penuh':
        return 'Penuh';
      case 'tutup':
        return 'Tutup / Libur';
      default:
        return 'Buka';
    }
  }

  static Color warnaKetersediaan(String k) {
    switch (k) {
      case 'penuh':
        return const Color(0xFFE65100);
      case 'tutup':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static String labelStatusSekarang(String k) {
    switch (k) {
      case 'buka':
        return 'Buka sekarang';
      case 'di_luar_jam':
        return 'Di luar jam kerja';
      case 'penuh':
        return 'Penuh';
      case 'libur':
        return 'Libur hari ini';
      default:
        return 'Tutup';
    }
  }

  static Color warnaStatusSekarang(String k) {
    switch (k) {
      case 'buka':
        return const Color(0xFF2E7D32);
      case 'di_luar_jam':
        return const Color(0xFF546E7A);
      case 'penuh':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFFC62828);
    }
  }

  static String labelMode(String m) {
    switch (m) {
      case 'datang':
        return 'Penyedia datang ke rumah warga';
      case 'tempat':
        return 'Warga datang ke tempat penyedia';
      default:
        return 'Datang ke rumah / warga datang ke tempat';
    }
  }

  static String labelModePendek(String m) {
    switch (m) {
      case 'datang':
        return 'Datang ke rumah';
      case 'tempat':
        return 'Di tempat penyedia';
      default:
        return 'Datang / di tempat';
    }
  }

  static String namaHari(int weekday) => const [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu'
      ][(weekday - 1) % 7];

  /// Jadwal bawaan: Senin–Sabtu 08:00–17:00, Minggu libur.
  static Map<int, JamHari> jadwalBawaan() => {
        for (int h = 1; h <= 7; h++)
          h: JamHari(aktif: h != 7, mulai: 480, selesai: 1020),
      };

  static const List<String> daftarSatuan = [
    'per jam',
    'per hari',
    'per proyek',
    'per servis',
    'per sesi',
    'per bulan',
    'per acara',
    'per kg',
    'per potong',
    'per porsi',
    'per paket',
    'per meter',
  ];

  static String satuanBawaan(String kategori) {
    switch (kategori) {
      case 'teknisi':
        return 'per servis';
      case 'guru_les':
        return 'per sesi';
      case 'fotografer':
        return 'per acara';
      case 'laundry':
        return 'per kg';
      case 'catering':
        return 'per porsi';
      default:
        return 'per hari';
    }
  }

  /// Saran kata kunci keahlian per kategori (hanya bantuan pengisian).
  static List<String> saranTag(String kategori) {
    switch (kategori) {
      case 'tukang':
        return ['Bangun rumah', 'Renovasi', 'Cat', 'Keramik', 'Atap', 'Pipa/ledeng', 'Listrik', 'Las/kanopi', 'Kayu'];
      case 'teknisi':
        return ['TV', 'Kulkas', 'Mesin cuci', 'AC', 'Kipas angin', 'HP', 'Laptop', 'Kompor/gas', 'Pompa air'];
      case 'guru_les':
        return ['SD', 'SMP', 'SMA', 'Matematika', 'Bahasa Inggris', 'Calistung', 'Mengaji', 'Kunjungan ke rumah', 'Online'];
      case 'fotografer':
        return ['Pernikahan', 'Khitanan', 'Wisuda', 'Acara desa', 'Pas foto', 'Produk', 'Video', 'Drone'];
      case 'laundry':
        return ['Kiloan', 'Satuan', 'Setrika', 'Karpet', 'Antar-jemput', 'Kebersihan rumah', 'Cuci sepatu'];
      case 'catering':
        return ['Nasi kotak', 'Hajatan', 'Tumpeng', 'Prasmanan', 'Kue/snack', 'Harian', 'Arisan'];
      default:
        return [];
    }
  }
}

/// Label kategori untuk pencarian teks (menghindari impor core.dart di models).
class AppUtilsLabel {
  static String kategori(String v) {
    switch (v) {
      case 'tukang':
        return 'Tukang Konstruksi';
      case 'teknisi':
        return 'Teknisi Elektronik';
      case 'guru_les':
        return 'Guru Les Pengajar';
      case 'fotografer':
        return 'Fotografer Videografer';
      case 'laundry':
        return 'Laundry Kebersihan';
      case 'catering':
        return 'Catering Masak';
      default:
        return v;
    }
  }
}

// ─────────────────────────────────────────────
// REVIEW MODEL — penyedia_jasa/{id}/reviews/{idPesanan}
// Satu ulasan per pesanan selesai (id dokumen = id pesanan).
// ─────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String idPengguna;
  final String namaPengguna;
  final int rating;
  final Map<String, int> aspek; // kualitas, ketepatan, komunikasi
  final String komentar;
  final String balasan; // balasan penyedia jasa
  final DateTime? balasanAt;
  final bool tampil; // false = disembunyikan Admin
  final String orderId;
  final String namaLayanan;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.idPengguna,
    required this.namaPengguna,
    required this.rating,
    this.aspek = const {},
    required this.komentar,
    this.balasan = '',
    this.balasanAt,
    this.tampil = true,
    this.orderId = '',
    this.namaLayanan = '',
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final asp = <String, int>{};
    final raw = data['aspek'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) asp['$k'] = v.toInt();
      });
    }
    return ReviewModel(
      id: doc.id,
      idPengguna: data['id_pengguna'] ?? '',
      namaPengguna: data['nama_pengguna'] ?? '',
      rating: ((data['rating'] ?? 0) as num).toInt(),
      aspek: asp,
      komentar: data['komentar'] ?? '',
      balasan: data['balasan'] ?? '',
      balasanAt: (data['balasan_at'] as Timestamp?)?.toDate(),
      tampil: data['tampil'] ?? true,
      orderId: data['order_id'] ?? '',
      namaLayanan: data['nama_layanan'] ?? '',
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
      case 'pesanan':
        return Icons.receipt_long_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'sistem':
        return Icons.settings_outlined;
      case 'pengaduan':
        return Icons.report_gmailerrorred_outlined;
      case 'sos':
        return Icons.sos;
      case 'surat':
        return Icons.description_outlined;
      case 'agenda':
        return Icons.event_outlined;
      case 'domisili':
        return Icons.home_work_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }
}


// ─────────────────────────────────────────────
// PENGADUAN WARGA
// Alur: menunggu_review (Admin saring) →
//   ringan: diproses (Admin) → selesai
//   berat : pending_kades → diproses (Kades) → selesai
//   atau ditolak (dengan alasan) di tahap review.
// ─────────────────────────────────────────────
class ComplaintModel {
  final String id;
  final String uidPelapor;
  final String namaPelapor;
  final String kategori;
  final String judul;
  final String isi;
  final List<String> fotoUrls;
  final double lat;
  final double lng;
  final String alamat;
  final bool rahasia; // nama pelapor disembunyikan dari Kades
  final String status;
  final String penanganan; // 'admin' | 'kades' | ''
  final String? alasanPenolakan;
  final String? tanggapan;
  final DateTime createdAt;
  final DateTime? tglKejadian;
  final String terlapor; // opsional
  final int rating; // 0 = belum dinilai
  final String ulasanRating;

  ComplaintModel({
    required this.id,
    required this.uidPelapor,
    required this.namaPelapor,
    required this.kategori,
    required this.judul,
    required this.isi,
    this.fotoUrls = const [],
    this.lat = 0,
    this.lng = 0,
    this.alamat = '',
    this.rahasia = false,
    required this.status,
    this.penanganan = '',
    this.alasanPenolakan,
    this.tanggapan,
    required this.createdAt,
    this.tglKejadian,
    this.terlapor = '',
    this.rating = 0,
    this.ulasanRating = '',
  });

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ComplaintModel(
      id: doc.id,
      uidPelapor: d['uid_pelapor'] ?? '',
      namaPelapor: d['nama_pelapor'] ?? '',
      kategori: d['kategori'] ?? 'lainnya',
      judul: d['judul'] ?? '',
      isi: d['isi'] ?? '',
      fotoUrls: List<String>.from(d['foto_urls'] ?? const []),
      lat: (d['lat'] ?? 0).toDouble(),
      lng: (d['lng'] ?? 0).toDouble(),
      alamat: d['alamat'] ?? '',
      rahasia: d['rahasia'] ?? false,
      status: d['status'] ?? 'menunggu_review',
      penanganan: d['penanganan'] ?? '',
      alasanPenolakan: d['alasan_penolakan'],
      tanggapan: d['tanggapan'],
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tglKejadian: (d['tanggal_kejadian'] as Timestamp?)?.toDate(),
      terlapor: d['terlapor'] ?? '',
      rating: ((d['rating'] ?? 0) as num).toInt(),
      ulasanRating: d['ulasan_rating'] ?? '',
    );
  }

  /// Batas waktu respons: 3 hari sejak laporan masuk
  static const int batasHari = 3;

  /// Masih menunggu Admin/Kades dan sudah lewat batas waktu
  bool get lewatBatas =>
      (status == 'menunggu_review' || status == 'pending_kades') &&
      DateTime.now().difference(createdAt).inDays >= batasHari;

  /// Kategori yang harus diteruskan ke Kepala Desa
  bool get isBerat => kategoriBerat.contains(kategori);

  static const List<String> kategoriBerat = ['keamanan', 'kekerasan'];

  /// value, label, ikon
  static const List<Map<String, String>> daftarKategori = [
    {'value': 'sampah', 'label': 'Sampah & Kebersihan'},
    {'value': 'jalan_rusak', 'label': 'Jalan / Fasilitas Rusak'},
    {'value': 'keamanan', 'label': 'Keamanan / Tawuran'},
    {'value': 'kekerasan', 'label': 'Kekerasan'},
    {'value': 'gangguan', 'label': 'Gangguan Ketertiban'},
    {'value': 'lingkungan', 'label': 'Lingkungan'},
    {'value': 'layanan_desa', 'label': 'Layanan Desa'},
    {'value': 'lainnya', 'label': 'Lainnya'},
  ];

  static String labelKategori(String v) => daftarKategori
      .firstWhere((k) => k['value'] == v,
          orElse: () => {'label': 'Lainnya'})['label']!;

  static IconData ikonKategori(String v) {
    switch (v) {
      case 'sampah':
        return Icons.delete_outline;
      case 'jalan_rusak':
        return Icons.add_road;
      case 'keamanan':
        return Icons.shield_outlined;
      case 'kekerasan':
        return Icons.warning_amber_outlined;
      case 'gangguan':
        return Icons.volume_up_outlined;
      case 'lingkungan':
        return Icons.park_outlined;
      case 'layanan_desa':
        return Icons.account_balance_outlined;
      default:
        return Icons.report_gmailerrorred_outlined;
    }
  }

  static String labelStatus(String s) {
    switch (s) {
      case 'menunggu_review':
        return 'Menunggu Review';
      case 'pending_kades':
        return 'Menunggu Kades';
      case 'diproses':
        return 'Diproses';
      case 'selesai':
        return 'Selesai';
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
      case 'diproses':
        return const Color(0xFF1565C0);
      case 'selesai':
        return const Color(0xFF2E7D32);
      case 'ditolak':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF616161);
    }
  }
}

// ─────────────────────────────────────────────
// VERIFIKASI KTP (koleksi terpisah: verifikasi_ktp/{uid})
// Sengaja TIDAK disimpan di dokumen users agar foto KTP tidak
// terbaca warga lain. Hanya pemilik & Admin yang boleh membaca.
// ─────────────────────────────────────────────
class KtpModel {
  final String uid;
  final String nama; // nama sesuai KTP
  final String email;
  final String status; // 'belum' | 'menunggu' | 'terverifikasi' | 'ditolak' | 'diblokir'
  final String nik;
  final String tempatLahir;
  final DateTime? tanggalLahir;
  final String jenisKelamin;
  final String alamat;
  final String rt;
  final String rw;
  final String telepon;
  final String? alasan;
  final DateTime? createdAt;
  final String fotoKtp; // foto 2: KTP saja (base64) — dihapus otomatis setelah diperiksa
  final String fotoSelfie; // foto 1: selfie kamera depan sambil memegang KTP (base64)

  KtpModel({
    required this.uid,
    this.nama = '',
    this.email = '',
    this.status = 'belum',
    this.nik = '',
    this.tempatLahir = '',
    this.tanggalLahir,
    this.jenisKelamin = '',
    this.alamat = '',
    this.rt = '',
    this.rw = '',
    this.telepon = '',
    this.alasan,
    this.createdAt,
    this.fotoKtp = '',
    this.fotoSelfie = '',
  });

  factory KtpModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return KtpModel(
      uid: doc.id,
      nama: d['nama'] ?? '',
      email: d['email'] ?? '',
      status: d['status'] ?? 'belum',
      nik: d['nik'] ?? '',
      tempatLahir: d['tempat_lahir'] ?? '',
      tanggalLahir: (d['tanggal_lahir'] as Timestamp?)?.toDate(),
      jenisKelamin: d['jenis_kelamin'] ?? '',
      alamat: d['alamat'] ?? '',
      rt: d['rt'] ?? '',
      rw: d['rw'] ?? '',
      telepon: d['telepon'] ?? '',
      alasan: d['alasan'],
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      fotoKtp: d['foto_ktp'] ?? '',
      fotoSelfie: d['foto_selfie'] ?? '',
    );
  }

  bool get terverifikasi => status == 'terverifikasi';
}
