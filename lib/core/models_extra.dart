// ============================================================
// models_extra.dart — Model untuk fitur lanjutan:
// aktivitas pengaduan, SOS, polling, agenda, surat online,
// audit log, laporan jasa.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'core.dart' show AppUtils;
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
  final String status; // 'baru' | 'diproses' | 'aman' | 'ditangani'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? posisiAt; // kapan titik GPS ini diambil
  final double akurasi;
  final String sumber; // 'gps' | 'terakhir' | 'tidak_ada'
  final String jenis; // medis | kebakaran | kejahatan | kecelakaan | bencana | lainnya
  final String keterangan;
  final String foto;
  final String petugas;
  final String hasil; // hasil penanganan
  final String catatan;
  final DateTime? ditanganiAt;
  final int rating; // 0 = belum menilai
  final String ulasan;

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
    required this.updatedAt,
    this.posisiAt,
    this.akurasi = 0,
    this.sumber = 'tidak_ada',
    this.jenis = 'lainnya',
    this.keterangan = '',
    this.foto = '',
    this.petugas = '',
    this.hasil = '',
    this.catatan = '',
    this.ditanganiAt,
    this.rating = 0,
    this.ulasan = '',
  });

  bool get punyaLokasi => sumber != 'tidak_ada' && !(lat == 0 && lng == 0);
  bool get aktif => status != 'ditangani';

  static const Map<String, String> labelJenis = {
    'medis': 'Medis / Sakit parah',
    'kebakaran': 'Kebakaran',
    'kejahatan': 'Kejahatan / Pencurian',
    'kecelakaan': 'Kecelakaan',
    'bencana': 'Bencana / Banjir',
    'lainnya': 'Darurat lainnya',
  };
  static const List<String> opsiHasil = [
    'Warga sudah ditolong / ditangani',
    'Dirujuk ke pihak berwenang (polisi / ambulans / damkar)',
    'Alarm palsu atau salah tekan',
    'Warga tidak ditemukan / tidak bisa dihubungi',
  ];

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
      updatedAt: _ts(d['updated_at']) ?? _ts(d['created_at']) ?? DateTime.now(),
      posisiAt: _ts(d['posisi_at']),
      akurasi: (d['akurasi'] ?? 0).toDouble(),
      sumber: d['sumber'] ?? 'tidak_ada',
      jenis: d['jenis'] ?? 'lainnya',
      keterangan: d['keterangan'] ?? '',
      foto: d['foto'] ?? '',
      petugas: d['petugas'] ?? '',
      hasil: d['hasil'] ?? '',
      catatan: d['catatan'] ?? '',
      ditanganiAt: _ts(d['ditangani_at']),
      rating: ((d['rating'] ?? 0) as num).toInt(),
      ulasan: d['ulasan'] ?? '',
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

/// Panduan singkat satu jenis surat (teks untuk warga awam)
class PanduanSurat {
  final IconData ikon;
  final String singkat;
  final List<String> untuk;
  final List<String> siapkan;
  final List<String> contohKeperluan;
  final String contohIsian;
  final String tips;

  const PanduanSurat({
    required this.ikon,
    required this.singkat,
    required this.untuk,
    required this.siapkan,
    required this.contohKeperluan,
    required this.contohIsian,
    required this.tips,
  });
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
  final Map<String, String> tambahan;

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
    this.tambahan = const {},
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
      tambahan: {
        for (final e in ((d['tambahan'] as Map?) ?? const {}).entries)
          e.key.toString(): (e.value ?? '').toString(),
      },
    );
  }

  String t(String k) => (tambahan[k] ?? '').trim();

  /// Label tampilan data tambahan
  static const Map<String, String> labelTambahan = {
    'agama': 'Agama',
    'status_kawin': 'Status Perkawinan',
    'pekerjaan': 'Pekerjaan',
    'tinggal_sejak': 'Tinggal sejak',
    'penghasilan': 'Penghasilan/bulan',
    'tanggungan': 'Jumlah tanggungan',
    'nama_usaha': 'Nama usaha',
    'jenis_usaha': 'Jenis usaha',
    'alamat_usaha': 'Alamat usaha',
    'lama_usaha': 'Lama usaha',
    'instansi': 'Instansi tujuan',
  };

  static String rupiah(String digit) {
    final d = digit.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return '-';
    final b = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
      b.write(d[i]);
    }
    return 'Rp $b';
  }

  /// Isi surat per jenis (dipakai PDF dan pratinjau di form).
  static String isiSurat(String jenis, Map<String, String> t) {
    String v(String k) => (t[k] ?? '').trim();
    switch (jenis) {
      case 'tidak_mampu':
        return 'Nama tersebut adalah benar warga Desa Talagasari, '
            'Kecamatan Cikupa, Kabupaten Tangerang. Berdasarkan keterangan yang '
            'bersangkutan dan data yang ada pada kami, yang bersangkutan tergolong '
            'keluarga kurang mampu secara ekonomi, dengan penghasilan kurang lebih '
            '${rupiah(v('penghasilan'))} per bulan dan jumlah tanggungan keluarga '
            '${v('tanggungan').isEmpty ? '-' : v('tanggungan')} orang.';
      case 'usaha':
        final lama = v('lama_usaha').isEmpty
            ? ''
            : ' Usaha tersebut telah berjalan kurang lebih ${v('lama_usaha')}.';
        return 'Nama tersebut adalah benar warga Desa Talagasari, '
            'Kecamatan Cikupa, Kabupaten Tangerang, yang memiliki dan menjalankan '
            'usaha ${v('jenis_usaha')} dengan nama "${v('nama_usaha')}"'
            '${v('alamat_usaha').isEmpty ? '' : ', beralamat di ${v('alamat_usaha')}'}.$lama';
      case 'pengantar':
        return 'Nama tersebut adalah benar warga Desa Talagasari, '
            'Kecamatan Cikupa, Kabupaten Tangerang. Surat ini diberikan sebagai '
            'pengantar kepada ${v('instansi')}.';
      default:
        final sejak = v('tinggal_sejak').isEmpty
            ? ''
            : ', dan bertempat tinggal di alamat tersebut sejak tahun ${v('tinggal_sejak')}';
        return 'Nama tersebut adalah benar warga yang berdomisili di '
            'Desa Talagasari, Kecamatan Cikupa, Kabupaten Tangerang, sesuai alamat '
            'tersebut di atas$sejak.';
    }
  }

  /// Butir data di badan surat (nomor, label, isi) — dipakai PDF dan pratinjau.
  List<List<String>> get butirData {
    String isi(String v) => v.trim().isEmpty ? '-' : v.trim();
    final String ttl =
        '${tempatLahir.isNotEmpty ? '$tempatLahir, ' : ''}${tanggalLahir != null ? AppUtils.formatTanggal(tanggalLahir!) : '-'}';
    final String jk = jenisKelamin == 'laki-laki'
        ? 'Laki-laki'
        : (jenisKelamin == 'perempuan' ? 'Perempuan' : '-');
    return [
      ['Nama Lengkap', isi(nama)],
      ['No KTP/NIK', isi(nik)],
      ['Jenis Kelamin', jk],
      ['Tempat Tanggal Lahir', ttl],
      ['Agama', isi(t('agama'))],
      ['Pekerjaan', isi(t('pekerjaan'))],
      ['Status Perkawinan', isi(t('status_kawin'))],
      ['Kewarganegaraan', 'Indonesia (WNI)'],
      ['Alamat', isi(alamat)],
    ];
  }

  /// Butir "Keterangan Lain" (bertitik/bullet).
  List<String> get keteranganLain => [
        isiSurat(jenis, tambahan),
        'Surat keterangan ini dibuat untuk keperluan: ${keperluan.isEmpty ? '........................' : keperluan}.',
        'Pemohon menyatakan bahwa data di atas benar dan bersedia mempertanggungjawabkannya sesuai ketentuan yang berlaku.',
        'Surat ini berlaku ${masaBulan(jenis)} bulan sejak tanggal ditandatangani.',
      ];

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

  /// Kalimat inti surat (dipakai PDF dan pratinjau di form pengajuan)
  static String kalimatUtama(String jenis) {
    switch (jenis) {
      case 'tidak_mampu':
        return 'adalah benar warga Desa Talagasari yang berdasarkan data kami tergolong kurang mampu secara ekonomi.';
      case 'usaha':
        return 'adalah benar warga Desa Talagasari yang memiliki usaha di wilayah desa kami.';
      case 'pengantar':
        return 'adalah benar warga Desa Talagasari. Surat ini diberikan sebagai pengantar.';
      default:
        return 'adalah benar warga yang berdomisili di wilayah Desa Talagasari.';
    }
  }

  /// Panduan untuk warga awam: surat ini untuk apa, contoh pemakaian, contoh isian.
  static PanduanSurat panduan(String jenis) {
    switch (jenis) {
      case 'tidak_mampu':
        return const PanduanSurat(
          ikon: Icons.volunteer_activism_outlined,
          singkat: 'Menerangkan bahwa keluarga Anda kurang mampu secara ekonomi.',
          untuk: [
            'Mengajukan keringanan biaya atau beasiswa sekolah',
            'Meminta keringanan biaya berobat',
            'Mengajukan bantuan sosial',
          ],
          siapkan: [
            'Identitas sudah terverifikasi di menu Akun',
            'Data Anda harus sesuai kenyataan; petugas desa dapat mengecek',
            'Saat tanda tangan di kantor desa, bawa KTP asli',
          ],
          contohKeperluan: [
            'Keringanan biaya sekolah anak',
            'Mengajukan beasiswa',
            'Keringanan biaya berobat',
            'Mengajukan bantuan sosial',
          ],
          contohIsian:
              'Untuk mengajukan keringanan biaya sekolah anak saya di SMP Contoh.',
          tips: 'Sebutkan siapa yang membutuhkan (Anda atau anak) dan di instansi mana surat dipakai.',
        );
      case 'usaha':
        return const PanduanSurat(
          ikon: Icons.storefront_outlined,
          singkat: 'Menerangkan bahwa Anda memiliki usaha di Desa Talagasari.',
          untuk: [
            'Mengajukan pinjaman atau modal usaha ke bank/koperasi',
            'Mengurus izin atau NIB usaha',
            'Mengajukan bantuan untuk pelaku usaha kecil',
          ],
          siapkan: [
            'Identitas sudah terverifikasi di menu Akun',
            'Usaha benar-benar berjalan di wilayah desa',
            'Tulis jenis, nama, dan alamat usaha di kolom keperluan',
            'Saat tanda tangan di kantor desa, bawa KTP asli',
          ],
          contohKeperluan: [
            'Pengajuan pinjaman modal usaha',
            'Mengurus NIB usaha',
            'Mengajukan bantuan pelaku usaha kecil',
          ],
          contohIsian:
              'Usaha warung makan "Warung Contoh" di Kp. Contoh RT 02/RW 03, untuk pengajuan pinjaman modal ke bank.',
          tips: 'Tulis jenis usaha, nama usaha, dan alamat usahanya.',
        );
      case 'pengantar':
        return const PanduanSurat(
          ikon: Icons.mail_outline,
          singkat: 'Surat pengantar dari desa untuk mengurus dokumen di instansi lain.',
          untuk: [
            'Mengurus surat di kantor kecamatan',
            'Mengurus SKCK di kepolisian',
            'Mengurus dokumen kependudukan (KTP, KK, akta)',
            'Urusan lain yang meminta pengantar dari desa',
          ],
          siapkan: [
            'Identitas sudah terverifikasi di menu Akun',
            'Tahu instansi tujuan dan urusannya',
            'Saat tanda tangan di kantor desa, bawa KTP asli',
          ],
          contohKeperluan: [
            'Pengantar mengurus SKCK',
            'Pengantar membuat Kartu Keluarga baru',
            'Pengantar mengurus surat di kecamatan',
          ],
          contohIsian: 'Pengantar untuk mengurus SKCK di kantor polisi setempat.',
          tips: 'Sebutkan instansi tujuan dan urusan yang akan Anda urus.',
        );
      default:
        return const PanduanSurat(
          ikon: Icons.home_work_outlined,
          singkat: 'Menerangkan bahwa Anda benar tinggal di Desa Talagasari.',
          untuk: [
            'Melamar kerja atau mendaftar sekolah/kuliah',
            'Membuka rekening bank atau mengurus BPJS',
            'Bukti tempat tinggal bagi yang mengontrak atau baru pindah',
            'Melengkapi syarat di instansi lain',
          ],
          siapkan: [
            'Identitas sudah terverifikasi di menu Akun',
            'Alamat pada identitas sesuai tempat tinggal Anda sekarang',
            'Saat tanda tangan di kantor desa, bawa KTP asli',
          ],
          contohKeperluan: [
            'Mendaftar CPNS / PPPK',
            'Mendaftar calon Tamtama TNI',
            'Mendaftar calon anggota Polri',
            'Melamar pekerjaan',
            'Membuka rekening bank',
            'Mendaftar sekolah anak',
            'Mengurus BPJS Kesehatan',
          ],
          contohIsian:
              'Untuk melengkapi syarat melamar pekerjaan di PT Contoh Sejahtera.',
          tips: 'Tulis tujuan surat dan nama tempat yang memintanya.',
        );
    }
  }

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


// ─────────────────────────────────────────────
// FOTO PROFIL MENUNGGU PERSETUJUAN — foto_profil_antri/{uid}
// ─────────────────────────────────────────────
class FotoAntri {
  final String uid;
  final String nama;
  final String foto; // data URL base64 (kosong bila ditolak)
  final String status; // menunggu | ditolak
  final String alasan;
  final DateTime createdAt;

  FotoAntri({
    required this.uid,
    required this.nama,
    this.foto = '',
    this.status = 'menunggu',
    this.alasan = '',
    required this.createdAt,
  });

  factory FotoAntri.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FotoAntri(
      uid: doc.id,
      nama: d['nama'] ?? '',
      foto: d['foto'] ?? '',
      status: d['status'] ?? 'menunggu',
      alasan: d['alasan'] ?? '',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  bool get menunggu => status == 'menunggu';
  bool get ditolak => status == 'ditolak';
}


// ═════════════════════════════════════════════════════════════
// BUTUH PEKERJA (lowongan dari warga) — lowongan_warga/{id}
// Lamaran — lamaran_kerja/{idLowongan_uidPelamar}
// ═════════════════════════════════════════════════════════════
class LowonganModel {
  final String id;
  final String uid;
  final String namaPemberi;
  final String fotoPemberi;
  final String whatsapp;
  final String judul;
  final String kategori;
  final String deskripsi;
  final String syarat;
  final String jenis; // harian | borongan | paruh_waktu | tetap
  final int jumlahOrang;
  final int diterima;
  final int upah; // 0 = dibicarakan
  final String satuanUpah;
  final bool upahNego;
  final String alamat;
  final DateTime? mulai;
  final DateTime batas;
  final String status; // aktif | ditutup | blokir
  final String alasan;
  final bool disetujui;
  final String hapusStatus; // '' | 'diajukan' | 'ditolak' | 'disetujui'
  final String hapusAlasan;
  final String hapusKeputusan;
  final List<String> fotoList;
  final double lat;
  final double lng;
  final DateTime createdAt;

  LowonganModel({
    required this.id,
    required this.uid,
    required this.namaPemberi,
    this.fotoPemberi = '',
    this.whatsapp = '',
    required this.judul,
    required this.kategori,
    required this.deskripsi,
    this.syarat = '',
    this.jenis = 'harian',
    this.jumlahOrang = 1,
    this.diterima = 0,
    this.upah = 0,
    this.satuanUpah = 'per hari',
    this.upahNego = false,
    this.alamat = '',
    this.mulai,
    required this.batas,
    this.status = 'aktif',
    this.alasan = '',
    this.disetujui = true,
    this.hapusStatus = '',
    this.hapusAlasan = '',
    this.hapusKeputusan = '',
    this.fotoList = const [],
    this.lat = 0,
    this.lng = 0,
    required this.createdAt,
  });

  factory LowonganModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LowonganModel(
      id: doc.id,
      uid: d['uid'] ?? '',
      namaPemberi: d['nama_pemberi'] ?? '',
      fotoPemberi: d['foto_pemberi'] ?? '',
      whatsapp: d['whatsapp'] ?? '',
      judul: d['judul'] ?? '',
      kategori: d['kategori'] ?? 'umum',
      deskripsi: d['deskripsi'] ?? '',
      syarat: d['syarat'] ?? '',
      jenis: d['jenis'] ?? 'harian',
      jumlahOrang: (d['jumlah_orang'] ?? 1) as int,
      diterima: (d['diterima'] ?? 0) as int,
      upah: (d['upah'] ?? 0) as int,
      satuanUpah: d['satuan_upah'] ?? 'per hari',
      upahNego: d['upah_nego'] ?? false,
      alamat: d['alamat'] ?? '',
      mulai: _ts(d['mulai']),
      batas: _ts(d['batas']) ?? DateTime.now(),
      status: d['status'] ?? 'aktif',
      alasan: d['alasan'] ?? '',
      disetujui: d['disetujui'] ?? true,
      hapusStatus: d['hapus_status'] ?? '',
      hapusAlasan: d['hapus_alasan'] ?? '',
      hapusKeputusan: d['hapus_keputusan'] ?? '',
      fotoList: List<String>.from(d['foto_list'] ?? const []),
      lat: (d['lat'] ?? 0).toDouble(),
      lng: (d['lng'] ?? 0).toDouble(),
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  int get sisa => jumlahOrang - diterima;
  bool get lewatBatas =>
      DateTime.now().isAfter(DateTime(batas.year, batas.month, batas.day, 23, 59, 59));
  bool get penuh => diterima >= jumlahOrang;

  /// Boleh dilamar sekarang
  bool get buka => status == 'aktif' && !lewatBatas && !penuh;

  String get labelStatus {
    if (status == 'blokir') return 'Diblokir Admin';
    if (status == 'pending') return 'Menunggu persetujuan Admin';
    if (status == 'ditolak') return 'Ditolak Admin';
    if (status == 'ditutup') return 'Ditutup';
    if (penuh) return 'Kuota penuh';
    if (lewatBatas) return 'Pendaftaran berakhir';
    return 'Dibuka';
  }

  String get labelUpah => upah <= 0
      ? 'Upah dibicarakan'
      : '${LetterModel.rupiah('$upah')} $satuanUpah${upahNego ? ' (bisa nego)' : ''}';

  static const List<Map<String, String>> daftarJenis = [
    {'value': 'harian', 'label': 'Harian / Serabutan', 'info': 'Dibayar per hari kerja, tanpa ikatan panjang.'},
    {'value': 'borongan', 'label': 'Borongan (per proyek)', 'info': 'Dibayar per pekerjaan selesai, misalnya cat satu rumah.'},
    {'value': 'paruh_waktu', 'label': 'Paruh Waktu', 'info': 'Kerja beberapa jam atau beberapa hari dalam seminggu.'},
    {'value': 'tetap', 'label': 'Karyawan Tetap', 'info': 'Kerja rutin untuk usaha Anda, dibayar bulanan.'},
  ];

  static const List<String> daftarSatuan = [
    'per hari', 'per proyek', 'per jam', 'per minggu', 'per bulan'
  ];

  static String satuanBawaan(String jenis) {
    switch (jenis) {
      case 'borongan':
        return 'per proyek';
      case 'paruh_waktu':
        return 'per jam';
      case 'tetap':
        return 'per bulan';
      default:
        return 'per hari';
    }
  }

  static String labelJenis(String v) => daftarJenis.firstWhere(
      (j) => j['value'] == v,
      orElse: () => {'label': v})['label']!;

  /// Kategori lowongan = semua kategori jasa (kecuali "Jasa Lainnya") + Pekerja Umum
  static List<Map<String, String>> get daftarKategori => [
        for (final k in AppUtils.daftarKategoriJasa)
          if (k['value'] != 'lainnya') k,
        {
          'value': 'umum',
          'label': 'Pekerja Umum / Serabutan',
          'contoh': 'Kuli angkut, jaga warung, kurir, serabutan'
        },
      ];

  static String labelKategori(String v) => daftarKategori.firstWhere(
      (j) => j['value'] == v,
      orElse: () => {'label': 'Pekerja Umum / Serabutan'})['label']!;
}

class LamaranModel {
  final String id;
  final String lowonganId;
  final String judulLowongan;
  final String pemberiUid;
  final String uid; // pelamar
  final String nama;
  final String foto;
  final String telepon;
  final String pesan;
  final int tawaran; // 0 = ikut upah di lowongan
  final String status; // baru | diterima | ditolak
  final DateTime createdAt;

  LamaranModel({
    required this.id,
    required this.lowonganId,
    this.judulLowongan = '',
    required this.pemberiUid,
    required this.uid,
    required this.nama,
    this.foto = '',
    this.telepon = '',
    this.pesan = '',
    this.tawaran = 0,
    this.status = 'baru',
    required this.createdAt,
  });

  factory LamaranModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LamaranModel(
      id: doc.id,
      lowonganId: d['lowongan_id'] ?? '',
      judulLowongan: d['judul_lowongan'] ?? '',
      pemberiUid: d['pemberi_uid'] ?? '',
      uid: d['uid'] ?? '',
      nama: d['nama'] ?? '',
      foto: d['foto'] ?? '',
      telepon: d['telepon'] ?? '',
      pesan: d['pesan'] ?? '',
      tawaran: (d['tawaran'] ?? 0) as int,
      status: d['status'] ?? 'baru',
      createdAt: _ts(d['created_at']) ?? DateTime.now(),
    );
  }

  String get labelStatus => status == 'diterima'
      ? 'Diterima'
      : (status == 'ditolak' ? 'Belum cocok' : 'Menunggu jawaban');
}

// ═════════════════════════════════════════════════════════════
// PANDUAN & CONTOH FITUR JASA (teks bantu untuk warga awam)
// Semua contoh adalah ilustrasi, bukan data nyata.
// ═════════════════════════════════════════════════════════════
class ContohLowongan {
  final String judul;
  final String deskripsi;
  final String jenis;
  final int upah;
  final int jumlah;
  const ContohLowongan(this.judul, this.deskripsi, this.jenis, this.upah, this.jumlah);
}

class InfoKategoriJasa {
  final String apaItu;
  final List<String> contohJasa; // contoh orang yang membuka jasa
  final List<String> contohDeskripsi; // contoh deskripsi profil jasa
  final List<String> contohPesanan; // contoh catatan saat memesan
  final List<ContohLowongan> contohLowongan; // contoh "Butuh Pekerja"
  final List<String> contohLamar; // contoh pesan melamar
  const InfoKategoriJasa({
    required this.apaItu,
    required this.contohJasa,
    required this.contohDeskripsi,
    required this.contohPesanan,
    required this.contohLowongan,
    required this.contohLamar,
  });

  static InfoKategoriJasa untuk(String kategori) {
    switch (kategori) {
      case 'tukang':
        return const InfoKategoriJasa(
          apaItu:
              'Pekerjaan bangunan skala rumah tangga: membangun, memperbaiki, mengecat, memasang keramik, atap, pagar, atau instalasi listrik dan pipa rumah. Cocok untuk tukang harian maupun yang menerima borongan.',
          contohJasa: [
            'Tukang bangunan harian (pasang bata, plester, cor lantai)',
            'Tukang cat tembok rumah',
            'Tukang keramik dan pasang lantai',
            'Tukang atap / perbaikan genteng bocor',
            'Tukang las: pagar, kanopi, teralis',
            'Tukang listrik atau pipa air rumah',
          ],
          contohDeskripsi: [
            'Tukang bangunan berpengalaman 8 tahun. Menerima borongan renovasi rumah kecil: dapur, kamar mandi, teras, dan pagar. Bisa datang survei dulu tanpa biaya. Melayani Talagasari dan sekitarnya. Hubungi lewat chat atau WhatsApp.',
            'Jasa cat tembok dalam dan luar rumah. Alat sendiri, bahan boleh dari Bapak/Ibu atau kami bantu belikan. Kerja rapi dan bersih, bisa harian atau borongan per ruangan.',
          ],
          contohPesanan: [
            'Atap dapur bocor, genteng sekitar 6 buah perlu diganti. Mohon survei hari Sabtu pagi.',
            'Ingin mengecat 3 kamar ukuran 3x3 meter, cat sudah ada. Berapa estimasi biayanya?',
            'Perlu pasang keramik teras 3x4 meter, keramik sudah dibeli.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh 3 kuli bangunan harian untuk renovasi rumah',
                'Renovasi rumah 2 lantai di Talagasari. Pekerjaan: membongkar dinding, angkat material, dan membantu tukang. Kerja 6 hari, jam 08.00 sampai 16.00, makan siang ditanggung.',
                'harian', 120000, 3),
            ContohLowongan('Butuh tukang cat borongan satu rumah',
                'Mengecat satu rumah tipe 36 (dalam dan luar). Cat disediakan pemilik. Harga borongan bisa dinego setelah survei. Mulai minggu depan.',
                'borongan', 2500000, 1),
          ],
          contohLamar: [
            'Saya tukang bangunan pengalaman 6 tahun, tinggal di RT 02 Talagasari. Bisa mulai kapan saja dan membawa alat kerja sendiri.',
            'Saya biasa jadi kenek tukang dan siap kerja harian. Sehat, rajin, dan bisa langsung datang besok pagi.',
          ],
        );
      case 'teknisi':
        return const InfoKategoriJasa(
          apaItu:
              'Perbaikan dan perawatan barang elektronik di rumah: TV, kulkas, mesin cuci, AC, kipas, HP, laptop, sampai pasang CCTV atau wifi.',
          contohJasa: [
            'Servis AC dan cuci AC',
            'Servis kulkas dan mesin cuci',
            'Servis TV dan elektronik rumah',
            'Servis laptop dan HP',
            'Pasang CCTV dan wifi',
          ],
          contohDeskripsi: [
            'Teknisi servis AC dan kulkas, pengalaman 5 tahun. Datang ke rumah, cek kerusakan dulu, dan biaya dijelaskan sebelum dikerjakan. Garansi servis 7 hari. Melayani area Cikupa dan sekitarnya.',
            'Servis laptop dan HP: ganti baterai, layar, instal ulang, bersihkan virus. Bisa dibawa ke rumah saya atau saya datang ke tempat Anda.',
          ],
          contohPesanan: [
            'AC kamar kurang dingin dan menetes air. Merk dan tipe menyusul lewat chat.',
            'Mesin cuci tidak bisa berputar dan keluar bunyi keras. Mohon dicek hari ini kalau bisa.',
            'Laptop sangat lambat dan sering mati sendiri.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh asisten teknisi AC (bisa belajar)',
                'Membantu angkat unit, pasang bracket, dan bersih-bersih saat servis AC. Tidak perlu berpengalaman, akan diajari. Kerja sesuai jadwal pesanan, sekitar 4 hari seminggu.',
                'paruh_waktu', 100000, 1),
            ContohLowongan('Butuh teknisi HP untuk jaga konter',
                'Konter HP butuh teknisi yang bisa ganti layar dan baterai. Jam kerja 09.00 sampai 17.00. Gaji bulanan dan bonus per servis.',
                'tetap', 2200000, 1),
          ],
          contohLamar: [
            'Saya lulusan SMK jurusan elektronika dan sudah biasa servis TV serta kipas. Siap belajar servis AC.',
            'Saya bisa ganti layar dan baterai HP, pernah magang di konter selama 1 tahun.',
          ],
        );
      case 'guru_les':
        return const InfoKategoriJasa(
          apaItu:
              'Mengajar anak atau remaja di luar sekolah: les mata pelajaran, mengaji, bahasa, musik, atau membantu mengerjakan PR. Bisa datang ke rumah murid atau murid datang ke tempat guru.',
          contohJasa: [
            'Les Matematika dan IPA SD/SMP',
            'Guru ngaji dan Iqra di rumah',
            'Les Bahasa Inggris',
            'Les calistung untuk anak TK',
            'Les gitar atau piano',
          ],
          contohDeskripsi: [
            'Guru les SD dan SMP, mahasiswa semester akhir jurusan pendidikan. Mengajar Matematika, IPA, dan Bahasa Indonesia. Bisa datang ke rumah murid atau belajar di rumah saya. Jadwal fleksibel sore dan malam.',
            'Guru ngaji untuk anak usia 5 sampai 12 tahun, mulai Iqra sampai Al-Quran. Kelas kecil maksimal 5 anak supaya perhatian merata.',
          ],
          contohPesanan: [
            'Anak saya kelas 5 SD butuh les Matematika, 2 kali seminggu sore hari.',
            'Mencari guru ngaji untuk 2 anak (usia 6 dan 8 tahun), datang ke rumah.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh guru ngaji untuk TPQ mushola',
                'Mengajar anak-anak TPQ sore hari, Senin sampai Jumat jam 16.00 sampai 17.30. Mampu mengajar Iqra dan tajwid dasar. Insentif bulanan.',
                'tetap', 800000, 1),
            ContohLowongan('Butuh pengajar les calistung anak TK',
                'Bimbel rumahan mencari pengajar sabar dan suka anak-anak untuk kelas calistung, Sabtu dan Minggu pagi.',
                'paruh_waktu', 50000, 1),
          ],
          contohLamar: [
            'Saya mahasiswa PGSD dan biasa mengajar adik-adik di lingkungan. Bisa hari Sabtu dan Minggu.',
            'Saya lulusan pesantren dan terbiasa mengajar ngaji anak-anak.',
          ],
        );
      case 'fotografer':
        return const InfoKategoriJasa(
          apaItu:
              'Jasa foto dan video untuk acara: lamaran, pernikahan, khitanan, ulang tahun, foto produk usaha, atau pas foto. Penyedia biasanya membawa kamera dan peralatan sendiri.',
          contohJasa: [
            'Foto dan video acara pernikahan atau lamaran',
            'Dokumentasi khitanan dan ulang tahun',
            'Foto produk untuk jualan online',
            'Foto wisuda dan pas foto',
            'Drone untuk dokumentasi acara',
          ],
          contohDeskripsi: [
            'Fotografer acara keluarga: lamaran, syukuran, khitanan, dan ulang tahun. Hasil diedit ringan dan dikirim lewat Google Drive maksimal 3 hari setelah acara. Paket foto saja atau foto plus video tersedia.',
            'Foto produk untuk UMKM: makanan, pakaian, dan kerajinan. Latar putih bersih, 10 foto per paket.',
          ],
          contohPesanan: [
            'Acara lamaran hari Minggu depan jam 10.00 sampai 13.00 di Talagasari, butuh foto dan video.',
            'Mau foto produk kue untuk dijual online, sekitar 15 produk.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh asisten fotografer untuk acara pernikahan',
                'Membantu membawa peralatan, mengatur lampu, dan mengambil foto tambahan pada acara pernikahan akhir pekan. Boleh pemula yang mau belajar.',
                'harian', 150000, 2),
            ContohLowongan('Butuh editor video lepas',
                'Mengedit video acara keluarga dari rekaman mentah, durasi hasil 5 sampai 10 menit. Dibayar per video selesai.',
                'borongan', 200000, 1),
          ],
          contohLamar: [
            'Saya punya kamera sendiri dan sering memotret acara keluarga. Ingin belajar jadi asisten fotografer.',
            'Saya bisa edit video memakai aplikasi di HP dan laptop. Contoh hasil bisa saya kirim lewat chat.',
          ],
        );
      case 'laundry':
        return const InfoKategoriJasa(
          apaItu:
              'Jasa cuci dan setrika pakaian, serta kebersihan rumah: bersih-bersih, cuci karpet atau sofa, dan asisten rumah tangga harian.',
          contohJasa: [
            'Laundry kiloan (cuci, setrika, antar jemput)',
            'Cuci dan setrika saja',
            'Cuci karpet, sofa, dan kasur',
            'Bersih-bersih rumah atau kontrakan',
            'Asisten rumah tangga harian',
          ],
          contohDeskripsi: [
            'Laundry kiloan dekat Talagasari. Cuci, kering, setrika, dan wangi. Selesai 2 hari, ada layanan kilat 1 hari. Gratis antar jemput untuk jarak dekat.',
            'Jasa bersih-bersih rumah dan kontrakan sebelum ditempati. Alat dan cairan pembersih dibawa sendiri.',
          ],
          contohPesanan: [
            'Cuci dan setrika sekitar 6 kg, mohon dijemput ke rumah hari Jumat sore.',
            'Cuci sofa 3 dudukan dan 1 karpet ukuran 2x3 meter.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh karyawan laundry bagian setrika',
                'Laundry kiloan butuh tenaga setrika, jam kerja 08.00 sampai 16.00, libur hari Minggu. Makan siang ditanggung.',
                'tetap', 1800000, 2),
            ContohLowongan('Butuh asisten rumah tangga harian',
                'Membersihkan rumah, mencuci, dan menyetrika, 3 kali seminggu jam 07.00 sampai 12.00.',
                'paruh_waktu', 80000, 1),
          ],
          contohLamar: [
            'Saya rajin dan sudah biasa menyetrika dalam jumlah banyak. Rumah saya dekat lokasi laundry.',
            'Saya pernah bekerja sebagai asisten rumah tangga dan bisa mulai minggu depan.',
          ],
        );
      case 'catering':
        return const InfoKategoriJasa(
          apaItu:
              'Memasak untuk dijual atau dipesan: nasi kotak, tumpeng, kue, snack box, masakan harian, sampai juru masak acara.',
          contohJasa: [
            'Nasi kotak untuk pengajian atau rapat',
            'Tumpeng dan prasmanan acara',
            'Kue ulang tahun dan kue kering',
            'Snack box',
            'Katering makan siang harian',
          ],
          contohDeskripsi: [
            'Menerima pesanan nasi kotak dan snack box minimal 20 porsi. Menu bisa dipilih, tanpa pengawet. Pesan sehari sebelumnya. Bisa diantar di area Talagasari.',
            'Kue ulang tahun dan kue kering lebaran buatan rumah. Desain bisa request.',
          ],
          contohPesanan: [
            'Pesan 40 nasi kotak (nasi, ayam goreng, sambal, lalapan) untuk pengajian hari Sabtu jam 12.00.',
            'Pesan kue ulang tahun ukuran 20 cm, tulisan "Selamat Ulang Tahun Dina".',
          ],
          contohLowongan: [
            ContohLowongan('Butuh 2 tenaga bantu masak untuk acara hajatan',
                'Membantu memasak, mengiris bahan, dan menyiapkan prasmanan untuk acara hajatan hari Sabtu, mulai jam 05.00 sampai selesai.',
                'harian', 120000, 2),
            ContohLowongan('Butuh karyawan dapur katering',
                'Katering harian butuh tenaga dapur untuk memasak dan mengemas pesanan, Senin sampai Sabtu jam 04.00 sampai 11.00.',
                'tetap', 2000000, 2),
          ],
          contohLamar: [
            'Saya terbiasa membantu masak untuk acara kampung dan bisa mulai dari subuh.',
            'Saya pernah bekerja di warung makan bagian dapur dan bisa mengemas pesanan dengan rapi.',
          ],
        );
      case 'bengkel':
        return const InfoKategoriJasa(
          apaItu:
              'Perawatan dan perbaikan kendaraan, terutama motor: servis rutin, ganti oli, tambal ban, aki, rem, sampai servis panggilan ke lokasi kalau kendaraan mogok.',
          contohJasa: [
            'Bengkel motor (servis rutin dan ganti oli)',
            'Tambal ban dan ganti ban',
            'Servis panggilan saat motor mogok',
            'Cuci motor dan mobil',
          ],
          contohDeskripsi: [
            'Bengkel motor rumahan, pengalaman 7 tahun. Servis rutin, ganti oli, rem, dan kelistrikan. Harga jelas sebelum dikerjakan. Bisa dipanggil ke lokasi kalau motor mogok di sekitar Talagasari.',
          ],
          contohPesanan: [
            'Motor Beat tahun 2018 susah distarter pagi hari, mohon dicek.',
            'Motor mogok di depan rumah, mesin mati mendadak. Butuh servis panggilan.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh mekanik motor untuk bengkel',
                'Bengkel butuh mekanik yang bisa servis ringan sampai berat. Jam kerja 08.00 sampai 17.00, libur Minggu. Gaji bulanan plus bonus per servis.',
                'tetap', 2500000, 1),
            ContohLowongan('Butuh anak magang bengkel',
                'Membantu mencuci onderdil dan membersihkan bengkel sambil belajar servis. Tidak perlu berpengalaman.',
                'paruh_waktu', 50000, 1),
          ],
          contohLamar: [
            'Saya lulusan SMK otomotif dan terbiasa servis motor. Bisa mulai minggu depan.',
            'Saya belum berpengalaman tapi mau belajar, rajin, dan tinggal dekat bengkel.',
          ],
        );
      case 'kebun':
        return const InfoKategoriJasa(
          apaItu:
              'Pekerjaan kebun dan lahan: merapikan taman rumah, memangkas rumput dan pohon, menanam, memupuk, menyemprot hama, serta membantu panen.',
          contohJasa: [
            'Rapikan taman dan pangkas rumput',
            'Tanam dan rawat tanaman hias',
            'Bantu panen atau tanam di lahan',
            'Bersihkan pekarangan',
          ],
          contohDeskripsi: [
            'Jasa rapikan taman dan pekarangan, pangkas rumput dan pohon kecil, buang sampah daun. Alat sendiri. Bisa harian atau borongan per halaman.',
          ],
          contohPesanan: [
            'Halaman rumah ukuran sekitar 6x10 meter penuh rumput liar, mohon dirapikan dan dibuang sisa rumputnya.',
            'Pohon mangga di depan rumah perlu dipangkas karena menyentuh kabel.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh 2 orang bantu panen di kebun',
                'Membantu memanen sayuran dan mengangkut hasil panen ke pengepul. Pagi hari jam 05.00 sampai 11.00, 3 hari.',
                'harian', 90000, 2),
            ContohLowongan('Butuh tukang kebun tetap untuk perumahan',
                'Merawat taman dan tanaman di lingkungan perumahan setiap pagi, Senin sampai Sabtu.',
                'tetap', 1800000, 1),
          ],
          contohLamar: [
            'Saya terbiasa bekerja di kebun dan kuat mengangkut hasil panen. Bisa mulai besok pagi.',
            'Saya biasa merawat taman dan punya alat pangkas sendiri.',
          ],
        );
      case 'asuh':
        return const InfoKategoriJasa(
          apaItu:
              'Menjaga anak atau lansia saat keluarganya bekerja: penitipan anak di rumah (daycare rumahan), mengantar ke sekolah, atau menemani orang tua yang butuh perhatian.',
          contohJasa: [
            'Penitipan anak harian di rumah',
            'Pengasuh anak (datang ke rumah)',
            'Antar-jemput anak ke sekolah',
            'Menemani dan menjaga lansia',
          ],
          contohDeskripsi: [
            'Penitipan anak usia 1 sampai 5 tahun di rumah saya, Senin sampai Jumat jam 07.00 sampai 17.00. Anak diberi makan siang dan tidur siang. Maksimal 4 anak supaya terawasi.',
          ],
          contohPesanan: [
            'Anak saya 3 tahun perlu dititipkan Senin sampai Jumat jam 07.00 sampai 16.00 karena saya bekerja.',
            'Butuh pengasuh untuk ibu saya (70 tahun) di siang hari, menemani dan mengingatkan minum obat.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh pengasuh anak datang ke rumah',
                'Menjaga satu anak usia 2 tahun di rumah, jam 07.00 sampai 16.00, Senin sampai Sabtu. Sabar dan suka anak-anak.',
                'tetap', 1800000, 1),
            ContohLowongan('Butuh penjaga lansia paruh waktu',
                'Menemani nenek di rumah pada siang hari, membantu makan dan jalan-jalan sore.',
                'paruh_waktu', 70000, 1),
          ],
          contohLamar: [
            'Saya sudah punya anak dan terbiasa mengurus balita. Sabar dan bisa datang jam 7 pagi.',
            'Saya pernah merawat nenek sendiri dan siap menemani lansia.',
          ],
        );
      case 'sewa_acara':
        return const InfoKategoriJasa(
          apaItu:
              'Menyewakan perlengkapan untuk hajatan, pengajian, atau acara kampung: tenda, kursi, meja, sound system, panggung, piring gelas, dan dekorasi. Biasanya dibayar per paket.',
          contohJasa: [
            'Sewa tenda dan kursi',
            'Sewa sound system dan MC',
            'Sewa piring, gelas, dan peralatan makan',
            'Dekorasi pelaminan dan panggung kecil',
          ],
          contohDeskripsi: [
            'Sewa tenda 4x6, kursi plastik, dan meja untuk hajatan atau pengajian. Pasang dan bongkar ditangani tim kami. Harga paket, bisa dinego untuk acara lebih dari satu hari.',
          ],
          contohPesanan: [
            'Sewa 1 tenda, 100 kursi, dan 5 meja untuk pengajian Sabtu depan di Talagasari. Tolong dipasang Jumat sore.',
            'Butuh sound system untuk acara 17 Agustus di lapangan RW, dari jam 07.00 sampai 12.00.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh 3 tenaga pasang dan bongkar tenda',
                'Membantu memasang dan membongkar tenda serta kursi pada acara akhir pekan. Kerja sehari penuh, ada makan siang.',
                'harian', 130000, 3),
            ContohLowongan('Butuh operator sound system',
                'Mengoperasikan sound system pada acara hajatan dan pengajian. Boleh pemula, akan diajari.',
                'harian', 150000, 1),
          ],
          contohLamar: [
            'Saya kuat angkat barang dan terbiasa membantu pasang tenda di kampung. Siap kerja akhir pekan.',
            'Saya bisa mengoperasikan sound system dasar dan sering membantu acara RW.',
          ],
        );
      case 'salon':
        return const InfoKategoriJasa(
          apaItu:
              'Perawatan penampilan: potong rambut, creambath, rias, sampai pijat. Bisa buka di rumah, atau datang ke rumah pelanggan.',
          contohJasa: [
            'Potong rambut pria dan anak',
            'Salon rumahan (potong, creambath, cat rambut)',
            'Rias pengantin dan wisuda',
            'Pijat dan refleksi',
          ],
          contohDeskripsi: [
            'Potong rambut pria dan anak-anak, buka di rumah setiap hari jam 08.00 sampai 20.00. Bisa dipanggil ke rumah untuk lansia atau yang sulit keluar.',
            'Rias pengantin dan wisuda, hasil natural, bisa datang ke rumah sejak subuh. Contoh hasil ada di foto portofolio.',
          ],
          contohPesanan: [
            'Potong rambut 2 anak laki-laki di rumah saya hari Minggu pagi.',
            'Butuh rias untuk acara lamaran hari Sabtu, datang jam 06.00 ke rumah.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh asisten salon',
                'Membantu keramas, creambath, dan merapikan salon. Boleh belum berpengalaman, akan dilatih.',
                'tetap', 1600000, 1),
            ContohLowongan('Butuh tukang cukur untuk barbershop',
                'Barbershop butuh tukang cukur yang bisa potongan modern. Sistem bagi hasil.',
                'tetap', 2000000, 1),
          ],
          contohLamar: [
            'Saya bisa potong rambut dasar dan pernah magang di salon 6 bulan. Siap belajar lagi.',
            'Saya rajin, rapi, dan ingin belajar jadi asisten salon.',
          ],
        );
      case 'jahit':
        return const InfoKategoriJasa(
          apaItu:
              'Menjahit pakaian baru atau memperbaiki pakaian lama: permak celana, ganti resleting, jahit seragam sekolah, kebaya, tirai, dan obras.',
          contohJasa: [
            'Permak celana dan baju',
            'Jahit baju dan kebaya',
            'Jahit seragam sekolah atau kantor',
            'Jahit tirai dan sprei',
          ],
          contohDeskripsi: [
            'Penjahit pengalaman 10 tahun. Menerima jahit baju, kebaya, seragam, dan permak. Bisa ambil ukuran di rumah. Pengerjaan 3 sampai 7 hari tergantung jumlah.',
          ],
          contohPesanan: [
            'Permak 3 celana panjang (potong ujung dan kecilkan pinggang), mohon dijemput.',
            'Jahit seragam sekolah SD untuk 2 anak, kain sudah ada.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh penjahit untuk konveksi kecil',
                'Konveksi rumahan butuh penjahit yang bisa menjahit kaos dan kemeja. Dibayar per potong, kerja di tempat.',
                'borongan', 8000, 2),
            ContohLowongan('Butuh tenaga obras dan finishing',
                'Mengobras dan merapikan jahitan, jam kerja 08.00 sampai 16.00, Senin sampai Sabtu.',
                'tetap', 1700000, 1),
          ],
          contohLamar: [
            'Saya bisa menjahit baju dasar dan terbiasa memakai mesin jahit listrik. Bisa kerja di tempat.',
            'Saya pernah bekerja di konveksi bagian finishing dan siap mulai segera.',
          ],
        );
      case 'angkut':
        return const InfoKategoriJasa(
          apaItu:
              'Mengantar orang atau barang: ojek, antar-jemput sekolah, antar paket dalam desa, serta angkut barang dan pindahan memakai motor roda tiga atau pick up.',
          contohJasa: [
            'Ojek harian atau antar-jemput sekolah',
            'Antar paket dan belanjaan',
            'Pindahan rumah memakai pick up',
            'Angkut material bangunan',
          ],
          contohDeskripsi: [
            'Jasa angkut barang dan pindahan memakai pick up, dibantu 2 orang. Area Talagasari dan sekitarnya. Harga per trip, bisa dinego untuk jarak jauh.',
            'Ojek antar-jemput anak sekolah, rute Talagasari sampai Cikupa, jam berangkat dan pulang tetap.',
          ],
          contohPesanan: [
            'Pindahan kontrakan ke rumah baru, barang kira-kira satu pick up, jarak 3 km. Butuh 2 orang membantu angkat.',
            'Antar-jemput anak SD, berangkat jam 06.30 dan pulang jam 12.30.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh 2 orang bantu pindahan rumah',
                'Membantu mengangkat barang ke pick up dan menurunkannya di rumah baru. Kerja setengah hari.',
                'harian', 100000, 2),
            ContohLowongan('Butuh kurir antar pesanan warung',
                'Mengantar pesanan belanjaan ke rumah warga sekitar desa memakai motor sendiri, jam 07.00 sampai 12.00.',
                'paruh_waktu', 70000, 1),
          ],
          contohLamar: [
            'Saya punya motor sendiri dan hafal jalan di Talagasari. Bisa mengantar pesanan dengan cepat.',
            'Saya kuat angkat barang berat dan terbiasa membantu pindahan.',
          ],
        );
      default:
        return const InfoKategoriJasa(
          apaItu:
              'Pekerjaan umum yang tidak masuk enam kategori jasa: kuli angkut, tukang kebun, penjaga toko, kurir lokal, jaga warung, dan pekerjaan serabutan lain.',
          contohJasa: [
            'Tukang kebun / bersih halaman',
            'Jasa angkut barang dan pindahan',
            'Kurir antar barang dalam desa',
          ],
          contohDeskripsi: [
            'Jasa angkut barang dan bantu pindahan rumah dengan motor roda tiga. Area Talagasari dan sekitarnya.',
          ],
          contohPesanan: [
            'Butuh bantuan pindahan kontrakan, barang sekitar satu pick up.',
          ],
          contohLowongan: [
            ContohLowongan('Butuh penjaga warung pagi hari',
                'Menjaga warung sembako jam 06.00 sampai 12.00, melayani pembeli dan mencatat penjualan.',
                'paruh_waktu', 60000, 1),
            ContohLowongan('Butuh tukang kebun harian',
                'Merapikan taman, memangkas rumput, dan membersihkan halaman rumah. Dikerjakan 1 hari.',
                'harian', 100000, 1),
          ],
          contohLamar: [
            'Saya warga RT 03 dan siap bekerja kapan saja. Bisa membawa alat sendiri.',
          ],
        );
    }
  }
}


// ═════════════════════════════════════════════════════════════
// PATOKAN UPAH — angka awal yang masuk akal untuk tiap kategori,
// jenis kerja, dan satuan. PERKIRAAN umum agar warga awam punya
// pegangan, bukan data resmi. Pemberi kerja bebas mengubahnya.
// ═════════════════════════════════════════════════════════════
class _DasarUpah {
  final int harian; // upah satu hari kerja (tenaga umum)
  final int proyek; // contoh harga satu pekerjaan borongan
  final String proyekLabel;
  final String pekerja;
  final String tugas;
  const _DasarUpah(this.harian, this.proyek, this.proyekLabel, this.pekerja, this.tugas);
}

class PatokanUpah {
  final int tipikal;
  final int min;
  final int max;
  final String satuan;
  final String catatan;
  const PatokanUpah(this.tipikal, this.min, this.max, this.satuan, this.catatan);

  /// UMK Kabupaten Tangerang 2026 (Rp 5.210.377), dibulatkan untuk patokan gaji bulanan.
  static const int umk = 5210377;

  static const Map<String, _DasarUpah> _dasar = {
    'tukang': _DasarUpah(130000, 3000000, 'mengecat satu rumah tipe 36', 'kuli/tukang bangunan', 'membongkar, mengangkat material, dan membantu pekerjaan bangunan'),
    'teknisi': _DasarUpah(150000, 400000, 'memasang CCTV 4 titik', 'asisten teknisi', 'membantu servis dan pemasangan elektronik atau AC'),
    'bengkel': _DasarUpah(120000, 300000, 'servis besar satu motor', 'mekanik/asisten bengkel', 'membantu servis kendaraan di bengkel'),
    'laundry': _DasarUpah(90000, 500000, 'bersih-bersih besar satu rumah kontrakan', 'petugas laundry', 'mencuci, menjemur, dan menyetrika pakaian pelanggan'),
    'kebun': _DasarUpah(100000, 600000, 'merapikan satu halaman besar', 'tenaga kebun', 'merapikan taman, memangkas rumput, dan membersihkan halaman'),
    'catering': _DasarUpah(110000, 800000, 'membantu memasak satu acara hajatan', 'tenaga dapur', 'memasak, menyiapkan bahan, dan mengemas pesanan'),
    'guru_les': _DasarUpah(100000, 600000, 'satu paket 8 pertemuan les', 'pengajar les', 'mengajar murid sesuai jadwal dan menyiapkan latihan soal'),
    'asuh': _DasarUpah(100000, 500000, 'menjaga anak selama satu acara keluarga', 'pengasuh', 'menjaga anak atau lansia dan menyiapkan makan'),
    'fotografer': _DasarUpah(200000, 1500000, 'satu acara pernikahan', 'asisten fotografer', 'membawa peralatan dan membantu pengambilan foto atau video'),
    'sewa_acara': _DasarUpah(120000, 600000, 'pasang dan bongkar satu acara', 'tenaga pasang tenda', 'memasang dan membongkar tenda, kursi, dan perlengkapan acara'),
    'salon': _DasarUpah(120000, 1000000, 'merias satu acara pengantin', 'asisten salon', 'membantu pelanggan, keramas, dan merapikan salon'),
    'jahit': _DasarUpah(110000, 700000, 'menjahit satu pesanan seragam', 'penjahit', 'menjahit, mengobras, dan merapikan pakaian'),
    'angkut': _DasarUpah(120000, 350000, 'satu kali pindahan rumah', 'tenaga angkut/kurir', 'mengangkat barang dan mengantar pesanan'),
    'umum': _DasarUpah(100000, 500000, 'satu pekerjaan kecil', 'pekerja umum', 'membantu pekerjaan harian sesuai arahan pemberi kerja'),
  };

  static _DasarUpah _d(String kategori) => _dasar[kategori] ?? _dasar['umum']!;

  static int _bulat(num v, int step) => ((v / step).round() * step);

  static PatokanUpah untuk(String kategori, String jenis, String satuan) {
    final d = _d(kategori);
    final bool paruh = jenis == 'paruh_waktu';
    switch (satuan) {
      case 'per jam':
        final t = _bulat(d.harian / 7, 500);
        return PatokanUpah(t, _bulat(t * 0.8, 500), _bulat(t * 1.4, 500), satuan,
            'Setara upah harian dibagi sekitar 7 jam kerja.');
      case 'per minggu':
        final t = _bulat(d.harian * 6 * (paruh ? 0.6 : 1.0), 10000);
        return PatokanUpah(t, _bulat(t * 0.8, 10000), _bulat(t * 1.3, 10000), satuan,
            paruh ? 'Kerja paruh waktu, sekitar 3 sampai 4 hari seminggu.' : 'Setara 6 hari kerja dalam seminggu.');
      case 'per bulan':
        final base = ((umk + 9999) ~/ 10000) * 10000; // dibulatkan ke atas agar tidak di bawah UMK
        if (paruh) {
          final t = _bulat(base * 0.5, 10000);
          return PatokanUpah(t, _bulat(t * 0.8, 10000), _bulat(t * 1.3, 10000), satuan,
              'Paruh waktu sekitar setengah waktu kerja, jadi sekitar setengah UMK.');
        }
        return PatokanUpah(base, base, _bulat(base * 1.3, 10000), satuan,
            'Mengikuti UMK Kabupaten Tangerang 2026 (Rp 5.210.377). Usaha sebaiknya tidak membayar di bawah UMK.');
      case 'per proyek':
        final t = _bulat(d.proyek, 25000);
        return PatokanUpah(t, _bulat(t * 0.6, 25000), _bulat(t * 1.6, 25000), satuan,
            'Contoh pekerjaan: ${d.proyekLabel}. Harga borongan sangat bergantung pada ukuran pekerjaan, sesuaikan.');
      default: // per hari
        final t = _bulat(d.harian * (paruh ? 0.6 : 1.0), 5000);
        return PatokanUpah(t, _bulat(t * 0.8, 5000), _bulat(t * 1.3, 5000), 'per hari',
            paruh
                ? 'Kerja paruh waktu (sekitar 4 jam), jadi sekitar 60 persen upah sehari penuh.'
                : 'Perkiraan upah harian untuk ${d.pekerja}.');
    }
  }

  /// Contoh lowongan siap pakai untuk SETIAP jenis kerja pada kategori ini.
  static List<ContohLowongan> templat(String kategori) {
    final d = _d(kategori);
    return [
      ContohLowongan('Butuh 2 ${d.pekerja} harian',
          'Membantu ${d.tugas}. Dibayar per hari kerja, jam 08.00 sampai 16.00, makan siang ditanggung. Kerja beberapa hari sesuai kebutuhan.',
          'harian', untuk(kategori, 'harian', 'per hari').tipikal, 2),
      ContohLowongan('Butuh ${d.pekerja} borongan: ${d.proyekLabel}',
          'Pekerjaan borongan: ${d.proyekLabel}. Upah per pekerjaan, bisa dinego setelah survei lokasi. Alat dan bahan diatur sesuai kesepakatan.',
          'borongan', untuk(kategori, 'borongan', 'per proyek').tipikal, 1),
      ContohLowongan('Butuh ${d.pekerja} paruh waktu',
          'Membantu ${d.tugas} sekitar 4 jam per hari, 3 sampai 4 hari dalam seminggu. Jadwal bisa menyesuaikan.',
          'paruh_waktu', untuk(kategori, 'paruh_waktu', 'per jam').tipikal, 1),
      ContohLowongan('Butuh ${d.pekerja} karyawan tetap',
          'Bekerja rutin: ${d.tugas}. Senin sampai Sabtu, jam 08.00 sampai 16.00. Gaji bulanan, tidak di bawah UMK.',
          'tetap', untuk(kategori, 'tetap', 'per bulan').tipikal, 1),
    ];
  }
}


// ═════════════════════════════════════════════════════════════
// PANDUAN TARIF PENYEDIA JASA — satuan yang relevan + kisaran harga
// awal untuk SETIAP kategori. PERKIRAAN umum agar warga awam punya
// pegangan, bukan data resmi atau harga tetap. Penyedia bebas mengubah.
// ═════════════════════════════════════════════════════════════
class PanduanTarif {
  final List<String> satuan; // urut: yang paling cocok di depan
  final Map<String, int> mulai; // tarif mulai tipikal per satuan
  final Map<String, int> maks; // batas atas tipikal per satuan
  final List<String> contoh; // contoh harga pekerjaan umum di kategori ini
  const PanduanTarif(this.satuan, this.mulai, this.maks, this.contoh);

  static PanduanTarif untuk(String kategori) => _data[kategori] ?? _data['lainnya']!;

  static const Map<String, PanduanTarif> _data = {
    'tukang': PanduanTarif(
      ['per hari', 'per proyek', 'per meter', 'per jam'],
      {'per hari': 130000, 'per proyek': 500000, 'per meter': 35000, 'per jam': 20000},
      {'per hari': 200000, 'per proyek': 5000000, 'per meter': 100000, 'per jam': 35000},
      [
        'Tukang bangunan harian: Rp 130.000 sampai Rp 200.000 per hari',
        'Mengecat tembok (jasa saja): Rp 25.000 sampai Rp 45.000 per meter persegi',
        'Memasang keramik (jasa saja): Rp 60.000 sampai Rp 100.000 per meter persegi',
        'Memperbaiki atap bocor: mulai Rp 300.000 per titik',
      ],
    ),
    'teknisi': PanduanTarif(
      ['per servis', 'per jam', 'per proyek'],
      {'per servis': 75000, 'per jam': 40000, 'per proyek': 500000},
      {'per servis': 350000, 'per jam': 80000, 'per proyek': 2500000},
      [
        'Cuci AC: Rp 75.000 sampai Rp 100.000 per unit',
        'Servis AC (tambah freon, perbaikan): Rp 150.000 sampai Rp 400.000',
        'Servis TV, kulkas, atau mesin cuci: Rp 100.000 sampai Rp 350.000 (belum termasuk suku cadang)',
        'Servis laptop atau HP: Rp 75.000 sampai Rp 250.000',
        'Pasang CCTV 4 titik: Rp 500.000 sampai Rp 1.500.000 (jasa pasang)',
      ],
    ),
    'bengkel': PanduanTarif(
      ['per servis', 'per jam'],
      {'per servis': 25000, 'per jam': 30000},
      {'per servis': 300000, 'per jam': 60000},
      [
        'Ganti oli motor (jasa): Rp 10.000 sampai Rp 25.000',
        'Tambal ban: Rp 10.000 sampai Rp 25.000',
        'Servis rutin motor: Rp 50.000 sampai Rp 150.000',
        'Servis panggilan ke lokasi: tambah Rp 25.000 sampai Rp 50.000',
      ],
    ),
    'laundry': PanduanTarif(
      ['per kg', 'per potong', 'per hari', 'per paket'],
      {'per kg': 6000, 'per potong': 10000, 'per hari': 100000, 'per paket': 100000},
      {'per kg': 10000, 'per potong': 60000, 'per hari': 150000, 'per paket': 400000},
      [
        'Cuci setrika kiloan: Rp 6.000 sampai Rp 10.000 per kg',
        'Cuci saja (tanpa setrika): Rp 4.000 sampai Rp 6.000 per kg',
        'Cuci sepatu: Rp 25.000 sampai Rp 50.000 per pasang',
        'Cuci sofa 3 dudukan: Rp 150.000 sampai Rp 300.000',
        'Bersih-bersih rumah: Rp 100.000 sampai Rp 150.000 per hari',
      ],
    ),
    'kebun': PanduanTarif(
      ['per hari', 'per proyek', 'per jam'],
      {'per hari': 100000, 'per proyek': 300000, 'per jam': 15000},
      {'per hari': 150000, 'per proyek': 1500000, 'per jam': 30000},
      [
        'Tukang kebun harian: Rp 100.000 sampai Rp 150.000 per hari',
        'Merapikan taman kecil: Rp 150.000 sampai Rp 400.000',
        'Memangkas pohon: Rp 100.000 sampai Rp 300.000 per pohon',
      ],
    ),
    'catering': PanduanTarif(
      ['per porsi', 'per paket', 'per acara'],
      {'per porsi': 15000, 'per paket': 100000, 'per acara': 1000000},
      {'per porsi': 50000, 'per paket': 800000, 'per acara': 10000000},
      [
        'Nasi kotak: Rp 15.000 sampai Rp 35.000 per kotak',
        'Snack box: Rp 10.000 sampai Rp 25.000 per box',
        'Tumpeng (untuk 10 sampai 15 orang): Rp 350.000 sampai Rp 800.000',
        'Kue ulang tahun: Rp 100.000 sampai Rp 400.000',
      ],
    ),
    'guru_les': PanduanTarif(
      ['per sesi', 'per jam', 'per bulan'],
      {'per sesi': 50000, 'per jam': 40000, 'per bulan': 300000},
      {'per sesi': 150000, 'per jam': 100000, 'per bulan': 1000000},
      [
        'Les SD: Rp 40.000 sampai Rp 75.000 per pertemuan',
        'Les SMP atau SMA: Rp 60.000 sampai Rp 150.000 per pertemuan',
        'Guru ngaji anak: Rp 150.000 sampai Rp 400.000 per bulan',
        'Les musik atau gitar: Rp 75.000 sampai Rp 150.000 per pertemuan',
      ],
    ),
    'asuh': PanduanTarif(
      ['per hari', 'per bulan', 'per jam'],
      {'per hari': 80000, 'per bulan': 800000, 'per jam': 10000},
      {'per hari': 150000, 'per bulan': 3000000, 'per jam': 25000},
      [
        'Penitipan anak harian: Rp 50.000 sampai Rp 100.000 per hari',
        'Penitipan anak bulanan: Rp 600.000 sampai Rp 1.500.000 per anak',
        'Pengasuh datang ke rumah: Rp 80.000 sampai Rp 150.000 per hari',
      ],
    ),
    'fotografer': PanduanTarif(
      ['per acara', 'per paket', 'per jam'],
      {'per acara': 500000, 'per paket': 300000, 'per jam': 100000},
      {'per acara': 3000000, 'per paket': 2500000, 'per jam': 250000},
      [
        'Foto acara lamaran atau syukuran: Rp 500.000 sampai Rp 1.500.000',
        'Foto dan video pernikahan: Rp 2.000.000 sampai Rp 6.000.000',
        'Foto produk 10 foto: Rp 150.000 sampai Rp 400.000',
        'Pas foto: Rp 25.000 sampai Rp 50.000',
      ],
    ),
    'sewa_acara': PanduanTarif(
      ['per paket', 'per hari', 'per acara'],
      {'per paket': 500000, 'per hari': 100000, 'per acara': 500000},
      {'per paket': 3000000, 'per hari': 1000000, 'per acara': 3000000},
      [
        'Sewa tenda 4x6 meter: Rp 300.000 sampai Rp 600.000 per hari',
        'Sewa kursi plastik: Rp 1.500 sampai Rp 3.000 per kursi',
        'Sewa sound system acara kecil: Rp 500.000 sampai Rp 1.500.000',
      ],
    ),
    'salon': PanduanTarif(
      ['per layanan', 'per acara', 'per jam'],
      {'per layanan': 15000, 'per acara': 500000, 'per jam': 50000},
      {'per layanan': 150000, 'per acara': 3000000, 'per jam': 150000},
      [
        'Potong rambut pria: Rp 15.000 sampai Rp 40.000',
        'Potong rambut anak: Rp 15.000 sampai Rp 30.000',
        'Creambath: Rp 50.000 sampai Rp 100.000',
        'Rias wisuda atau lamaran: Rp 250.000 sampai Rp 600.000',
        'Rias pengantin: Rp 1.500.000 sampai Rp 5.000.000',
      ],
    ),
    'jahit': PanduanTarif(
      ['per potong', 'per paket'],
      {'per potong': 15000, 'per paket': 100000},
      {'per potong': 300000, 'per paket': 800000},
      [
        'Permak celana (potong ujung): Rp 15.000 sampai Rp 30.000',
        'Ganti resleting: Rp 15.000 sampai Rp 30.000',
        'Jahit kemeja atau baju: Rp 100.000 sampai Rp 250.000',
        'Jahit kebaya: Rp 250.000 sampai Rp 800.000',
        'Jahit seragam sekolah: Rp 75.000 sampai Rp 150.000 per potong',
      ],
    ),
    'angkut': PanduanTarif(
      ['per trip', 'per jam', 'per hari'],
      {'per trip': 15000, 'per jam': 30000, 'per hari': 250000},
      {'per trip': 500000, 'per jam': 80000, 'per hari': 600000},
      [
        'Ojek jarak dekat di dalam desa: Rp 10.000 sampai Rp 25.000',
        'Antar-jemput sekolah: Rp 300.000 sampai Rp 600.000 per bulan',
        'Pindahan memakai pick up: Rp 250.000 sampai Rp 600.000 per trip',
        'Antar paket atau belanjaan di dalam desa: Rp 5.000 sampai Rp 15.000',
      ],
    ),
    'lainnya': PanduanTarif(
      ['per hari', 'per jam', 'per proyek', 'per paket'],
      {'per hari': 100000, 'per jam': 20000, 'per proyek': 200000, 'per paket': 100000},
      {'per hari': 200000, 'per jam': 50000, 'per proyek': 1500000, 'per paket': 500000},
      [
        'Tarif umum harian: Rp 100.000 sampai Rp 200.000 per hari',
        'Sesuaikan dengan lama dan tingkat kesulitan pekerjaan.',
      ],
    ),
  };
}
