// ============================================================
// agenda_view.dart — AGENDA DESA TALAGASARI
//
// Fungsi: kalender kegiatan desa (rapat, kerja bakti, posyandu, pengajian,
// siskamling, bazar UMKM, layanan keliling, dll.). Perangkat desa membuat
// agenda; warga melihat, konfirmasi kehadiran (Hadir / Mungkin / Tidak),
// check-in saat acara, bertanya di kolom diskusi.
// Firestore saja (gratis). Foto base64.
// ============================================================
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/village_controller.dart' show notifPeran, AuditLog;
import '../core/core.dart';
import '../core/models.dart' show UserModel;
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'info_sosial.dart' show GaleriFoto;
import 'moderasi_view.dart';

// ─────────────────────────────────────────────────────────────
// KATEGORI + CONTOH
// ─────────────────────────────────────────────────────────────
class KatAgenda {
  final String id;
  final String label;
  final IconData ikon;
  final Color warna;
  final String ringkas;
  final String contohJudul;
  final String contohIsi;
  final String contohBawa;
  final int durasiJam;
  const KatAgenda(this.id, this.label, this.ikon, this.warna, this.ringkas,
      this.contohJudul, this.contohIsi, this.contohBawa, this.durasiJam);
}

const List<KatAgenda> kategoriAgenda = [
  KatAgenda('rapat', 'Rapat & Musyawarah', Icons.groups_2_outlined, Color(0xFF1565C0),
      'Rapat desa, musrenbang, rapat RT/RW.',
      'Musyawarah Rencana Pembangunan Desa',
      'Pembahasan rencana pembangunan desa tahun depan. Warga boleh menyampaikan usulan.',
      'Undangan atau KTP, alat tulis bila ingin mencatat.', 3),
  KatAgenda('gotong', 'Kerja Bakti / Gotong Royong', Icons.handyman_outlined, Color(0xFF6D4C41),
      'Bersih-bersih lingkungan, perbaikan jalan, saluran air.',
      'Kerja Bakti Bersih Selokan RW 05',
      'Membersihkan selokan sepanjang Jl. Kampung Baru agar tidak banjir saat hujan.',
      'Sarung tangan, cangkul/sapu, air minum sendiri.', 3),
  KatAgenda('posyandu', 'Posyandu & Kesehatan', Icons.medical_services_outlined, Color(0xFFD81B60),
      'Posyandu balita, lansia, imunisasi, cek kesehatan.',
      'Posyandu Balita dan Ibu Hamil',
      'Penimbangan balita, imunisasi, dan pemeriksaan ibu hamil oleh bidan desa.',
      'Buku KIA / buku kesehatan anak dan kartu keluarga.', 3),
  KatAgenda('keagamaan', 'Keagamaan', Icons.mosque_outlined, Color(0xFF2E7D32),
      'Pengajian, peringatan hari besar, doa bersama.',
      'Pengajian Akbar Maulid Nabi',
      'Pengajian bersama dan doa untuk keselamatan desa. Terbuka untuk umum.',
      'Pakaian sopan dan alas duduk bila perlu.', 3),
  KatAgenda('pendidikan', 'Pelatihan & Penyuluhan', Icons.school_outlined, Color(0xFF00897B),
      'Pelatihan usaha, penyuluhan tani, sosialisasi.',
      'Pelatihan Usaha Kecil: Cara Memotret Produk',
      'Pelatihan gratis untuk pelaku UMKM desa agar produk lebih menarik dijual online.',
      'HP yang dibawa sendiri dan contoh produk.', 4),
  KatAgenda('olahraga', 'Olahraga, Seni & Budaya', Icons.sports_soccer_outlined, Color(0xFFF57C00),
      'Turnamen, senam, pentas seni, lomba.',
      'Turnamen Voli Antar-RW',
      'Turnamen voli memperingati HUT RI. Pendaftaran tim lewat ketua RW.',
      'Pakaian olahraga, tim mendaftar lewat RW.', 5),
  KatAgenda('keamanan', 'Keamanan & Siskamling', Icons.shield_outlined, Color(0xFF37474F),
      'Ronda malam, patroli, koordinasi keamanan.',
      'Jadwal Ronda Malam RW 03',
      'Giliran ronda malam bapak-bapak RW 03. Cek jadwal giliran di lokasi pos ronda.',
      'Senter, jaket, dan kopi sendiri.', 8),
  KatAgenda('ekonomi', 'Pasar, Bazar & UMKM', Icons.storefront_outlined, Color(0xFFAD1457),
      'Bazar, pasar kaget, pameran produk desa.',
      'Bazar UMKM Talagasari',
      'Bazar produk warga: makanan, fashion, kerajinan. Pelaku UMKM boleh membuka stan.',
      'Produk dagangan dan meja bila punya.', 6),
  KatAgenda('layanan', 'Layanan Keliling & Administrasi', Icons.badge_outlined, Color(0xFF5E35B1),
      'Layanan KTP/KK keliling, pajak, bantuan hukum.',
      'Layanan KTP dan KK Keliling',
      'Petugas Dukcapil melayani perekaman KTP dan pengurusan KK di balai desa.',
      'Fotokopi KK dan surat pengantar RT.', 4),
  KatAgenda('sosial', 'Bantuan & Kegiatan Sosial', Icons.volunteer_activism_outlined, Color(0xFFE65100),
      'Pembagian sembako, santunan, donor darah.',
      'Pembagian Sembako Warga Kurang Mampu',
      'Pembagian sembako untuk warga terdaftar. Bawa kartu atau surat dari RT.',
      'KTP dan kartu penerima.', 3),
  KatAgenda('lainnya', 'Kegiatan Lain', Icons.event_outlined, Color(0xFF546E7A),
      'Kegiatan desa yang belum cocok di kelompok lain.',
      'Kegiatan Desa',
      'Tulis penjelasan kegiatan Anda di sini.',
      '', 2),
];

KatAgenda katAgenda(String id) =>
    kategoriAgenda.firstWhere((k) => k.id == id, orElse: () => kategoriAgenda.last);

const List<String> _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const Map<String, String> _labelUlang = {
  '': 'Sekali saja',
  'mingguan': 'Rutin tiap minggu',
  'bulanan': 'Rutin tiap bulan',
};

String _tgl(DateTime t) => DateFormat('EEEE, d MMMM yyyy', 'id').format(t);
String _jam(DateTime t) => DateFormat('HH.mm').format(t);

bool _samaHari(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Apakah agenda berlangsung pada hari tertentu?
bool adaDiHari(AgendaModel a, DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final mulai = DateTime(a.waktu.year, a.waktu.month, a.waktu.day);
  if (a.rutin) {
    if (d.isBefore(mulai)) return false;
    return a.ulang == 'mingguan' ? d.weekday == a.waktu.weekday : d.day == a.waktu.day;
  }
  final akhir = DateTime(a.akhir.year, a.akhir.month, a.akhir.day);
  return !d.isBefore(mulai) && !d.isAfter(akhir);
}

// ─────────────────────────────────────────────────────────────
// PANDUAN
// ─────────────────────────────────────────────────────────────
class PanduanAgendaView extends StatelessWidget {
  const PanduanAgendaView({super.key});

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
      appBar: AppBar(backgroundColor: primary, title: const Text('Panduan Agenda Desa')),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        _j('Apa itu Agenda Desa?'),
        _p('Agenda Desa adalah kalender resmi kegiatan Desa Talagasari. Semua kegiatan yang diadakan desa, RT/RW, posyandu, dan kelompok warga dicatat di sini supaya Anda tidak ketinggalan dan tahu kapan, di mana, serta apa yang harus dibawa.'),
        _j('Untuk apa saja?'),
        _kotak('Contoh nyata', [
          '• Kerja bakti: lihat tanggal, lokasi, dan apa yang perlu dibawa (sapu, cangkul).',
          '• Posyandu: tahu jadwal tiap bulan dan syarat membawa buku KIA.',
          '• Layanan KTP keliling: tahu tanggalnya dan berkas yang disiapkan.',
          '• Bazar UMKM: warga yang berjualan tahu jadwal untuk membuka stan.',
          '• Ronda malam: tahu giliran per RW.',
        ], Colors.green.shade700),
        _j('Cara memakai (untuk warga)'),
        _p('1. Buka Beranda → menu "Agenda Desa".\n'
            '2. Lihat tab "Akan datang" untuk kegiatan terdekat, atau tab "Kalender" untuk melihat per tanggal.\n'
            '3. Ketuk kegiatan untuk melihat waktu, lokasi, peta, dan yang perlu dibawa.\n'
            '4. Tekan Hadir, Mungkin, atau Tidak supaya panitia tahu perkiraan jumlah peserta.\n'
            '5. Saat acara berlangsung, tekan "Saya sudah hadir" (check-in).\n'
            '6. Ada pertanyaan? Tulis di kolom diskusi di bawah kegiatan.'),
        _j('Arti tanda-tanda'),
        _kotak('Label di kartu agenda', [
          '• SEDANG BERLANGSUNG = acara sedang jalan sekarang.',
          '• WAJIB = diharapkan semua warga sasaran hadir.',
          '• RUTIN = terjadi berulang (tiap minggu atau bulan), tidak perlu konfirmasi.',
          '• PENUH = kuota peserta sudah habis.',
          '• DIBATALKAN = kegiatan tidak jadi; alasan tertulis di dalamnya.',
          '• Sasaran: "Khusus RW 05" artinya hanya warga RW itu yang diundang.',
        ], Colors.blue.shade700),
        _j('Untuk perangkat desa'),
        _p('Tekan tombol "Buat Agenda". Pilih jenis kegiatan lalu tekan "Pakai contoh" agar judul, penjelasan, dan barang bawaan terisi otomatis, kemudian ubah sesuai kebutuhan. Warga otomatis mendapat pemberitahuan. Bila kegiatan batal, tekan "Batalkan" dan tulis alasan; warga yang sudah konfirmasi diberi tahu.'),
        _j('Beda dengan fitur lain'),
        _kotak('Agenda, Info, dan Suara Warga', [
          '• Agenda = KAPAN dan DI MANA kegiatan (ada tanggal, ada konfirmasi hadir).',
          '• Info Beranda = berita atau pengumuman (tidak berjadwal).',
          '• Suara Warga = meminta pendapat warga sebelum diputuskan.',
        ], Colors.orange.shade800),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DAFTAR AGENDA
// ─────────────────────────────────────────────────────────────
class AgendaListView extends StatefulWidget {
  const AgendaListView({super.key});

  @override
  State<AgendaListView> createState() => _AgendaListViewState();
}

class _AgendaListViewState extends State<AgendaListView> {
  final db = FirebaseFirestore.instance;
  int _tab = 0; // 0 akan datang, 1 kalender, 2 rutin, 3 selesai
  String _kat = 'semua';
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _dipilih = DateTime.now();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      db.collection('agenda').orderBy('waktu', descending: true).limit(300).snapshots();

  bool get _staf => Get.find<AuthController>().isStaff;

  Widget _tabBtn(int i, String t) => ChoiceChip(
        label: Text(t, style: const TextStyle(fontSize: 12.5)),
        selected: _tab == i,
        onSelected: (_) => setState(() => _tab = i),
      );

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text('Agenda Desa'),
        actions: [
          IconButton(
              tooltip: 'Panduan',
              icon: const Icon(Icons.help_outline),
              onPressed: () => Get.to(() => const PanduanAgendaView())),
        ],
      ),
      floatingActionButton: _staf
          ? FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: () => Get.to(() => const AgendaFormView()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Buat Agenda', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.error_outline,
                title: 'Agenda tidak dapat dimuat',
                subtitle: 'Periksa koneksi internet Anda.');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          var semua = snap.data!.docs.map(AgendaModel.fromFirestore).toList();
          if (_kat != 'semua') semua = semua.where((a) => a.kategori == _kat).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
            _kotakPenjelasan(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Wrap(spacing: 8, children: [
                _tabBtn(0, 'Akan datang'),
                _tabBtn(1, 'Kalender'),
                _tabBtn(2, 'Rutin'),
                _tabBtn(3, 'Selesai'),
              ]),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _chipKat('semua', 'Semua', Icons.apps, primary),
                  for (final k in kategoriAgenda) _chipKat(k.id, k.label, k.ikon, k.warna),
                ],
              ),
            ),
            ..._isi(semua),
          ]);
        },
      ),
    );
  }

  Widget _chipKat(String id, String label, IconData ik, Color c) {
    final sel = _kat == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: ChoiceChip(
        avatar: Icon(ik, size: 16, color: sel ? Colors.white : c),
        label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
        selected: sel,
        selectedColor: c,
        showCheckmark: false,
        onSelected: (_) => setState(() => _kat = id),
      ),
    );
  }

  Widget _kotakPenjelasan() => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade100)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.lightbulb_outline, color: Colors.green.shade800),
            title: const Text('Agenda Desa itu apa? Baca di sini',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Kalender kegiatan resmi Desa Talagasari: kerja bakti, posyandu, pengajian, layanan KTP keliling, bazar, dan lainnya. Anda bisa melihat waktu dan lokasi, memberi tahu panitia bahwa Anda akan hadir, dan bertanya langsung.',
                  style: TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 8),
              const Text('Contoh:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Text(
                  '• Ada kerja bakti Minggu pagi? Lihat jam, lokasi, dan barang yang dibawa, lalu tekan "Hadir".\n'
                  '• Anak imunisasi? Cari "Posyandu" untuk jadwal tiap bulan.\n'
                  '• Mau urus KTP? Cek kapan "Layanan Keliling" datang.',
                  style: TextStyle(fontSize: 13, height: 1.45)),
              TextButton(
                  onPressed: () => Get.to(() => const PanduanAgendaView()),
                  child: const Text('Panduan lengkap')),
            ],
          ),
        ),
      );

  List<Widget> _isi(List<AgendaModel> semua) {
    if (_tab == 1) return _kalender(semua);
    List<AgendaModel> list;
    String kosong;
    if (_tab == 0) {
      list = semua.where((a) => !a.rutin && !a.lewat).toList()
        ..sort((a, b) => a.waktu.compareTo(b.waktu));
      kosong = 'Belum ada agenda yang akan datang.';
    } else if (_tab == 2) {
      list = semua.where((a) => a.rutin).toList()..sort((a, b) => a.berikutnya.compareTo(b.berikutnya));
      kosong = 'Belum ada kegiatan rutin.';
    } else {
      list = semua.where((a) => a.lewat).toList()..sort((a, b) => b.waktu.compareTo(a.waktu));
      kosong = 'Belum ada agenda yang selesai.';
    }
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: EmptyState(
              icon: Icons.event_busy_outlined, title: kosong, subtitle: 'Kegiatan desa akan muncul di sini.'),
        )
      ];
    }
    if (_tab != 0) return [for (final a in list) KartuAgenda(a: a)];
    // kelompok waktu
    final now = DateTime.now();
    final hariIni = list.where((a) => a.berlangsung || _samaHari(a.waktu, now)).toList();
    final minggu = list
        .where((a) => !hariIni.contains(a) && a.waktu.difference(now).inDays < 7)
        .toList();
    final nanti = list.where((a) => !hariIni.contains(a) && !minggu.contains(a)).toList();
    Widget judul(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)));
    return [
      if (hariIni.isNotEmpty) judul('Hari ini'),
      for (final a in hariIni) KartuAgenda(a: a),
      if (minggu.isNotEmpty) judul('Minggu ini'),
      for (final a in minggu) KartuAgenda(a: a),
      if (nanti.isNotEmpty) judul('Berikutnya'),
      for (final a in nanti) KartuAgenda(a: a),
    ];
  }

  List<Widget> _kalender(List<AgendaModel> semua) {
    final awal = DateTime(_bulan.year, _bulan.month, 1);
    final jmlHari = DateTime(_bulan.year, _bulan.month + 1, 0).day;
    final offset = awal.weekday - 1; // Senin = 0
    final sel = <Widget>[];
    for (var i = 0; i < offset; i++) {
      sel.add(const SizedBox());
    }
    for (var d = 1; d <= jmlHari; d++) {
      final tgl = DateTime(_bulan.year, _bulan.month, d);
      final ada = semua.where((a) => !a.batal && adaDiHari(a, tgl)).toList();
      final pilih = _samaHari(tgl, _dipilih);
      final hariIni = _samaHari(tgl, DateTime.now());
      sel.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _dipilih = tgl),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: pilih ? Colors.green.shade700 : (hariIni ? Colors.green.shade50 : null),
            borderRadius: BorderRadius.circular(10),
            border: hariIni && !pilih ? Border.all(color: Colors.green.shade700) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$d',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: pilih ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            if (ada.isEmpty)
              const SizedBox(height: 6)
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final a in ada.take(3))
                  Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                          color: pilih ? Colors.white : katAgenda(a.kategori).warna,
                          shape: BoxShape.circle)),
              ]),
          ]),
        ),
      ));
    }
    final hariPilih = semua.where((a) => adaDiHari(a, _dipilih)).toList()
      ..sort((a, b) => a.waktu.hour.compareTo(b.waktu.hour));
    return [
      kartu(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(children: [
          Row(children: [
            IconButton(
                onPressed: () => setState(() => _bulan = DateTime(_bulan.year, _bulan.month - 1)),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(DateFormat('MMMM yyyy', 'id').format(_bulan),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
            ),
            IconButton(
                onPressed: () => setState(() => _bulan = DateTime(_bulan.year, _bulan.month + 1)),
                icon: const Icon(Icons.chevron_right)),
          ]),
          Row(children: [
            for (final h in _hari)
              Expanded(
                  child: Center(
                      child: Text(h,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)))),
          ]),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: sel,
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(_tgl(_dipilih), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      if (hariPilih.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
              child: Text('Tidak ada kegiatan di tanggal ini.',
                  style: TextStyle(color: AppTheme.textSecondary))),
        ),
      for (final a in hariPilih) KartuAgenda(a: a),
    ];
  }
}

class KartuAgenda extends StatelessWidget {
  final AgendaModel a;
  const KartuAgenda({super.key, required this.a});

  Widget _lencana(String t, Color c) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
        child: Text(t,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    final k = katAgenda(a.kategori);
    final w = a.berikutnya;
    final penuh = a.kuota > 0 && a.hadir >= a.kuota;
    return InkWell(
      onTap: () => Get.to(() => AgendaDetailView(id: a.id)),
      child: kartu(
        padding: const EdgeInsets.all(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                color: a.batal ? Colors.grey.shade300 : k.warna.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(DateFormat('MMM', 'id').format(w).toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: k.warna)),
              Text('${w.day}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: k.warna)),
              Text(DateFormat('E', 'id').format(w),
                  style: TextStyle(fontSize: 10.5, color: k.warna)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(runSpacing: 3, children: [
                if (a.batal) _lencana('DIBATALKAN', Colors.red.shade700),
                if (a.berlangsung) _lencana('SEDANG BERLANGSUNG', Colors.green.shade700),
                if (a.wajib) _lencana('WAJIB', Colors.orange.shade800),
                if (a.rutin) _lencana('RUTIN', Colors.blue.shade700),
                if (penuh && !a.rutin) _lencana('PENUH', Colors.grey.shade700),
              ]),
              Text(a.judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration: a.batal ? TextDecoration.lineThrough : null)),
              Text(k.label,
                  style: TextStyle(fontSize: 11.5, color: k.warna, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('${_jam(w)} – ${_jam(a.akhir.isAfter(a.waktu) ? w.add(a.akhir.difference(a.waktu)) : w)}',
                    style: const TextStyle(fontSize: 12)),
                if (a.rutin) Text('  · ${_labelUlang[a.ulang]}', style: const TextStyle(fontSize: 12)),
              ]),
              if (a.lokasi.isNotEmpty)
                Row(children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(a.lokasi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                ]),
              if (!a.rutin && a.hadir > 0)
                Text('${a.hadir} warga akan hadir',
                    style: TextStyle(fontSize: 11.5, color: Colors.green.shade800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DETAIL AGENDA
// ─────────────────────────────────────────────────────────────
class AgendaDetailView extends StatefulWidget {
  final String id;
  const AgendaDetailView({super.key, required this.id});

  @override
  State<AgendaDetailView> createState() => _AgendaDetailViewState();
}

class _AgendaDetailViewState extends State<AgendaDetailView> {
  final db = FirebaseFirestore.instance;
  final _komen = TextEditingController();
  bool _proses = false;

  DocumentReference<Map<String, dynamic>> get _ref => db.collection('agenda').doc(widget.id);

  @override
  void dispose() {
    _komen.dispose();
    super.dispose();
  }

  Future<void> _rsvp(AgendaModel a, String? lama, String baru) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _proses || lama == baru) return;
    if (baru == 'hadir' && a.kuota > 0 && a.hadir >= a.kuota && lama != 'hadir') {
      showSnack(false, '', 'Kuota peserta sudah penuh.');
      return;
    }
    setState(() => _proses = true);
    try {
      final b = db.batch();
      b.set(_ref.collection('hadir').doc(me.uid), {
        'uid': me.uid,
        'nama': me.nama,
        'rw': me.alamatRw,
        'status': baru,
        'at': Timestamp.now(),
      }, SetOptions(merge: true));
      b.update(_ref, {
        if (lama != null) 'rsvp_$lama': FieldValue.increment(-1),
        'rsvp_$baru': FieldValue.increment(1),
      });
      await b.commit();
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan konfirmasi. Periksa koneksi internet.');
    }
    if (mounted) setState(() => _proses = false);
  }

  Future<void> _checkin(AgendaModel a, Map<String, dynamic>? saya) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _proses) return;
    setState(() => _proses = true);
    try {
      final lama = saya?['status'] as String?;
      final b = db.batch();
      b.set(_ref.collection('hadir').doc(me.uid), {
        'uid': me.uid,
        'nama': me.nama,
        'rw': me.alamatRw,
        'status': 'hadir',
        'checkin': true,
        'checkin_at': Timestamp.now(),
        'at': Timestamp.now(),
      }, SetOptions(merge: true));
      b.update(_ref, {
        'rsvp_checkin': FieldValue.increment(1),
        if (lama != 'hadir') 'rsvp_hadir': FieldValue.increment(1),
        if (lama != null && lama != 'hadir') 'rsvp_$lama': FieldValue.increment(-1),
      });
      await b.commit();
      showSnack(true, 'Kehadiran Anda tercatat. Terima kasih sudah datang!', '');
    } catch (_) {
      showSnack(false, '', 'Gagal mencatat kehadiran.');
    }
    if (mounted) setState(() => _proses = false);
  }

  Future<void> _batalkan(AgendaModel a) async {
    final ctrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Batalkan agenda?'),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
            labelText: 'Alasan (wajib, dibaca warga)', hintText: 'Contoh: Turun hujan deras, diundur minggu depan.'),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Kembali')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 42), backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (ctrl.text.trim().length < 10) {
                showSnack(false, '', 'Alasan wajib diisi (minimal 10 huruf).');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Batalkan')),
      ],
    ));
    if (ok != true) return;
    try {
      await _ref.update({'batal': true, 'alasan_batal': ctrl.text.trim()});
      await AuditLog.catat(aksi: 'Membatalkan agenda', targetTipe: 'agenda', targetId: a.id, detail: a.judul);
      // beri tahu yang sudah konfirmasi
      final h = await _ref.collection('hadir').limit(150).get();
      for (final d in h.docs) {
        final st = d.data()['status'];
        if (st == 'hadir' || st == 'mungkin') {
          try {
            await Get.find<NotificationController>().kirimKe(
              uidTujuan: '${d.data()['uid']}',
              judul: 'Agenda dibatalkan',
              isi: '${a.judul}: ${ctrl.text.trim()}',
              tipe: 'agenda',
            );
          } catch (_) {}
        }
      }
      showSnack(true, 'Agenda dibatalkan dan peserta diberi tahu.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal membatalkan agenda.');
    }
  }

  Future<void> _hapus(AgendaModel a) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Hapus agenda?'),
      content: const Text('Agenda dan data konfirmasi dihapus permanen. Bila kegiatan batal, pakai tombol Batalkan agar warga tahu.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Kembali')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 42), backgroundColor: Colors.red.shade700),
            onPressed: () => Get.back(result: true),
            child: const Text('Hapus')),
      ],
    ));
    if (ok != true) return;
    try {
      await _ref.delete();
      await AuditLog.catat(aksi: 'Menghapus agenda', targetTipe: 'agenda', targetId: a.id, detail: a.judul);
      Get.back();
      showSnack(true, 'Agenda dihapus.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menghapus agenda.');
    }
  }

  void _lihatPeserta() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ref.collection('hadir').limit(300).snapshots(),
          builder: (_, s) {
            final docs = s.data?.docs ?? const [];
            final h = docs.where((d) => d.data()['status'] == 'hadir').toList();
            final m = docs.where((d) => d.data()['status'] == 'mungkin').toList();
            Widget grup(String t, List<QueryDocumentSnapshot<Map<String, dynamic>>> l) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('$t (${l.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
                    for (final d in l)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text('${d.data()['nama'] ?? 'Warga'}'),
                        subtitle: Text(
                            'RW ${d.data()['rw'] ?? '-'}${d.data()['checkin'] == true ? ' · sudah check-in ✓' : ''}'),
                        onTap: () => bukaProfil('${d.data()['uid']}', nama: '${d.data()['nama']}'),
                      ),
                  ],
                );
            return ListView(children: [
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Daftar peserta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              grup('Akan hadir', h),
              grup('Mungkin hadir', m),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _wa(AgendaModel a) async {
    var n = a.kontak.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = '62${n.substring(1)}';
    if (n.length < 9) return;
    await bukaUri(Uri.parse(
        'https://wa.me/$n?text=${Uri.encodeComponent('Halo, saya mau bertanya soal agenda "${a.judul}" di Talagasari Hub.')}'));
  }

  void _bagikan(AgendaModel a) {
    final t =
        '*${a.judul}*\n${_tgl(a.berikutnya)}, pukul ${_jam(a.berikutnya)}\nLokasi: ${a.lokasi}\n\n${a.deskripsi}\n\n— Agenda Desa Talagasari (Talagasari Hub)';
    Clipboard.setData(ClipboardData(text: t));
    showSnack(true, 'Teks agenda disalin. Tempel di WhatsApp untuk mengajak tetangga.', '');
  }

  Future<void> _kirimKomen() async {
    final me = Get.find<AuthController>().currentUser.value;
    final t = _komen.text.trim();
    if (me == null || t.isEmpty) return;
    try {
      await _ref.collection('komentar').add({
        'uid': me.uid,
        'nama': me.nama,
        'role': me.role,
        'isi': t.length > 300 ? t.substring(0, 300) : t,
        'at': Timestamp.now(),
      });
      _komen.clear();
    } catch (_) {
      showSnack(false, '', 'Gagal mengirim pertanyaan.');
    }
  }

  Widget _baris(IconData ic, String l, String v, {Color? warna}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 19, color: warna ?? AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
              width: 92,
              child: Text(l, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
        ]),
      );

  String _labelSasaran(String s) {
    if (s == 'semua') return 'Seluruh warga Talagasari';
    if (s.startsWith('rw:')) return 'Khusus warga RW ${s.substring(3)}';
    if (s.startsWith('dusun:')) return 'Khusus warga Kp. ${s.substring(6)}';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final me = auth.currentUser.value;
    final staf = auth.isStaff;
    final primary = AppTheme.primaryColor(auth.role);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(backgroundColor: primary), body: const Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) {
          return Scaffold(
              appBar: AppBar(backgroundColor: primary),
              body: const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Agenda tidak ditemukan',
                  subtitle: 'Agenda ini sudah dihapus.'));
        }
        final a = AgendaModel.fromFirestore(snap.data!);
        final k = katAgenda(a.kategori);
        final w = a.berikutnya;
        final dur = a.akhir.difference(a.waktu);
        final penuh = a.kuota > 0 && a.hadir >= a.kuota;
        final bisaCheckin = !a.batal &&
            DateTime.now().isAfter(w.subtract(const Duration(hours: 1))) &&
            DateTime.now().isBefore(w.add(dur));
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: primary,
            title: Text(k.label),
            actions: [
              IconButton(tooltip: 'Bagikan', icon: const Icon(Icons.share_outlined), onPressed: () => _bagikan(a)),
              if (staf)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'ubah') Get.to(() => AgendaFormView(awal: a));
                    if (v == 'peserta') _lihatPeserta();
                    if (v == 'batal') _batalkan(a);
                    if (v == 'hapus') _hapus(a);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'ubah', child: Text('Ubah agenda')),
                    const PopupMenuItem(value: 'peserta', child: Text('Lihat peserta')),
                    if (!a.batal) const PopupMenuItem(value: 'batal', child: Text('Batalkan agenda')),
                    const PopupMenuItem(value: 'hapus', child: Text('Hapus agenda')),
                  ],
                ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            if (a.batal)
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(12),
                child: Text('AGENDA DIBATALKAN. ${a.alasanBatal}',
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600)),
              ),
            if (a.semuaFoto.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: GaleriFoto(foto: a.semuaFoto)),
            kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, children: [
                  Chip(
                      avatar: Icon(k.ikon, size: 16, color: k.warna),
                      label: Text(k.label, style: const TextStyle(fontSize: 11.5)),
                      visualDensity: VisualDensity.compact),
                  if (a.wajib)
                    Chip(
                        label: const Text('WAJIB HADIR', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.orange.shade800,
                        visualDensity: VisualDensity.compact),
                  if (a.berlangsung)
                    Chip(
                        label: const Text('SEDANG BERLANGSUNG', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: Colors.green.shade700,
                        visualDensity: VisualDensity.compact),
                ]),
                Text(a.judul, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _baris(Icons.event, 'Tanggal', _tgl(w)),
                _baris(Icons.schedule, 'Pukul', '${_jam(w)} – ${_jam(w.add(dur))} WIB'),
                if (a.rutin) _baris(Icons.repeat, 'Berulang', _labelUlang[a.ulang] ?? ''),
                _baris(Icons.place_outlined, 'Lokasi', a.lokasi.isEmpty ? '-' : a.lokasi),
                if (a.penyelenggara.isNotEmpty) _baris(Icons.account_balance_outlined, 'Penyelenggara', a.penyelenggara),
                _baris(Icons.groups_outlined, 'Sasaran', _labelSasaran(a.sasaran)),
                if (a.kuota > 0) _baris(Icons.event_seat_outlined, 'Kuota', '${a.hadir} / ${a.kuota} peserta'),
                if (a.bawa.isNotEmpty) _baris(Icons.backpack_outlined, 'Yang dibawa', a.bawa, warna: Colors.orange.shade800),
                if (a.kontak.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => _wa(a),
                      icon: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFF25D366)),
                      label: const Text('Tanya panitia lewat WhatsApp'),
                    ),
                  ),
                if (a.deskripsi.isNotEmpty) ...[
                  const Divider(height: 22),
                  Text(a.deskripsi, style: const TextStyle(fontSize: 14.5, height: 1.5)),
                ],
              ]),
            ),
            if (a.punyaLokasi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PetaDenganLokasi(
                    pusat: LatLng(a.lat, a.lng),
                    tinggi: 180,
                    penanda: [
                      Marker(
                        point: LatLng(a.lat, a.lng),
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on, size: 40, color: k.warna),
                      ),
                    ],
                  ),
                ),
              ),
            if (!a.batal) _panelRsvp(a, me, penuh, bisaCheckin),
            if (staf && !a.rutin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _lihatPeserta,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: Text('Daftar peserta (${a.hadir} hadir, ${a.mungkin} mungkin, ${a.checkin} check-in)'),
                ),
              ),
            const SectionTitle('Tanya & diskusi'),
            _diskusi(me, staf),
          ]),
        );
      },
    );
  }

  Widget _panelRsvp(AgendaModel a, UserModel? me, bool penuh, bool bisaCheckin) {
    if (a.rutin) {
      return kartu(
        child: const Text(
            'Kegiatan rutin: datang saja sesuai jadwal, tidak perlu konfirmasi.',
            style: TextStyle(fontSize: 13)),
      );
    }
    if (a.lewat) {
      return kartu(
        child: Text('Kegiatan sudah selesai. ${a.checkin} warga tercatat hadir.',
            style: const TextStyle(fontSize: 13)),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.collection('hadir').doc(me?.uid ?? '-').snapshots(),
      builder: (_, s) {
        final saya = s.data?.data();
        final st = saya?['status'] as String?;
        Widget tombol(String id, String label, IconData ic, Color c, int jumlah) {
          final aktif = st == id;
          return Expanded(
            child: InkWell(
              onTap: _proses ? null : () => _rsvp(a, st, id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: aktif ? c : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c, width: aktif ? 2 : 1),
                ),
                child: Column(children: [
                  Icon(ic, color: aktif ? Colors.white : c),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold, color: aktif ? Colors.white : c)),
                  Text('$jumlah',
                      style: TextStyle(fontSize: 11, color: aktif ? Colors.white70 : AppTheme.textSecondary)),
                ]),
              ),
            ),
          );
        }

        return kartu(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Apakah Anda akan hadir?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('Jawaban Anda membantu panitia menyiapkan acara.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              tombol('hadir', 'Hadir', Icons.check_circle_outline, Colors.green.shade700, a.hadir),
              tombol('mungkin', 'Mungkin', Icons.help_outline, Colors.orange.shade800, a.mungkin),
              tombol('tidak', 'Tidak', Icons.cancel_outlined, Colors.red.shade700, a.tidak),
            ]),
            if (penuh && st != 'hadir')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Kuota penuh. Anda masih bisa memilih "Mungkin".',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
            if (a.kuota > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                    value: (a.hadir / a.kuota).clamp(0.0, 1.0), minHeight: 6, borderRadius: BorderRadius.circular(3)),
              ),
            const SizedBox(height: 10),
            if (saya?['checkin'] == true)
              Row(children: [
                Icon(Icons.verified, color: Colors.green.shade700),
                const SizedBox(width: 6),
                const Expanded(child: Text('Kehadiran Anda sudah tercatat. Terima kasih!')),
              ])
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: bisaCheckin && !_proses ? () => _checkin(a, saya) : null,
                icon: const Icon(Icons.how_to_reg_outlined, color: Colors.white),
                label: Text(bisaCheckin ? 'Saya sudah hadir (check-in)' : 'Check-in dibuka 1 jam sebelum acara'),
              ),
          ]),
        );
      },
    );
  }

  Widget _diskusi(UserModel? me, bool staf) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _komen,
              maxLength: 300,
              decoration: const InputDecoration(
                  counterText: '', hintText: 'Tulis pertanyaan, misal: "Anak-anak boleh ikut?"'),
            ),
          ),
          IconButton(onPressed: _kirimKomen, icon: Icon(Icons.send, color: Colors.green.shade700)),
        ]),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ref.collection('komentar').orderBy('at', descending: true).limit(60).snapshots(),
        builder: (_, s) {
          final docs = s.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Belum ada pertanyaan.', style: TextStyle(color: AppTheme.textSecondary)));
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
                        child: Text(
                            '${d.data()['nama'] ?? 'Warga'}${d.data()['role'] != null && d.data()['role'] != 'warga' ? ' · ${AppTheme.labelRole('${d.data()['role']}')}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    if (staf || d.data()['uid'] == me?.uid)
                      InkWell(
                          onTap: () => d.reference.delete().catchError((_) {}),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                  ]),
                  Text('${d.data()['isi'] ?? ''}', style: const TextStyle(fontSize: 13.5)),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// FORM BUAT / UBAH AGENDA (perangkat desa)
// ─────────────────────────────────────────────────────────────
class AgendaFormView extends StatefulWidget {
  final AgendaModel? awal;
  const AgendaFormView({super.key, this.awal});

  @override
  State<AgendaFormView> createState() => _AgendaFormViewState();
}

class _AgendaFormViewState extends State<AgendaFormView> {
  final _judul = TextEditingController();
  final _isi = TextEditingController();
  final _lokasi = TextEditingController();
  final _penyel = TextEditingController();
  final _bawa = TextEditingController();
  final _kontak = TextEditingController();
  final _kuota = TextEditingController();
  final _rw = TextEditingController();
  final _dusun = TextEditingController();
  String _kat = '';
  String _ulang = '';
  String _sasaran = 'semua';
  bool _wajib = false;
  bool _notif = true;
  DateTime _mulai = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 8, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime _selesai = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 11, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  bool _pakaiPeta = false;
  LatLng _titik = const LatLng(-6.239265, 106.530200);
  List<File> _fotoBaru = [];
  List<String> _fotoLama = [];
  bool _simpan = false;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    if (a != null) {
      _judul.text = a.judul;
      _isi.text = a.deskripsi;
      _lokasi.text = a.lokasi;
      _penyel.text = a.penyelenggara;
      _bawa.text = a.bawa;
      _kontak.text = a.kontak;
      _kuota.text = a.kuota > 0 ? '${a.kuota}' : '';
      _kat = a.kategori;
      _ulang = a.ulang;
      _wajib = a.wajib;
      _mulai = a.waktu;
      _selesai = a.akhir;
      _fotoLama = [...a.semuaFoto];
      _notif = false;
      if (a.sasaran.startsWith('rw:')) {
        _sasaran = 'rw';
        _rw.text = a.sasaran.substring(3);
      } else if (a.sasaran.startsWith('dusun:')) {
        _sasaran = 'dusun';
        _dusun.text = a.sasaran.substring(6);
      }
      if (a.punyaLokasi) {
        _pakaiPeta = true;
        _titik = LatLng(a.lat, a.lng);
      }
    } else {
      _penyel.text = 'Pemerintah Desa Talagasari';
    }
  }

  @override
  void dispose() {
    for (final c in [_judul, _isi, _lokasi, _penyel, _bawa, _kontak, _kuota, _rw, _dusun]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pakaiContoh() {
    if (_kat.isEmpty) {
      showSnack(false, '', 'Pilih jenis kegiatan dulu.');
      return;
    }
    final k = katAgenda(_kat);
    setState(() {
      _judul.text = k.contohJudul;
      _isi.text = k.contohIsi;
      _bawa.text = k.contohBawa;
      _selesai = _mulai.add(Duration(hours: k.durasiJam));
    });
  }

  Future<void> _pilihWaktu(bool mulai) async {
    final awal = mulai ? _mulai : _selesai;
    final d = await showDatePicker(
        context: context,
        initialDate: awal,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(awal));
    if (t == null) return;
    final v = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (mulai) {
        final dur = _selesai.difference(_mulai);
        _mulai = v;
        _selesai = v.add(dur.isNegative ? const Duration(hours: 2) : dur);
      } else {
        _selesai = v;
      }
    });
  }

  Widget _langkah(int n, String judul, String bantu) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryColor('admin'),
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(child: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5))),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(bantu, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
          ),
        ]),
      );

  Future<void> _kirim() async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _simpan) return;
    if (_kat.isEmpty) return showSnack(false, '', 'Langkah 1: pilih jenis kegiatan.');
    if (_judul.text.trim().length < 5) return showSnack(false, '', 'Langkah 2: judul minimal 5 huruf.');
    if (_isi.text.trim().length < 15) return showSnack(false, '', 'Langkah 2: jelaskan kegiatan (minimal 15 huruf).');
    if (!_selesai.isAfter(_mulai)) return showSnack(false, '', 'Langkah 3: jam selesai harus setelah jam mulai.');
    if (_lokasi.text.trim().length < 3) return showSnack(false, '', 'Langkah 4: isi lokasi kegiatan.');
    String sasaran = 'semua';
    if (_sasaran == 'rw') {
      if (_rw.text.trim().isEmpty) return showSnack(false, '', 'Langkah 6: isi nomor RW.');
      sasaran = 'rw:${_rw.text.trim()}';
    } else if (_sasaran == 'dusun') {
      if (_dusun.text.trim().isEmpty) return showSnack(false, '', 'Langkah 6: isi nama kampung.');
      sasaran = 'dusun:${_dusun.text.trim()}';
    }
    setState(() => _simpan = true);
    try {
      final foto = [..._fotoLama];
      for (final f in _fotoBaru) {
        final e = await ImageUtil.encode(f);
        if (e != null) foto.add(e);
      }
      final data = <String, dynamic>{
        'judul': _judul.text.trim(),
        'deskripsi': _isi.text.trim(),
        'lokasi': _lokasi.text.trim(),
        'waktu': Timestamp.fromDate(_mulai),
        'selesai': Timestamp.fromDate(_selesai),
        'kategori': _kat,
        'penyelenggara': _penyel.text.trim(),
        'bawa': _bawa.text.trim(),
        'kontak': _kontak.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'kuota': int.tryParse(_kuota.text.trim()) ?? 0,
        'ulang': _ulang,
        'sasaran': sasaran,
        'wajib': _wajib,
        'foto_list': foto,
        'lat': _pakaiPeta ? _titik.latitude : 0.0,
        'lng': _pakaiPeta ? _titik.longitude : 0.0,
      };
      final col = FirebaseFirestore.instance.collection('agenda');
      String id;
      if (widget.awal == null) {
        final ref = await col.add({
          ...data,
          'dibuat_oleh': me.nama,
          'created_at': Timestamp.now(),
          'batal': false,
          'rsvp_hadir': 0,
          'rsvp_mungkin': 0,
          'rsvp_tidak': 0,
          'rsvp_checkin': 0,
        });
        id = ref.id;
        await AuditLog.catat(aksi: 'Membuat agenda', targetTipe: 'agenda', targetId: id, detail: _judul.text.trim());
      } else {
        id = widget.awal!.id;
        await col.doc(id).update(data);
        await AuditLog.catat(aksi: 'Mengubah agenda', targetTipe: 'agenda', targetId: id, detail: _judul.text.trim());
      }
      if (_notif) {
        await notifPeran(['warga'],
            judul: 'Agenda Desa: ${_judul.text.trim()}',
            isi: '${_tgl(_mulai)}, pukul ${_jam(_mulai)} di ${_lokasi.text.trim()}',
            tipe: 'agenda',
            targetId: id);
      }
      Get.back();
      showSnack(true, widget.awal == null ? 'Agenda dibuat.' : 'Agenda diperbarui.', '');
    } catch (e) {
      setState(() => _simpan = false);
      showSnack(false, '', 'Gagal menyimpan agenda: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    final kel = _kat.isEmpty ? null : katAgenda(_kat);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(widget.awal == null ? 'Buat Agenda' : 'Ubah Agenda'),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () => Get.to(() => const PanduanAgendaView())),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Text(
              'Isi 7 langkah. Bingung? Pilih jenis kegiatan lalu tekan "Pakai contoh": judul, penjelasan, dan barang bawaan terisi otomatis, tinggal Anda ubah.',
              style: TextStyle(fontSize: 13, height: 1.4)),
        ),
        _langkah(1, 'Jenis kegiatan', 'Pilih yang paling cocok. Warna dan ikon di kalender mengikuti pilihan ini.'),
        Wrap(spacing: 6, children: [
          for (final k in kategoriAgenda)
            ChoiceChip(
              avatar: Icon(k.ikon, size: 16, color: _kat == k.id ? Colors.white : k.warna),
              label: Text(k.label, style: TextStyle(fontSize: 12, color: _kat == k.id ? Colors.white : null)),
              selected: _kat == k.id,
              selectedColor: k.warna,
              showCheckmark: false,
              onSelected: (_) => setState(() => _kat = k.id),
            ),
        ]),
        if (kel != null) ...[
          const SizedBox(height: 6),
          Text(kel.ringkas, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          TextButton.icon(
              onPressed: _pakaiContoh,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Pakai contoh untuk jenis ini')),
        ],
        _langkah(2, 'Judul dan penjelasan', 'Tulis jelas supaya warga paham acara ini untuk apa.'),
        TextField(
            controller: _judul,
            maxLength: 80,
            decoration: InputDecoration(
                labelText: 'Judul kegiatan', hintText: 'Contoh: ${kel?.contohJudul ?? 'Kerja Bakti Bersih Selokan'}')),
        TextField(
            controller: _isi,
            maxLines: 4,
            maxLength: 600,
            decoration: const InputDecoration(labelText: 'Penjelasan', hintText: 'Apa kegiatannya, tujuannya, siapa yang diundang.')),
        _langkah(3, 'Waktu', 'Pilih tanggal dan jam mulai serta selesai. Kegiatan rutin cukup diisi satu kali.'),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _pilihWaktu(true),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text('Mulai\n${DateFormat('d MMM, HH.mm', 'id').format(_mulai)}', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _pilihWaktu(false),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text('Selesai\n${DateFormat('d MMM, HH.mm', 'id').format(_selesai)}', textAlign: TextAlign.center),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final e in _labelUlang.entries)
            ChoiceChip(
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: _ulang == e.key,
              onSelected: (_) => setState(() => _ulang = e.key),
            ),
        ]),
        if (_ulang.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Contoh: Posyandu tiap bulan di tanggal yang sama, ronda tiap minggu. Kegiatan rutin tidak memakai konfirmasi hadir.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        _langkah(4, 'Tempat', 'Tulis nama tempat. Menandai titik di peta bersifat opsional.'),
        TextField(
            controller: _lokasi,
            decoration: const InputDecoration(
                labelText: 'Lokasi', hintText: 'Contoh: Balai Desa Talagasari / Lapangan RW 05')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pakaiPeta,
          onChanged: (v) => setState(() => _pakaiPeta = v),
          title: const Text('Tandai titik di peta (opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Ketuk peta, tombol Lokasi saya, atau Cari alamat.', style: TextStyle(fontSize: 12)),
        ),
        if (_pakaiPeta) PemilihPeta(titik: _titik, warna: kel?.warna ?? Colors.red, onChanged: (p) => _titik = p),
        _langkah(5, 'Panitia dan perlengkapan', 'Siapa penyelenggaranya, nomor yang bisa ditanya, dan apa yang harus dibawa warga.'),
        TextField(controller: _penyel, decoration: const InputDecoration(labelText: 'Penyelenggara')),
        TextField(
            controller: _kontak,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'WhatsApp panitia (opsional)', hintText: '081234567890')),
        TextField(
            controller: _bawa,
            maxLines: 2,
            decoration: InputDecoration(
                labelText: 'Yang perlu dibawa (opsional)', hintText: kel?.contohBawa.isNotEmpty == true ? kel!.contohBawa : 'Contoh: KTP, sarung tangan')),
        _langkah(6, 'Siapa yang diundang', 'Pilih seluruh warga atau hanya satu RW / kampung. Atur batas peserta bila tempat terbatas.'),
        Wrap(spacing: 6, children: [
          ChoiceChip(label: const Text('Semua warga'), selected: _sasaran == 'semua', onSelected: (_) => setState(() => _sasaran = 'semua')),
          ChoiceChip(label: const Text('Satu RW'), selected: _sasaran == 'rw', onSelected: (_) => setState(() => _sasaran = 'rw')),
          ChoiceChip(label: const Text('Satu kampung'), selected: _sasaran == 'dusun', onSelected: (_) => setState(() => _sasaran = 'dusun')),
        ]),
        if (_sasaran == 'rw')
          TextField(controller: _rw, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nomor RW', hintText: '05')),
        if (_sasaran == 'dusun')
          TextField(controller: _dusun, decoration: const InputDecoration(labelText: 'Nama kampung', hintText: 'Kp. Baru')),
        TextField(
            controller: _kuota,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Batas peserta (kosongkan bila tanpa batas)', hintText: '50')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _wajib,
          onChanged: (v) => setState(() => _wajib = v),
          title: const Text('Tandai WAJIB hadir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Untuk rapat atau kegiatan penting.', style: TextStyle(fontSize: 12)),
        ),
        _langkah(7, 'Poster / foto dan pemberitahuan', 'Foto bersifat opsional (maksimal 3).'),
        FotoPicker(
          maks: 3,
          label: 'Poster atau foto (opsional)',
          fotoLama: _fotoLama,
          onChanged: (baru, lama) {
            _fotoBaru = baru;
            _fotoLama = lama;
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _notif,
          onChanged: (v) => setState(() => _notif = v),
          title: const Text('Beri tahu semua warga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Warga menerima pemberitahuan di aplikasi.', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52)),
          onPressed: _simpan ? null : _kirim,
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(_simpan ? 'Menyimpan...' : (widget.awal == null ? 'Terbitkan agenda' : 'Simpan perubahan')),
        ),
      ]),
    );
  }
}
