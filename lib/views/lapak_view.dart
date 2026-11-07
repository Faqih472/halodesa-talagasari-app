// ============================================================
// lapak_view.dart — LAPAK UMKM DESA: warga membuka usaha (nasi uduk, toko
// baju, bengkel, toko buah, dll.), warga lain melihat, memesan lewat chat,
// dan memberi ulasan. Firestore saja (gratis). Foto base64.
// ============================================================
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../core/core.dart';
import '../core/models.dart' show rupiah;
import '../core/ui_helpers.dart';
import 'chat_view.dart';
import 'info_sosial.dart' show GaleriFoto;
import 'moderasi_view.dart';
import 'verification_view.dart' show wajibVerifikasi;

// ─────────────────────────────────────────────────────────────
// DATA KATEGORI (terstruktur: kelompok → jenis usaha)
// ─────────────────────────────────────────────────────────────
class JenisLapak {
  final String id;
  final String label;
  final String contoh; // contoh nama usaha
  final String contohProduk; // contoh isi daftar produk
  const JenisLapak(this.id, this.label, this.contoh, this.contohProduk);
}

class KelompokLapak {
  final String id;
  final String label;
  final IconData ikon;
  final Color warna;
  final String ringkas;
  final List<JenisLapak> jenis;
  const KelompokLapak(this.id, this.label, this.ikon, this.warna, this.ringkas, this.jenis);
}

const List<KelompokLapak> kelompokLapak = [
  KelompokLapak('makanan', 'Makanan & Minuman', Icons.restaurant, Color(0xFFE65100),
      'Warung makan, sarapan, jajanan, kue, minuman.', [
    JenisLapak('sarapan', 'Sarapan pagi', 'Nasi Uduk Bu Ani',
        'Nasi uduk + telur = 12000; Lontong sayur = 10000; Bubur ayam = 12000'),
    JenisLapak('nasi_goreng_mie', 'Nasi goreng, mie & kwetiau', 'Nasi Goreng Bang Ucup',
        'Nasi goreng biasa = 13000; Nasi goreng spesial = 18000; Mie goreng = 12000'),
    JenisLapak('warteg', 'Warteg / nasi rames / katering harian', 'Warteg Mbak Sri',
        'Nasi + sayur + lauk = 15000; Nasi kotak 20 porsi = 300000'),
    JenisLapak('gorengan', 'Gorengan & jajanan', 'Gorengan Pak Haji',
        'Bakwan = 1000; Pisang goreng = 1500; Cireng isi = 2000'),
    JenisLapak('bakso_soto', 'Bakso, soto & sop', 'Bakso Mas Joko',
        'Bakso urat = 15000; Soto ayam = 14000'),
    JenisLapak('kue_roti', 'Kue, roti & donat', 'Kue Basah Bu Rini',
        'Kue lapis (isi 10) = 25000; Donat (isi 6) = 20000'),
    JenisLapak('minuman', 'Minuman: es, kopi & jus', 'Es Teh Jumbo Pak Ade',
        'Es teh = 4000; Kopi susu = 10000; Jus alpukat = 12000'),
    JenisLapak('lauk_matang', 'Lauk matang & sate', 'Pecel Lele Cak Kasim',
        'Pecel lele = 18000; Ayam goreng = 15000; Sate ayam 10 tusuk = 20000'),
  ]),
  KelompokLapak('pangan', 'Bahan Pangan & Sembako', Icons.shopping_basket_outlined, Color(0xFF2E7D32),
      'Warung sembako, sayur, buah, daging, telur, beras, gas.', [
    JenisLapak('sembako', 'Warung sembako', 'Warung Sembako Bu Ratna',
        'Beras 5 kg = 68000; Minyak goreng 1 L = 18000; Gula 1 kg = 17000'),
    JenisLapak('sayur_buah', 'Sayur & toko buah', 'Toko Buah Segar Pak Dedi',
        'Jeruk per kg = 25000; Apel per kg = 35000; Pisang per sisir = 15000'),
    JenisLapak('daging_ikan', 'Daging, ayam & ikan', 'Ayam Potong Pak Mamat',
        'Ayam potong per kg = 38000; Ikan lele per kg = 28000'),
    JenisLapak('telur_unggas', 'Telur & unggas', 'Telur Segar Bu Enah',
        'Telur ayam per kg = 29000; Telur bebek per butir = 3500'),
    JenisLapak('beras_gas', 'Beras, gas & galon', 'Agen Gas & Galon Pak Rudi',
        'Gas 3 kg = 22000; Galon isi ulang = 6000; Beras 25 kg = 320000'),
  ]),
  KelompokLapak('fashion', 'Fashion & Pakaian', Icons.checkroom, Color(0xFFAD1457),
      'Toko baju, sepatu, tas, hijab. (Jahit & permak ada di Cari Jasa.)', [
    JenisLapak('toko_baju', 'Toko baju', 'Toko Baju Anugerah',
        'Kaos anak = 45000; Kemeja pria = 95000; Gamis = 150000'),
    JenisLapak('sepatu_tas', 'Sepatu, sandal & tas', 'Toko Sepatu Berkah',
        'Sandal jepit = 25000; Sepatu sekolah = 120000'),
    JenisLapak('hijab_aksesoris', 'Hijab & aksesoris', 'Hijab Cantik Teh Lia',
        'Pashmina = 35000; Jilbab instan = 45000'),
  ]),
  KelompokLapak('otomotif', 'Otomotif: Suku Cadang & Kendaraan', Icons.two_wheeler, Color(0xFF37474F),
      'Menjual suku cadang, oli, helm, atau kendaraan bekas. (Bengkel & tambal ban ada di Cari Jasa.)', [
    JenisLapak('kendaraan_bekas', 'Motor / sepeda bekas', 'Jual Beli Motor Bekas Pak Anto',
        'Motor bekas (sesuai unit, nego); Sepeda anak = 450000'),
    JenisLapak('sparepart', 'Suku cadang & aksesoris', 'Toko Sparepart Mandiri',
        'Oli 1 L = 55000; Kampas rem = 40000; Helm = 120000'),
  ]),
  KelompokLapak('rumah', 'Rumah, Bangunan & Perabot', Icons.home_repair_service_outlined, Color(0xFF6D4C41),
      'Toko bangunan, mebel, perabot, listrik dan air.', [
    JenisLapak('toko_bangunan', 'Toko bangunan', 'Toko Bangunan Sumber Rejeki',
        'Semen 40 kg = 65000; Cat tembok 5 kg = 90000; Pasir per m3 = 250000'),
    JenisLapak('mebel', 'Mebel & furnitur', 'Mebel Jati Pak Ahmad',
        'Kursi tamu (set) = 2500000; Lemari 2 pintu = 1200000'),
    JenisLapak('perabot', 'Perabot & peralatan rumah', 'Toko Perabot Bu Sari',
        'Panci = 50000; Piring (isi 6) = 60000'),
    JenisLapak('listrik_air', 'Alat listrik & pipa air', 'Toko Listrik Maju',
        'Lampu LED = 25000; Kabel per meter = 6000; Pipa PVC = 30000'),
  ]),
  KelompokLapak('elektronik', 'Elektronik & Digital', Icons.devices_other, Color(0xFF1565C0),
      'Konter pulsa, fotokopi, toko elektronik. (Servis HP/TV ada di Cari Jasa.)', [
    JenisLapak('konter', 'Konter pulsa & paket data', 'Konter Pulsa Mandiri',
        'Pulsa 10rb = 12000; Token listrik 50rb = 52500; Paket data'),
    JenisLapak('fotokopi_print', 'Fotokopi & print', 'Fotokopi Cepat Jaya',
        'Fotokopi per lembar = 300; Print warna = 1500; Jilid = 5000'),
    JenisLapak('toko_elektronik', 'Toko elektronik', 'Toko Elektronik Surya',
        'Kipas angin = 250000; Setrika = 120000; Lampu emergency = 80000'),
  ]),
  KelompokLapak('kecantikan', 'Jamu, Herbal & Kosmetik', Icons.spa_outlined, Color(0xFF00897B),
      'Jamu, herbal, dan kosmetik. (Salon & pijat ada di Cari Jasa.)', [
    JenisLapak('jamu_herbal', 'Jamu & herbal', 'Jamu Gendong Mbok Yem',
        'Kunyit asam = 5000; Beras kencur = 5000; Jamu pegal linu = 7000'),
    JenisLapak('kosmetik', 'Kosmetik & perawatan', 'Toko Kosmetik Cantik',
        'Bedak = 25000; Sabun wajah = 30000'),
  ]),
  KelompokLapak('pertanian', 'Pertanian, Peternakan & Perikanan', Icons.agriculture_outlined, Color(0xFF558B2F),
      'Bibit, pupuk, tanaman hias, ternak, ikan.', [
    JenisLapak('bibit_pupuk', 'Bibit, pupuk & obat tanaman', 'Toko Tani Makmur',
        'Pupuk urea 1 kg = 3000; Bibit cabai = 15000'),
    JenisLapak('tanaman_hias', 'Tanaman hias', 'Taman Hijau Pak Slamet',
        'Monstera = 75000; Pot tanah liat = 15000'),
    JenisLapak('ternak', 'Ternak & hewan peliharaan', 'Ternak Kambing Pak Jaja',
        'Kambing (nego); Ayam kampung per ekor = 85000; Pakan = 12000'),
    JenisLapak('perikanan', 'Ikan & budidaya', 'Kolam Lele Barokah',
        'Bibit lele per 100 = 40000; Lele konsumsi per kg = 28000'),
  ]),
  KelompokLapak('kerajinan', 'Kerajinan, Oleh-oleh & Mainan', Icons.palette_outlined, Color(0xFFF9A825),
      'Kerajinan tangan, makanan khas, souvenir, mainan anak.', [
    JenisLapak('percetakan', 'Percetakan, sablon & undangan', 'Sablon Kaos Kreatif',
        'Sablon kaos satuan = 55000; Undangan 100 lembar = 250000'),
    JenisLapak('kerajinan', 'Kerajinan tangan', 'Anyaman Bambu Mak Isah',
        'Keranjang = 35000; Tempat tisu = 25000'),
    JenisLapak('oleh_oleh', 'Makanan khas & oleh-oleh', 'Keripik Singkong Bu Nining',
        'Keripik singkong 250 g = 15000; Emping = 30000'),
    JenisLapak('souvenir', 'Souvenir & hampers', 'Hampers Lebaran Cantik',
        'Hampers kecil = 75000; Souvenir pernikahan per pcs = 5000'),
    JenisLapak('mainan', 'Mainan anak', 'Toko Mainan Ceria',
        'Mobil-mobilan = 25000; Puzzle = 35000'),
  ]),
  KelompokLapak('sekolah', 'Alat Tulis, Buku & Sekolah', Icons.menu_book_outlined, Color(0xFF0277BD),
      'Toko ATK, buku, seragam dan perlengkapan sekolah.', [
    JenisLapak('atk', 'Toko alat tulis (ATK)', 'Toko ATK Cerdas',
        'Buku tulis = 5000; Pulpen = 3000; Penggaris = 4000'),
    JenisLapak('buku', 'Toko buku', 'Toko Buku Ilmu',
        'Buku pelajaran (sesuai kelas); Buku cerita = 25000'),
    JenisLapak('seragam', 'Seragam & perlengkapan sekolah', 'Seragam Sekolah Bu Tuti',
        'Seragam SD = 110000; Tas sekolah = 95000'),
  ]),
  KelompokLapak('lainnya', 'Usaha Lainnya', Icons.storefront_outlined, Color(0xFF546E7A),
      'Usaha yang belum cocok di kelompok lain.', [
    JenisLapak('lain', 'Usaha lain', 'Usaha Keluarga Kami', 'Tulis produk atau layanan Anda'),
  ]),
];

KelompokLapak kelompokDari(String id) =>
    kelompokLapak.firstWhere((k) => k.id == id, orElse: () => kelompokLapak.last);

JenisLapak? jenisDari(String kel, String id) {
  for (final j in kelompokDari(kel).jenis) {
    if (j.id == id) return j;
  }
  return null;
}

const List<String> _namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────
class ProdukLapak {
  String nama;
  int harga; // 0 = tanya penjual
  String ket;
  bool habis;
  ProdukLapak({this.nama = '', this.harga = 0, this.ket = '', this.habis = false});

  Map<String, dynamic> toMap() => {'nama': nama, 'harga': harga, 'ket': ket, 'habis': habis};

  factory ProdukLapak.dari(Map m) => ProdukLapak(
        nama: '${m['nama'] ?? ''}',
        harga: (m['harga'] ?? 0) is int ? m['harga'] as int : int.tryParse('${m['harga']}') ?? 0,
        ket: '${m['ket'] ?? ''}',
        habis: m['habis'] == true,
      );
}

class LapakModel {
  final String id;
  final String uid;
  final String namaPemilik;
  final String fotoPemilik;
  final String nama;
  final String kelompok;
  final String jenis;
  final String deskripsi;
  final List<String> foto;
  final String alamat;
  final double lat;
  final double lng;
  final List<int> hari; // 1=Senin ... 7=Minggu
  final String jamBuka;
  final String jamTutup;
  final String whatsapp;
  final List<String> layanan; // antar | ambil | di_tempat
  final String bentuk; // menetap | keliling | rumahan
  final List<ProdukLapak> produk;
  final bool bukaManual; // pemilik menekan "Buka / Tutup"
  final String status; // aktif | disembunyikan
  final String alasanAdmin;
  final int ratingTotal;
  final int ratingJumlah;
  final int dilihat;
  final DateTime? dibuat;

  LapakModel({
    required this.id,
    required this.uid,
    required this.namaPemilik,
    required this.fotoPemilik,
    required this.nama,
    required this.kelompok,
    required this.jenis,
    required this.deskripsi,
    required this.foto,
    required this.alamat,
    required this.lat,
    required this.lng,
    required this.hari,
    required this.jamBuka,
    required this.jamTutup,
    required this.whatsapp,
    required this.layanan,
    required this.bentuk,
    required this.produk,
    required this.bukaManual,
    required this.status,
    required this.alasanAdmin,
    required this.ratingTotal,
    required this.ratingJumlah,
    required this.dilihat,
    required this.dibuat,
  });

  factory LapakModel.dari(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    List<T> daftar<T>(dynamic v, T Function(dynamic) f) =>
        v is List ? v.map(f).toList() : <T>[];
    return LapakModel(
      id: d.id,
      uid: '${m['uid'] ?? ''}',
      namaPemilik: '${m['nama_pemilik'] ?? ''}',
      fotoPemilik: '${m['foto_pemilik'] ?? ''}',
      nama: '${m['nama'] ?? ''}',
      kelompok: '${m['kelompok'] ?? 'lainnya'}',
      jenis: '${m['jenis'] ?? ''}',
      deskripsi: '${m['deskripsi'] ?? ''}',
      foto: daftar<String>(m['foto_list'], (e) => '$e'),
      alamat: '${m['alamat'] ?? ''}',
      lat: (m['lat'] ?? 0).toDouble(),
      lng: (m['lng'] ?? 0).toDouble(),
      hari: daftar<int>(m['hari'], (e) => (e as num).toInt()),
      jamBuka: '${m['jam_buka'] ?? '08:00'}',
      jamTutup: '${m['jam_tutup'] ?? '17:00'}',
      whatsapp: '${m['whatsapp'] ?? ''}',
      layanan: daftar<String>(m['layanan'], (e) => '$e'),
      bentuk: '${m['bentuk'] ?? 'menetap'}',
      produk: daftar<ProdukLapak>(m['produk'], (e) => ProdukLapak.dari(e as Map)),
      bukaManual: m['buka_manual'] != false,
      status: '${m['status'] ?? 'aktif'}',
      alasanAdmin: '${m['alasan_admin'] ?? ''}',
      ratingTotal: (m['rating_total'] ?? 0) as int,
      ratingJumlah: (m['rating_jumlah'] ?? 0) as int,
      dilihat: (m['dilihat'] ?? 0) as int,
      dibuat: (m['created_at'] as Timestamp?)?.toDate(),
    );
  }

  bool get punyaLokasi => lat != 0 || lng != 0;
  double get rating => ratingJumlah == 0 ? 0 : ratingTotal / ratingJumlah;

  int _mnt(String s) {
    final p = s.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  /// Buka sekarang bila: pemilik tidak menutup manual, hari ini termasuk jadwal,
  /// dan jam sekarang di antara jam buka–tutup.
  bool get bukaSekarang {
    if (!bukaManual) return false;
    final n = DateTime.now();
    if (hari.isNotEmpty && !hari.contains(n.weekday)) return false;
    final skrg = n.hour * 60 + n.minute;
    final b = _mnt(jamBuka), t = _mnt(jamTutup);
    if (t > b) return skrg >= b && skrg <= t;
    return skrg >= b || skrg <= t; // lewat tengah malam
  }

  String get ringkasHari {
    if (hari.isEmpty || hari.length == 7) return 'Setiap hari';
    final u = [...hari]..sort();
    return u.map((h) => _namaHari[h - 1]).join(', ');
  }

  String get namaJenis => jenisDari(kelompok, jenis)?.label ?? kelompokDari(kelompok).label;
}

const Map<String, String> _labelLayanan = {
  'antar': 'Diantar ke rumah',
  'ambil': 'Ambil di tempat',
  'di_tempat': 'Makan / dilayani di tempat',
};
const Map<String, String> _labelBentuk = {
  'menetap': 'Toko / kios tetap',
  'keliling': 'Keliling kampung',
  'rumahan': 'Usaha di rumah',
};

// ─────────────────────────────────────────────────────────────
// PANDUAN (penjelasan + contoh untuk orang awam)
// ─────────────────────────────────────────────────────────────
class PanduanLapakView extends StatelessWidget {
  const PanduanLapakView({super.key});

  Widget _j(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _p(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Text(t, style: const TextStyle(fontSize: 13.5, height: 1.45)),
      );

  Widget _kotak(String judul, List<String> baris, Color c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 4),
          for (final b in baris)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(b, style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Panduan Lapak UMKM')),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        _j('Apa itu Lapak UMKM?'),
        _p('Lapak UMKM adalah etalase online untuk usaha warga Desa Talagasari. Siapa saja yang punya usaha kecil (warung, toko, bengkel, dagangan keliling, usaha rumahan) bisa memasang lapaknya di sini supaya dikenal tetangga, lalu pembeli bisa melihat daftar produk, jam buka, lokasi, dan memesan lewat chat.'),
        _kotak('Beda Lapak dan Jasa (penting)', [
          '• LAPAK = Anda MENJUAL BARANG atau makanan. Pembeli datang atau minta diantar, bayar, barang diterima. Contoh: nasi uduk, toko baju, toko buah, toko bangunan, sparepart.',
          '• JASA = Anda MENAWARKAN TENAGA atau keahlian. Pelanggan memesan lalu Anda mengerjakan. Contoh: tukang, bengkel/tambal ban, servis HP, salon, laundry, jahit, katering acara, sewa tenda.',
          '• Satu usaha bisa punya dua-duanya. Contoh: toko HP menjual HP (Lapak) dan menerima servis (Jasa).',
          '• Tidak yakin? Tanya: "yang dibeli orang itu BARANG atau PEKERJAAN saya?" Barang → Lapak. Pekerjaan → Jasa.',
        ], Colors.blue.shade700),
        _j('Contoh nyata'),
        _kotak('Nasi uduk pagi', [
          'Ibu Ani jualan nasi uduk di depan rumah jam 05.30–09.00. Ia membuka lapak: kelompok "Makanan & Minuman" → "Sarapan pagi". Daftar menu: Nasi uduk + telur 12.000, Lontong sayur 10.000. Hari: Senin–Sabtu. Layanan: Ambil di tempat dan Diantar.',
        ], Colors.orange.shade800),
        _kotak('Toko buah', [
          'Pak Dedi punya toko buah. Ia memasang foto toko, mengisi harga jeruk, apel, pisang per kg, jam buka 07.00–20.00, lalu menandai lokasi di peta. Pembeli bisa chat untuk pesan dan minta diantar.',
        ], Colors.green.shade700),
        _kotak('Toko sparepart motor', [
          'Toko Sparepart Mandiri menjual oli 55.000, kampas rem 40.000, helm 120.000. Bengkel yang memperbaiki motor memasang usahanya di Cari Jasa (kategori Bengkel), bukan di Lapak.',
        ], Colors.blueGrey.shade700),
        _j('Cara membuka lapak (5 langkah)'),
        _p('1. Buka tab Jasa → pilih "Lapak UMKM" → tekan tombol "Buka Lapak".\n'
            '2. Pilih kelompok dan jenis usaha. Contoh nama akan muncul sebagai petunjuk.\n'
            '3. Isi nama lapak, penjelasan singkat, dan foto (maksimal 3).\n'
            '4. Isi daftar produk beserta harga. Boleh dikosongi bila harga berubah-ubah.\n'
            '5. Isi hari dan jam buka, cara layanan, nomor WhatsApp, dan alamat. Peta bersifat opsional.'),
        _j('Cara membeli'),
        _p('1. Buka tab Lapak UMKM, cari lewat kategori atau ketik nama.\n'
            '2. Ketuk lapak yang cocok, lihat produk dan jam buka.\n'
            '3. Tekan + pada produk yang ingin dibeli.\n'
            '4. Tekan "Pesan lewat Chat". Rincian pesanan terkirim otomatis ke penjual.\n'
            '5. Bayar dan terima barang sesuai kesepakatan dengan penjual (aplikasi tidak memproses uang).'),
        _j('Penting diketahui'),
        _kotak('Tanggung jawab bersama', [
          '• Aplikasi hanya mempertemukan pembeli dan penjual. Pembayaran langsung antara kalian.',
          '• Lapak hanya boleh untuk usaha di Desa Talagasari.',
          '• Dilarang menjual barang terlarang atau menipu. Lihat Aturan Komunitas di menu Akun.',
          '• Curiga ada penipuan? Tekan ⋮ lalu "Laporkan lapak ini".',
          '• Pembeli bisa memberi bintang dan ulasan jujur setelah membeli.',
        ], Colors.red.shade700),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DAFTAR LAPAK (tab di halaman Jasa)
// ─────────────────────────────────────────────────────────────
class LapakTab extends StatefulWidget {
  final Color primary;
  const LapakTab({super.key, required this.primary});

  @override
  State<LapakTab> createState() => _LapakTabState();
}

class _LapakTabState extends State<LapakTab> {
  final _cari = TextEditingController();
  String _kel = 'semua';
  bool _hanyaBuka = false;
  bool _peta = false;
  String _urut = 'terbaru';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore.instance
      .collection('lapak_umkm')
      .where('status', isEqualTo: 'aktif')
      .limit(200)
      .snapshots();

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _buka() async {
    final auth = Get.find<AuthController>();
    if (auth.role == 'warga' && !await wajibVerifikasi()) return;
    await Get.to(() => const LapakFormView());
  }

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _cari,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cari lapak: nasi uduk, bengkel, toko buah...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _cari.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _cari.clear())),
            isDense: true,
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            _chip('semua', 'Semua', Icons.apps, widget.primary),
            for (final k in kelompokLapak) _chip(k.id, k.label, k.ikon, k.warna),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilterChip(
            label: const Text('Buka sekarang', style: TextStyle(fontSize: 12)),
            selected: _hanyaBuka,
            onSelected: (v) => setState(() => _hanyaBuka = v),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Peta', style: TextStyle(fontSize: 12)),
            selected: _peta,
            onSelected: (v) => setState(() => _peta = v),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _urut,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            items: const [
              DropdownMenuItem(value: 'terbaru', child: Text('Terbaru')),
              DropdownMenuItem(value: 'rating', child: Text('Rating tertinggi')),
              DropdownMenuItem(value: 'ramai', child: Text('Paling dilihat')),
            ],
            onChanged: (v) => setState(() => _urut = v ?? 'terbaru'),
          ),
          TextButton.icon(
            onPressed: () => Get.to(() => const LapakSayaView()),
            icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
            label: const Text('Lapak saya'),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Lapak belum dapat dimuat',
                  subtitle:
                      'Periksa koneksi internet. Bila terus muncul, pastikan aturan Firestore terbaru sudah dipasang.');
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var list = snap.data!.docs.map(LapakModel.dari).toList();
            final q = _cari.text.trim().toLowerCase();
            if (_kel != 'semua') list = list.where((l) => l.kelompok == _kel).toList();
            if (_hanyaBuka) list = list.where((l) => l.bukaSekarang).toList();
            if (q.isNotEmpty) {
              list = list
                  .where((l) =>
                      l.nama.toLowerCase().contains(q) ||
                      l.namaJenis.toLowerCase().contains(q) ||
                      l.deskripsi.toLowerCase().contains(q) ||
                      l.produk.any((p) => p.nama.toLowerCase().contains(q)))
                  .toList();
            }
            list.sort((a, b) {
              if (_urut == 'rating') return b.rating.compareTo(a.rating);
              if (_urut == 'ramai') return b.dilihat.compareTo(a.dilihat);
              return (b.dibuat ?? DateTime(2000)).compareTo(a.dibuat ?? DateTime(2000));
            });
            return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
              _PanduanLapakRingkas(onBuka: _buka),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Belum ada lapak',
                      subtitle:
                          'Belum ada lapak yang cocok. Jadilah yang pertama membuka lapak di kategori ini.'),
                ),
              if (_peta)
                PetaDaftar(
                  namaItem: 'lapak',
                  totalItem: list.length,
                  titik: [
                    for (final l in list)
                      if (l.punyaLokasi)
                        TitikPeta(LatLng(l.lat, l.lng), l.nama, l.namaJenis,
                            kelompokDari(l.kelompok).warna,
                            () => Get.to(() => LapakDetailView(id: l.id))),
                  ],
                )
              else
                for (final l in list) KartuLapak(l: l, saya: uid),
            ]);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: widget.primary, minimumSize: const Size(0, 48)),
          onPressed: _buka,
          icon: const Icon(Icons.add_business_outlined, color: Colors.white),
          label: const Text('Buka Lapak Usaha Saya'),
        ),
      ),
    ]);
  }

  Widget _chip(String id, String label, IconData ik, Color c) {
    final sel = _kel == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: ChoiceChip(
        avatar: Icon(ik, size: 16, color: sel ? Colors.white : c),
        label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
        selected: sel,
        selectedColor: c,
        showCheckmark: false,
        onSelected: (_) => setState(() => _kel = id),
      ),
    );
  }
}

class _PanduanLapakRingkas extends StatelessWidget {
  final VoidCallback onBuka;
  const _PanduanLapakRingkas({required this.onBuka});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.lightbulb_outline, color: Colors.orange.shade800),
          title: const Text('Apa itu Lapak UMKM? Baca di sini',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Tempat warga Talagasari menjual BARANG dan makanan (warung, toko, dagangan keliling). Kalau yang ditawarkan tenaga/keahlian (tukang, bengkel, servis, salon, laundry), pakai "Cari Jasa".',
                style: TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 8),
            const Text('Contoh:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text(
                '• Mau sarapan: cari "Makanan & Minuman", pilih Nasi Uduk Bu Ani, tekan + pada menu, lalu "Pesan lewat Chat".\n'
                '• Punya toko buah: tekan "Buka Lapak", isi harga, foto, dan jam buka.\n'
                '• Motor bocor ban? Itu pekerjaan, cari di tab Cari Jasa (kategori Bengkel).',
                style: TextStyle(fontSize: 13, height: 1.45)),
            const SizedBox(height: 6),
            Row(children: [
              TextButton(
                  onPressed: () => Get.to(() => const PanduanLapakView()),
                  child: const Text('Panduan lengkap')),
              TextButton(onPressed: onBuka, child: const Text('Buka lapak')),
            ]),
          ],
        ),
      ),
    );
  }
}

class KartuLapak extends StatelessWidget {
  final LapakModel l;
  final String saya;
  const KartuLapak({required this.l, required this.saya});

  @override
  Widget build(BuildContext context) {
    final k = kelompokDari(l.kelompok);
    final buka = l.bukaSekarang;
    return kartuGaris(
      warna: k.warna,
      onTap: () => Get.to(() => LapakDetailView(id: l.id)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 92,
              height: 92,
              child: l.foto.isNotEmpty
                  ? ImageUtil.image(l.foto.first, fit: BoxFit.cover)
                  : Container(
                      color: k.warna.withOpacity(0.15),
                      child: Icon(k.ikon, size: 38, color: k.warna)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(l.namaJenis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: k.warna, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: buka ? Colors.green.shade600 : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(buka ? 'BUKA' : 'TUTUP',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                if (l.ratingJumlah > 0) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' ${l.rating.toStringAsFixed(1)} (${l.ratingJumlah})',
                      style: const TextStyle(fontSize: 12)),
                ] else
                  const Text('Belum ada ulasan',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Text('${l.jamBuka}–${l.jamTutup} · ${l.ringkasHari}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              if (l.produk.isNotEmpty)
                Text(
                    'Mulai ${rupiah(l.produk.where((p) => p.harga > 0).map((p) => p.harga).fold<int>(0, (a, b) => a == 0 || b < a ? b : a))}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: k.warna)),
            ]),
          ),
        ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL LAPAK
// ─────────────────────────────────────────────────────────────
class LapakDetailView extends StatefulWidget {
  final String id;
  const LapakDetailView({super.key, required this.id});

  @override
  State<LapakDetailView> createState() => _LapakDetailViewState();
}

class _LapakDetailViewState extends State<LapakDetailView> {
  final Map<int, int> _qty = {}; // index produk → jumlah
  bool _hitung = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('lapak_umkm').doc(widget.id);

  int _total(LapakModel l) {
    var t = 0;
    _qty.forEach((i, q) {
      if (i < l.produk.length) t += l.produk[i].harga * q;
    });
    return t;
  }

  int _jumlahItem() => _qty.values.fold(0, (a, b) => a + b);

  Future<void> _pesan(LapakModel l) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null) return;
    if (l.uid == me.uid) {
      showSnack(false, '', 'Ini lapak Anda sendiri.');
      return;
    }
    if (_jumlahItem() == 0) {
      showSnack(false, '', 'Tekan + pada produk yang ingin dipesan dulu.');
      return;
    }
    String cara = l.layanan.isNotEmpty ? l.layanan.first : 'ambil';
    final catatan = TextEditingController();
    final alamat = TextEditingController(text: me.alamatLengkap);
    final ok = await Get.dialog<bool>(StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: const Text('Kirim pesanan'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cara terima:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: [
              for (final c in (l.layanan.isEmpty ? ['ambil'] : l.layanan))
                ChoiceChip(
                  label: Text(_labelLayanan[c] ?? c, style: const TextStyle(fontSize: 12)),
                  selected: cara == c,
                  onSelected: (_) => setS(() => cara = c),
                ),
            ]),
            if (cara == 'antar') ...[
              const SizedBox(height: 8),
              TextField(
                controller: alamat,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Alamat antar', hintText: 'Kp. ..., RT/RW ..., patokan rumah'),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: catatan,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: Tidak pedas, ambil jam 7 pagi.'),
            ),
            const SizedBox(height: 8),
            Text('Total perkiraan: ${rupiah(_total(l))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
              onPressed: () => Get.back(result: true),
              child: const Text('Kirim ke penjual')),
        ],
      );
    }));
    if (ok != true) return;
    final b = StringBuffer('Halo, saya ${me.nama}. Saya ingin memesan di ${l.nama}:\n');
    _qty.forEach((i, q) {
      if (q > 0 && i < l.produk.length) {
        final p = l.produk[i];
        b.writeln('• $q× ${p.nama}${p.harga > 0 ? ' (${rupiah(p.harga * q)})' : ''}');
      }
    });
    b.writeln('Total perkiraan: ${rupiah(_total(l))}');
    b.writeln('Cara: ${_labelLayanan[cara] ?? cara}');
    if (cara == 'antar' && alamat.text.trim().isNotEmpty) {
      b.writeln('Alamat antar: ${alamat.text.trim()}');
    }
    if (catatan.text.trim().isNotEmpty) b.writeln('Catatan: ${catatan.text.trim()}');
    try {
      final chat = Get.find<ChatController>();
      final room = await chat.bukaAtauBuatRoom(
          otherUid: l.uid, otherNama: l.namaPemilik, otherFoto: l.fotoPemilik);
      await chat.kirimPesan(room.id, b.toString().trim(), otherUid: l.uid);
      showSnack(true, 'Pesanan terkirim ke penjual lewat chat.', '');
      await Get.to(() => ChatRoomView(
            roomId: room.id,
            otherUid: l.uid,
            namaLawan: room.namaLawan(me.uid),
            fotoLawan: room.fotoLawan(me.uid),
          ));
    } catch (e) {
      showSnack(false, '', 'Gagal mengirim pesanan: $e');
    }
  }

  Future<void> _wa(LapakModel l) async {
    var n = l.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = '62${n.substring(1)}';
    if (n.length < 9) {
      showSnack(false, '', 'Penjual belum mengisi nomor WhatsApp.');
      return;
    }
    await bukaUri(Uri.parse(
        'https://wa.me/$n?text=${Uri.encodeComponent('Halo, saya melihat ${l.nama} di aplikasi Talagasari Hub.')}'));
  }

  @override
  Widget build(BuildContext context) {
    final me = Get.find<AuthController>().currentUser.value;
    final primary = AppTheme.primaryColor(me?.role ?? 'warga');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
              appBar: AppBar(backgroundColor: primary),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) {
          return Scaffold(
              appBar: AppBar(backgroundColor: primary),
              body: const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Lapak tidak ditemukan',
                  subtitle: 'Lapak ini sudah dihapus pemiliknya.'));
        }
        final l = LapakModel.dari(snap.data!);
        if (!_hitung) {
          _hitung = true;
          if (me != null && me.uid != l.uid) {
            _ref.update({'dilihat': FieldValue.increment(1)}).catchError((_) {});
          }
        }
        final milik = me?.uid == l.uid;
        final k = kelompokDari(l.kelompok);
        final buka = l.bukaSekarang;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: primary,
            title: Text(l.nama, overflow: TextOverflow.ellipsis),
            actions: [
              if (milik)
                IconButton(
                    tooltip: 'Ubah lapak',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Get.to(() => LapakFormView(awal: l))),
              if (!milik)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'profil') {
                      bukaProfil(l.uid, nama: l.namaPemilik);
                    } else {
                      laporkan(
                        tipe: 'lapak',
                        targetId: l.id,
                        targetUid: l.uid,
                        targetNama: '${l.nama} (${l.namaPemilik})',
                        cuplikan: l.deskripsi,
                        targetPath: 'lapak_umkm/${l.id}',
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'profil', child: Text('Lihat profil penjual')),
                    PopupMenuItem(value: 'lapor', child: Text('Laporkan lapak ini')),
                  ],
                ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
            if (l.status != 'aktif')
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(10),
                child: Text(
                    'Lapak ini disembunyikan Admin${l.alasanAdmin.isEmpty ? '' : ': ${l.alasanAdmin}'}',
                    style: TextStyle(color: Colors.red.shade800)),
              ),
            if (l.foto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GaleriFoto(foto: l.foto),
              ),
            kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(k.ikon, size: 18, color: k.warna),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${k.label} · ${l.namaJenis}',
                        style: TextStyle(
                            color: k.warna, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: buka ? Colors.green.shade600 : Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(buka ? 'BUKA SEKARANG' : 'TUTUP',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  if (l.ratingJumlah > 0) ...[
                    const Icon(Icons.star, size: 18, color: Colors.amber),
                    Text(' ${l.rating.toStringAsFixed(1)} · ${l.ratingJumlah} ulasan',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ]),
                const SizedBox(height: 10),
                _baris(Icons.schedule, '${l.jamBuka}–${l.jamTutup} · ${l.ringkasHari}'),
                _baris(Icons.store_outlined, _labelBentuk[l.bentuk] ?? l.bentuk),
                if (l.layanan.isNotEmpty)
                  _baris(Icons.delivery_dining_outlined,
                      l.layanan.map((e) => _labelLayanan[e] ?? e).join(' · ')),
                if (l.alamat.isNotEmpty) _baris(Icons.place_outlined, l.alamat),
                if (l.deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l.deskripsi, style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
              ]),
            ),
            if (l.punyaLokasi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PetaDenganLokasi(
                    pusat: LatLng(l.lat, l.lng),
                    tinggi: 170,
                    penanda: [
                      Marker(
                        point: LatLng(l.lat, l.lng),
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on, size: 40, color: k.warna),
                      ),
                    ],
                  ),
                ),
              ),
            if (l.produk.isNotEmpty) ...[
              const SectionTitle('Daftar produk / harga'),
              for (var i = 0; i < l.produk.length; i++) _barisProduk(l, i, milik),
            ] else
              kartu(
                child: const Text(
                    'Penjual belum mengisi daftar produk. Tanyakan langsung lewat chat atau WhatsApp.',
                    style: TextStyle(fontSize: 13)),
              ),
            _penjual(l, milik),
            const SectionTitle('Ulasan pembeli'),
            _Ulasan(lapak: l, milik: milik),
          ]),
          bottomNavigationBar: milik
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
                    ]),
                    child: Row(children: [
                      IconButton(
                        tooltip: 'WhatsApp',
                        onPressed: () => _wa(l),
                        icon: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFF25D366)),
                      ),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primary, minimumSize: const Size(0, 48)),
                          onPressed: () => _jumlahItem() == 0
                              ? _chatSaja(l)
                              : _pesan(l),
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                          label: Text(
                              _jumlahItem() == 0
                                  ? 'Chat penjual'
                                  : 'Pesan lewat Chat · ${rupiah(_total(l))}',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _chatSaja(LapakModel l) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null) return;
    try {
      final chat = Get.find<ChatController>();
      final room = await chat.bukaAtauBuatRoom(
          otherUid: l.uid, otherNama: l.namaPemilik, otherFoto: l.fotoPemilik);
      await Get.to(() => ChatRoomView(
            roomId: room.id,
            otherUid: l.uid,
            namaLawan: room.namaLawan(me.uid),
            fotoLawan: room.fotoLawan(me.uid),
          ));
    } catch (e) {
      showSnack(false, '', 'Tidak dapat membuka obrolan: $e');
    }
  }

  Widget _baris(IconData ic, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5))),
        ]),
      );

  Widget _barisProduk(LapakModel l, int i, bool milik) {
    final p = l.produk[i];
    final q = _qty[i] ?? 0;
    return kartu(
      margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nama,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: p.habis ? TextDecoration.lineThrough : null)),
            if (p.ket.isNotEmpty)
              Text(p.ket,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text(p.harga > 0 ? rupiah(p.harga) : 'Tanya penjual',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800)),
          ]),
        ),
        if (p.habis)
          const Text('HABIS',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
        else if (!milik)
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (q > 0) ...[
              IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _qty[i] = q - 1),
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$q', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _qty[i] = q + 1),
                icon: Icon(Icons.add_circle, color: Colors.green.shade700)),
          ]),
      ]),
    );
  }

  Widget _penjual(LapakModel l, bool milik) {
    return kartu(
      child: InkWell(
        onTap: () => bukaProfil(l.uid, nama: l.namaPemilik),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: l.fotoPemilik.isNotEmpty ? ImageUtil.provider(l.fotoPemilik) : null,
            child: l.fotoPemilik.isEmpty ? Text(AppUtils.inisial(l.namaPemilik)) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Penjual', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              Text(l.namaPemilik, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          const Text('Lihat profil', style: TextStyle(fontSize: 12.5)),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

// ── Ulasan & bintang ──
class _Ulasan extends StatefulWidget {
  final LapakModel lapak;
  final bool milik;
  const _Ulasan({required this.lapak, required this.milik});

  @override
  State<_Ulasan> createState() => _UlasanState();
}

class _UlasanState extends State<_Ulasan> {
  int _bintang = 5;
  final _teks = TextEditingController();
  bool _kirim = false;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _kirim) return;
    setState(() => _kirim = true);
    final ref = FirebaseFirestore.instance.collection('lapak_umkm').doc(widget.lapak.id);
    final ulasan = ref.collection('ulasan').doc(me.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final lama = await tx.get(ulasan);
        final lamaBintang = lama.exists ? (lama.data()!['bintang'] ?? 0) as int : 0;
        tx.set(ulasan, {
          'uid': me.uid,
          'nama': me.nama,
          'bintang': _bintang,
          'teks': _teks.text.trim(),
          'at': Timestamp.now(),
        });
        tx.update(ref, {
          'rating_total': FieldValue.increment(_bintang - lamaBintang),
          'rating_jumlah': FieldValue.increment(lama.exists ? 0 : 1),
        });
      });
      _teks.clear();
      showSnack(true, 'Terima kasih, ulasan tersimpan.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan ulasan.');
    }
    if (mounted) setState(() => _kirim = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = Get.find<AuthController>().currentUser.value;
    final ref = FirebaseFirestore.instance
        .collection('lapak_umkm')
        .doc(widget.lapak.id)
        .collection('ulasan');
    return Column(children: [
      if (!widget.milik && me != null)
        kartu(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Beri ulasan (setelah membeli)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _bintang = i),
                  icon: Icon(i <= _bintang ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 30),
                ),
            ]),
            TextField(
              controller: _teks,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                  hintText: 'Ceritakan pengalaman Anda dengan jujur dan sopan.'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 42)),
              onPressed: _kirim ? null : _simpan,
              child: Text(_kirim ? 'Menyimpan...' : 'Kirim ulasan'),
            ),
          ]),
        ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('at', descending: true).limit(50).snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Belum ada ulasan.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return Column(children: [
            for (final d in docs)
              kartu(
                margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => bukaProfil('${d.data()['uid']}', nama: '${d.data()['nama']}'),
                        child: Text('${d.data()['nama'] ?? 'Warga'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    for (var i = 1; i <= 5; i++)
                      Icon(i <= ((d.data()['bintang'] ?? 0) as int) ? Icons.star : Icons.star_border,
                          size: 15, color: Colors.amber),
                  ]),
                  if ('${d.data()['teks'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${d.data()['teks']}', style: const TextStyle(fontSize: 13.5)),
                    ),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// LAPAK SAYA
// ─────────────────────────────────────────────────────────────
class LapakSayaView extends StatelessWidget {
  const LapakSayaView({super.key});

  Future<void> _hapus(LapakModel l) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Hapus lapak?'),
      content: Text('Lapak "${l.nama}" beserta daftar produknya akan dihapus permanen. Bila hanya libur, pakai tombol Tutup saja.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 42), backgroundColor: Colors.red.shade700),
            onPressed: () => Get.back(result: true),
            child: const Text('Hapus')),
      ],
    ));
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('lapak_umkm').doc(l.id).delete();
      showSnack(true, 'Lapak dihapus.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menghapus lapak.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Get.find<AuthController>().currentUser.value;
    final primary = AppTheme.primaryColor(me?.role ?? 'warga');
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Lapak Saya')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        onPressed: () async {
          if (me?.role == 'warga' && !await wajibVerifikasi()) return;
          Get.to(() => const LapakFormView());
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Lapak baru', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('lapak_umkm')
            .where('uid', isEqualTo: me?.uid ?? '-')
            .limit(30)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.error_outline,
                title: 'Tidak dapat memuat',
                subtitle: 'Periksa koneksi internet Anda.');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!.docs.map(LapakModel.dari).toList();
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Anda belum punya lapak',
                subtitle: 'Tekan "Lapak baru" untuk membuka usaha Anda di Talagasari Hub.');
          }
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            for (final l in list)
              kartu(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    onTap: () => Get.to(() => LapakDetailView(id: l.id)),
                    child: Row(children: [
                      Expanded(
                        child: Text(l.nama,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                  Text(l.namaJenis,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  if (l.status != 'aktif')
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          'Disembunyikan Admin${l.alasanAdmin.isEmpty ? '' : ': ${l.alasanAdmin}'}',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('${l.dilihat} dilihat',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text(l.bukaManual ? 'Terima pesanan' : 'Libur / tutup',
                        style: const TextStyle(fontSize: 12)),
                    Switch(
                      value: l.bukaManual,
                      onChanged: (v) => FirebaseFirestore.instance
                          .collection('lapak_umkm')
                          .doc(l.id)
                          .update({'buka_manual': v}).catchError(
                              (_) => showSnack(false, '', 'Gagal mengubah status.')),
                    ),
                  ]),
                  Row(children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => Get.to(() => LapakFormView(awal: l)),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40), foregroundColor: Colors.red.shade700),
                      onPressed: () => _hapus(l),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                  ]),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORM BUKA / UBAH LAPAK
// ─────────────────────────────────────────────────────────────
class LapakFormView extends StatefulWidget {
  final LapakModel? awal;
  const LapakFormView({super.key, this.awal});

  @override
  State<LapakFormView> createState() => _LapakFormViewState();
}

class _LapakFormViewState extends State<LapakFormView> {
  final _nama = TextEditingController();
  final _desk = TextEditingController();
  final _wa = TextEditingController();
  final _almt = AlamatDesaCtrl();
  String _kel = '';
  String _jenis = '';
  final Set<int> _hari = {1, 2, 3, 4, 5, 6};
  TimeOfDay _buka = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _tutup = const TimeOfDay(hour: 17, minute: 0);
  final Set<String> _layanan = {'ambil'};
  String _bentuk = 'menetap';
  final List<ProdukLapak> _produk = [];
  final List<TextEditingController> _pNama = [];
  final List<TextEditingController> _pHarga = [];
  final List<TextEditingController> _pKet = [];
  List<File> _fotoBaru = [];
  List<String> _fotoLama = [];
  bool _pakaiPeta = false;
  LatLng _titik = const LatLng(-6.239265, 106.530200);
  bool _simpan = false;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    final me = Get.find<AuthController>().currentUser.value;
    _wa.text = me?.nomorTelepon ?? '';
    if (a != null) {
      _nama.text = a.nama;
      _desk.text = a.deskripsi;
      _wa.text = a.whatsapp;
      _kel = a.kelompok;
      _jenis = a.jenis;
      _hari
        ..clear()
        ..addAll(a.hari);
      _buka = _parse(a.jamBuka);
      _tutup = _parse(a.jamTutup);
      _layanan
        ..clear()
        ..addAll(a.layanan);
      _bentuk = a.bentuk;
      _fotoLama = [...a.foto];
      _almt.isiDari(jalanTeks: a.alamat);
      if (a.punyaLokasi) {
        _pakaiPeta = true;
        _titik = LatLng(a.lat, a.lng);
      }
      for (final p in a.produk) {
        _tambahProduk(p);
      }
    } else {
      _tambahProduk(ProdukLapak());
    }
  }

  TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p.first) ?? 8, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _tambahProduk(ProdukLapak p) {
    _pNama.add(TextEditingController(text: p.nama));
    _pHarga.add(TextEditingController(text: p.harga > 0 ? '${p.harga}' : ''));
    _pKet.add(TextEditingController(text: p.ket));
    _produk.add(p);
  }

  @override
  void dispose() {
    _nama.dispose();
    _desk.dispose();
    _wa.dispose();
    _almt.dispose();
    for (final c in [..._pNama, ..._pHarga, ..._pKet]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _langkah(int n, String judul, String bantu) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryColor('warga'),
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(judul,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5))),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(bantu,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
          ),
        ]),
      );

  Future<void> _pilihJam(bool buka) async {
    final t = await showTimePicker(context: context, initialTime: buka ? _buka : _tutup);
    if (t != null) setState(() => buka ? _buka = t : _tutup = t);
  }

  Future<void> _kirim() async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _simpan) return;
    if (_kel.isEmpty || _jenis.isEmpty) {
      showSnack(false, '', 'Langkah 1: pilih kelompok dan jenis usaha dulu.');
      return;
    }
    if (_nama.text.trim().length < 3) {
      showSnack(false, '', 'Langkah 2: isi nama lapak (minimal 3 huruf).');
      return;
    }
    if (_desk.text.trim().length < 10) {
      showSnack(false, '', 'Langkah 2: jelaskan usaha Anda singkat (minimal 10 huruf).');
      return;
    }
    if (_fotoBaru.isEmpty && _fotoLama.isEmpty) {
      showSnack(false, '', 'Langkah 3: tambahkan minimal 1 foto agar pembeli percaya.');
      return;
    }
    final produk = <ProdukLapak>[];
    for (var i = 0; i < _produk.length; i++) {
      final n = _pNama[i].text.trim();
      if (n.isEmpty) continue;
      produk.add(ProdukLapak(
        nama: n,
        harga: int.tryParse(_pHarga[i].text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        ket: _pKet[i].text.trim(),
        habis: i < _produk.length ? _produk[i].habis : false,
      ));
    }
    if (_hari.isEmpty) {
      showSnack(false, '', 'Langkah 5: pilih minimal satu hari buka.');
      return;
    }
    if (_layanan.isEmpty) {
      showSnack(false, '', 'Langkah 5: pilih minimal satu cara layanan.');
      return;
    }
    final wa = _wa.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (wa.length < 9) {
      showSnack(false, '', 'Langkah 6: isi nomor WhatsApp yang benar.');
      return;
    }
    final g = _almt.galat();
    if (g != null) {
      showSnack(false, '', 'Langkah 7: $g');
      return;
    }
    setState(() => _simpan = true);
    try {
      final foto = [..._fotoLama];
      var gagalFoto = 0;
      for (final f in _fotoBaru) {
        final e = await ImageUtil.encode(f);
        if (e == null) {
          gagalFoto++;
        } else {
          foto.add(e);
        }
      }
      final data = <String, dynamic>{
        'uid': me.uid,
        'nama_pemilik': me.nama,
        'foto_pemilik': '',
        'nama': _nama.text.trim(),
        'kelompok': _kel,
        'jenis': _jenis,
        'deskripsi': _desk.text.trim(),
        'foto_list': foto,
        'alamat': _almt.teks,
        'lat': _pakaiPeta ? _titik.latitude : 0.0,
        'lng': _pakaiPeta ? _titik.longitude : 0.0,
        'hari': (_hari.toList()..sort()),
        'jam_buka': _fmt(_buka),
        'jam_tutup': _fmt(_tutup),
        'whatsapp': wa,
        'layanan': _layanan.toList(),
        'bentuk': _bentuk,
        'produk': produk.map((p) => p.toMap()).toList(),
        'updated_at': Timestamp.now(),
      };
      final col = FirebaseFirestore.instance.collection('lapak_umkm');
      if (widget.awal == null) {
        await col.add({
          ...data,
          'buka_manual': true,
          'status': 'aktif',
          'rating_total': 0,
          'rating_jumlah': 0,
          'dilihat': 0,
          'created_at': Timestamp.now(),
        });
      } else {
        await col.doc(widget.awal!.id).update(data);
      }
      Get.back();
      showSnack(
          true,
          gagalFoto > 0
              ? 'Lapak tersimpan, tetapi $gagalFoto foto terlalu besar dan dilewati.'
              : 'Lapak berhasil disimpan.',
          '');
    } catch (e) {
      setState(() => _simpan = false);
      showSnack(false, '', 'Gagal menyimpan lapak. Periksa koneksi dan aturan Firestore. ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    final kel = _kel.isEmpty ? null : kelompokDari(_kel);
    final jenis = kel == null ? null : jenisDari(_kel, _jenis);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(widget.awal == null ? 'Buka Lapak UMKM' : 'Ubah Lapak'),
        actions: [
          IconButton(
              tooltip: 'Panduan',
              icon: const Icon(Icons.help_outline),
              onPressed: () => Get.to(() => const PanduanLapakView())),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Text(
              'Isi 7 langkah di bawah. Tidak perlu terburu-buru: contoh akan muncul di setiap kolom. Lapak hanya untuk usaha di Desa Talagasari.',
              style: TextStyle(fontSize: 13, height: 1.4)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
          child: const Text(
              'Lapak untuk usaha yang MENJUAL BARANG atau makanan. Bila Anda menawarkan TENAGA/keahlian (tukang, bengkel, servis HP, salon, laundry, jahit, katering acara), pasang di tab "Cari Jasa".',
              style: TextStyle(fontSize: 12.5, height: 1.4)),
        ),
        _langkah(1, 'Pilih jenis usaha',
            'Pilih kelompok dulu, lalu jenis yang paling mirip dengan usaha Anda. Contoh: jualan nasi uduk → "Makanan & Minuman" → "Sarapan pagi".'),
        Wrap(spacing: 6, runSpacing: 0, children: [
          for (final k in kelompokLapak)
            ChoiceChip(
              avatar: Icon(k.ikon, size: 16, color: _kel == k.id ? Colors.white : k.warna),
              label: Text(k.label,
                  style: TextStyle(fontSize: 12, color: _kel == k.id ? Colors.white : null)),
              selected: _kel == k.id,
              selectedColor: k.warna,
              showCheckmark: false,
              onSelected: (_) => setState(() {
                _kel = k.id;
                _jenis = '';
              }),
            ),
        ]),
        if (kel != null) ...[
          const SizedBox(height: 8),
          Text(kel.ringkas,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          for (final j in kel.jenis)
            InkWell(
              onTap: () => setState(() => _jenis = j.id),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _jenis == j.id ? kel.warna.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _jenis == j.id ? kel.warna : Colors.grey.shade300,
                      width: _jenis == j.id ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(_jenis == j.id ? Icons.check_circle : Icons.circle_outlined,
                      color: kel.warna, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(j.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Contoh: ${j.contoh}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
        _langkah(2, 'Nama dan penjelasan usaha',
            'Tulis nama yang mudah diingat tetangga, lalu jelaskan singkat apa yang dijual dan keunggulannya.'),
        TextField(
          controller: _nama,
          maxLength: 50,
          decoration: InputDecoration(
              labelText: 'Nama lapak',
              hintText: 'Contoh: ${jenis?.contoh ?? 'Nasi Uduk Bu Ani'}'),
        ),
        TextField(
          controller: _desk,
          maxLines: 4,
          maxLength: 400,
          decoration: const InputDecoration(
              labelText: 'Penjelasan singkat',
              hintText:
                  'Contoh: Nasi uduk dengan lauk telur, tempe orek, dan sambal buatan sendiri. Buka tiap pagi di depan rumah.'),
        ),
        _langkah(3, 'Foto usaha',
            'Foto toko, makanan, atau dagangan. Foto pertama jadi sampul. Maksimal 3, otomatis dikecilkan.'),
        FotoPicker(
          maks: 3,
          label: 'Foto lapak (wajib minimal 1)',
          fotoLama: _fotoLama,
          onChanged: (baru, lama) {
            _fotoBaru = baru;
            _fotoLama = lama;
          },
        ),
        _langkah(4, 'Daftar produk dan harga',
            'Isi barang atau menu yang dijual. Harga boleh dikosongi bila berubah-ubah (pembeli akan diminta bertanya).'),
        if (jenis != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('Contoh isi: ${jenis.contohProduk}',
                style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        for (var i = 0; i < _produk.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pNama[i],
                    decoration: InputDecoration(
                        labelText: 'Produk ${i + 1}', hintText: 'Contoh: Nasi uduk + telur'),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus baris',
                  onPressed: _produk.length <= 1
                      ? null
                      : () => setState(() {
                            _pNama.removeAt(i).dispose();
                            _pHarga.removeAt(i).dispose();
                            _pKet.removeAt(i).dispose();
                            _produk.removeAt(i);
                          }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pHarga[i],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RibuanFormatter(),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Harga (Rp)', hintText: '12000', prefixText: 'Rp '),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pKet[i],
                    decoration: const InputDecoration(
                        labelText: 'Keterangan', hintText: 'per porsi / per kg'),
                  ),
                ),
              ]),
              Row(children: [
                Checkbox(
                  value: _produk[i].habis,
                  onChanged: (v) => setState(() => _produk[i].habis = v ?? false),
                ),
                const Text('Sedang habis', style: TextStyle(fontSize: 13)),
              ]),
            ]),
          ),
        if (_produk.length < 40)
          TextButton.icon(
            onPressed: () => setState(() => _tambahProduk(ProdukLapak())),
            icon: const Icon(Icons.add),
            label: const Text('Tambah produk'),
          ),
        _langkah(5, 'Jam buka dan cara layanan',
            'Pilih hari buka, jam, dan cara pembeli menerima barang.'),
        Wrap(spacing: 6, children: [
          for (var i = 0; i < 7; i++)
            FilterChip(
              label: Text(_namaHari[i], style: const TextStyle(fontSize: 12)),
              selected: _hari.contains(i + 1),
              onSelected: (v) => setState(() => v ? _hari.add(i + 1) : _hari.remove(i + 1)),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => _pilihJam(true),
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
              label: Text('Buka ${_fmt(_buka)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => _pilihJam(false),
              icon: const Icon(Icons.nightlight_outlined, size: 18),
              label: Text('Tutup ${_fmt(_tutup)}'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Bentuk usaha', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, children: [
          for (final e in _labelBentuk.entries)
            ChoiceChip(
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: _bentuk == e.key,
              onSelected: (_) => setState(() => _bentuk = e.key),
            ),
        ]),
        const SizedBox(height: 8),
        const Text('Cara layanan (boleh lebih dari satu)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, children: [
          for (final e in _labelLayanan.entries)
            FilterChip(
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: _layanan.contains(e.key),
              onSelected: (v) => setState(() => v ? _layanan.add(e.key) : _layanan.remove(e.key)),
            ),
        ]),
        _langkah(6, 'Nomor WhatsApp',
            'Dipakai pembeli untuk menghubungi Anda. Contoh: 081234567890.'),
        TextField(
          controller: _wa,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              labelText: 'Nomor WhatsApp', prefixIcon: Icon(Icons.phone_in_talk_outlined)),
        ),
        _langkah(7, 'Alamat usaha',
            'Alamat wajib di Desa Talagasari (desa, kecamatan, kabupaten terkunci). Tandai titik di peta bila mau (opsional).'),
        BlokAlamatDesa(c: _almt),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pakaiPeta,
          onChanged: (v) => setState(() => _pakaiPeta = v),
          title: const Text('Tandai lokasi di peta (opsional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
              'Tidak otomatis. Anda yang menentukan titiknya: ketuk peta, tombol Lokasi saya, atau Cari alamat.',
              style: TextStyle(fontSize: 12)),
        ),
        if (_pakaiPeta)
          PemilihPeta(
            titik: _titik,
            warna: kel?.warna ?? Colors.red,
            onChanged: (p) => _titik = p,
          ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52)),
          onPressed: _simpan ? null : _kirim,
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(_simpan ? 'Menyimpan...' : (widget.awal == null ? 'Buka lapak sekarang' : 'Simpan perubahan')),
        ),
        const SizedBox(height: 8),
        const Text(
            'Dengan membuka lapak, Anda setuju mengikuti Aturan Komunitas: usaha harus di Talagasari, jujur, dan tidak menjual barang terlarang.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADMIN: kelola lapak
// ─────────────────────────────────────────────────────────────
class LapakStaffTab extends StatelessWidget {
  const LapakStaffTab({super.key});

  Future<void> _ubahStatus(LapakModel l) async {
    final admin = Get.find<AuthController>().currentUser.value;
    if (admin == null || admin.role != 'admin') return;
    final sembunyi = l.status == 'aktif';
    final alasan = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(sembunyi ? 'Sembunyikan lapak?' : 'Tampilkan lagi?'),
      content: sembunyi
          ? TextField(
              controller: alasan,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Alasan (wajib)', hintText: 'Contoh: Berjualan di luar Talagasari.'),
            )
          : const Text('Lapak akan tampil lagi untuk warga.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
            onPressed: () {
              if (sembunyi && alasan.text.trim().length < 10) {
                showSnack(false, '', 'Alasan wajib (minimal 10 huruf).');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Ya')),
      ],
    ));
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('lapak_umkm').doc(l.id).update({
        'status': sembunyi ? 'disembunyikan' : 'aktif',
        'alasan_admin': sembunyi ? alasan.text.trim() : '',
      });
      try {
        await Get.find<NotificationController>().kirimKe(
          uidTujuan: l.uid,
          judul: sembunyi ? 'Lapak Anda disembunyikan' : 'Lapak Anda tampil kembali',
          isi: sembunyi ? '${l.nama}: ${alasan.text.trim()}' : l.nama,
          tipe: 'info',
        );
      } catch (_) {}
      showSnack(true, sembunyi ? 'Lapak disembunyikan.' : 'Lapak ditampilkan.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lapak_umkm')
          .orderBy('created_at', descending: true)
          .limit(150)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
              icon: Icons.error_outline,
              title: 'Tidak dapat memuat',
              subtitle: 'Periksa koneksi internet.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs.map(LapakModel.dari).toList();
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada lapak',
              subtitle: 'Lapak UMKM warga akan muncul di sini.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final l = list[i];
            return kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: () => Get.to(() => LapakDetailView(id: l.id)),
                  child: Text(l.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('${l.namaJenis} · oleh ${l.namaPemilik}',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                if (l.status != 'aktif')
                  Text('DISEMBUNYIKAN: ${l.alasanAdmin}',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => bukaProfil(l.uid, nama: l.namaPemilik),
                    child: const Text('Profil pemilik'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        backgroundColor:
                            l.status == 'aktif' ? Colors.red.shade700 : Colors.green.shade700),
                    onPressed: () => _ubahStatus(l),
                    child: Text(l.status == 'aktif' ? 'Sembunyikan' : 'Tampilkan',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}
