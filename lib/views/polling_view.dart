// ============================================================
// polling_view.dart — SUARA WARGA (musyawarah online Desa Talagasari)
//
// Fungsi: Kepala Desa / perangkat meminta pendapat warga sebelum memutuskan
// (pembangunan, kegiatan, keamanan, anggaran, dst.). Warga memilih secara
// RAHASIA (satu akun = satu suara), melihat hasil, berdiskusi, lalu desa
// menetapkan keputusan yang bisa dibaca semua warga.
// Warga juga dapat MENGUSULKAN topik. Firestore saja (gratis).
// ============================================================
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/village_controller.dart' show notifPeran, AuditLog;
import '../core/core.dart';
import '../core/ui_helpers.dart';
import 'info_sosial.dart' show GaleriFoto;
import 'moderasi_view.dart';
import 'verification_view.dart' show wajibVerifikasi;

// ─────────────────────────────────────────────────────────────
// KATEGORI + TEMPLATE CONTOH
// ─────────────────────────────────────────────────────────────
class KatPoll {
  final String id;
  final String label;
  final IconData ikon;
  final Color warna;
  final String contoh;
  const KatPoll(this.id, this.label, this.ikon, this.warna, this.contoh);
}

const List<KatPoll> kategoriPoll = [
  KatPoll('pembangunan', 'Pembangunan & Infrastruktur', Icons.construction, Color(0xFF6D4C41),
      'Perbaikan jalan, saluran air, lampu jalan, balai warga.'),
  KatPoll('kegiatan', 'Kegiatan & Acara', Icons.celebration_outlined, Color(0xFFE65100),
      'Lomba 17 Agustus, bazar, pengajian akbar, jalan sehat.'),
  KatPoll('keamanan', 'Keamanan & Ketertiban', Icons.shield_outlined, Color(0xFF37474F),
      'Jadwal ronda, CCTV kampung, portal lingkungan.'),
  KatPoll('lingkungan', 'Kebersihan & Lingkungan', Icons.eco_outlined, Color(0xFF2E7D32),
      'Jadwal sampah, bank sampah, kerja bakti, penghijauan.'),
  KatPoll('ekonomi', 'Ekonomi & UMKM', Icons.storefront_outlined, Color(0xFF00897B),
      'Pasar kaget, pelatihan UMKM, koperasi desa.'),
  KatPoll('kesehatan', 'Kesehatan & Posyandu', Icons.health_and_safety_outlined, Color(0xFFC62828),
      'Jadwal posyandu, senam sehat, penyuluhan, vaksinasi.'),
  KatPoll('pendidikan', 'Pendidikan & Pemuda', Icons.school_outlined, Color(0xFF1565C0),
      'Taman baca, pelatihan pemuda, turnamen, beasiswa.'),
  KatPoll('sosial', 'Keagamaan & Sosial', Icons.volunteer_activism_outlined, Color(0xFF6A1B9A),
      'Santunan, kegiatan masjid, gotong royong.'),
  KatPoll('anggaran', 'Anggaran & Dana Desa', Icons.account_balance_wallet_outlined, Color(0xFFAD1457),
      'Prioritas penggunaan dana desa tahun depan.'),
  KatPoll('layanan', 'Layanan Desa & Aplikasi', Icons.support_agent_outlined, Color(0xFF0277BD),
      'Jam pelayanan kantor desa, fitur baru aplikasi.'),
  KatPoll('lainnya', 'Lainnya', Icons.more_horiz, Color(0xFF546E7A), 'Topik lain yang perlu pendapat warga.'),
];

KatPoll katPoll(String id) =>
    kategoriPoll.firstWhere((k) => k.id == id, orElse: () => kategoriPoll.last);

class TipePoll {
  final String id;
  final String label;
  final String bantu;
  const TipePoll(this.id, this.label, this.bantu);
}

const List<TipePoll> tipePoll = [
  TipePoll('tunggal', 'Pilih satu', 'Warga memilih satu jawaban. Cocok untuk memilih prioritas atau jadwal.'),
  TipePoll('ganda', 'Pilih beberapa', 'Warga boleh memilih lebih dari satu jawaban (Anda tentukan batasnya).'),
  TipePoll('setuju', 'Setuju / Tidak', 'Warga menjawab Setuju, Tidak setuju, atau Abstain. Cocok untuk rencana.'),
  TipePoll('skala', 'Penilaian 1–5', 'Warga memberi nilai kepuasan 1 sampai 5. Cocok untuk evaluasi layanan.'),
];

const List<String> _opsiSetuju = ['Setuju', 'Tidak setuju', 'Abstain'];
const List<String> _opsiSkala = [
  '1 – Sangat kurang',
  '2 – Kurang',
  '3 – Cukup',
  '4 – Baik',
  '5 – Sangat baik'
];

class TemplatePoll {
  final String kategori;
  final String judul;
  final String pertanyaan;
  final String penjelasan;
  final String tipe;
  final List<String> opsi;
  const TemplatePoll(this.kategori, this.judul, this.pertanyaan, this.penjelasan, this.tipe, this.opsi);
}

const List<TemplatePoll> templatePoll = [
  TemplatePoll('pembangunan', 'Prioritas perbaikan jalan',
      'Jalan mana yang paling perlu diperbaiki lebih dulu tahun ini?',
      'Dana terbatas sehingga perbaikan dilakukan bertahap. Pilih satu yang paling mendesak menurut Anda.',
      'tunggal', ['Jalan Kampung (RW 01)', 'Jalan Utama Desa', 'Gang menuju sekolah', 'Saluran air depan pasar']),
  TemplatePoll('pembangunan', 'Pemasangan lampu jalan',
      'Setujukah Anda bila desa memasang lampu jalan tenaga surya di titik gelap?',
      'Lampu surya tidak menambah tagihan listrik, tetapi memakai dana desa.',
      'setuju', _opsiSetuju),
  TemplatePoll('kegiatan', 'Lomba 17 Agustus',
      'Lomba apa yang paling Anda ingin ikuti saat peringatan 17 Agustus?',
      'Pilih maksimal 3 lomba. Hasilnya dipakai panitia menyusun acara.',
      'ganda', ['Panjat pinang', 'Balap karung', 'Tarik tambang', 'Lomba makan kerupuk', 'Lomba anak-anak', 'Jalan sehat']),
  TemplatePoll('kegiatan', 'Hari kerja bakti',
      'Hari apa paling cocok untuk kerja bakti bulanan?',
      'Agar sebanyak mungkin warga bisa ikut tanpa mengganggu pekerjaan.',
      'tunggal', ['Sabtu pagi', 'Minggu pagi', 'Minggu sore']),
  TemplatePoll('keamanan', 'Jadwal ronda malam',
      'Setujukah ronda malam dijadwalkan bergilir per RT mulai bulan depan?',
      'Jadwal dibuat bergilir agar tidak memberatkan satu RT saja.',
      'setuju', _opsiSetuju),
  TemplatePoll('lingkungan', 'Bank sampah',
      'Apakah Anda bersedia ikut program bank sampah desa?',
      'Sampah anorganik ditimbang dan ditabung, hasilnya untuk kas RW.',
      'setuju', _opsiSetuju),
  TemplatePoll('ekonomi', 'Pasar kaget mingguan',
      'Hari apa pasar kaget UMKM sebaiknya diadakan?',
      'Pasar kaget memberi tempat jualan murah bagi pelaku usaha rumahan.',
      'tunggal', ['Jumat sore', 'Sabtu pagi', 'Minggu pagi']),
  TemplatePoll('kesehatan', 'Senam sehat / posyandu lansia',
      'Kegiatan kesehatan apa yang paling Anda butuhkan?',
      'Pilih maksimal 2. Dinas kesehatan akan diundang sesuai pilihan terbanyak.',
      'ganda', ['Senam sehat pagi', 'Posyandu lansia', 'Cek gula darah gratis', 'Penyuluhan gizi anak']),
  TemplatePoll('pendidikan', 'Taman baca desa',
      'Setujukah desa membuka taman baca di balai warga?',
      'Taman baca dikelola karang taruna dan terbuka untuk anak-anak sepulang sekolah.',
      'setuju', _opsiSetuju),
  TemplatePoll('sosial', 'Santunan anak yatim',
      'Kapan sebaiknya santunan anak yatim dilaksanakan?',
      'Dilaksanakan bersama pengurus masjid dan donasi warga.',
      'tunggal', ['Bulan Muharram', 'Menjelang Ramadan', 'Setelah Idulfitri']),
  TemplatePoll('anggaran', 'Prioritas dana desa',
      'Dana desa tahun depan sebaiknya diprioritaskan untuk apa?',
      'Pilih maksimal 2. Hasil dipakai pada musyawarah desa.',
      'ganda', ['Perbaikan jalan', 'Pelatihan UMKM', 'Kesehatan & posyandu', 'Keamanan lingkungan', 'Beasiswa pemuda']),
  TemplatePoll('layanan', 'Kepuasan pelayanan kantor desa',
      'Seberapa puas Anda dengan pelayanan kantor desa bulan ini?',
      'Penilaian Anda rahasia dan dipakai untuk memperbaiki pelayanan.',
      'skala', _opsiSkala),
];

const List<String> _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────
class SuaraModel {
  final String id;
  final String pertanyaan;
  final String penjelasan;
  final String kategori;
  final String tipe;
  final List<String> opsi;
  final int maksPilih;
  final DateTime mulai;
  final DateTime tutup;
  final String sasaran; // semua | rw:NN | dusun:nama
  final bool hasilLangsung; // false = hasil tampil setelah ditutup
  final List<String> foto;
  final String dibuatOleh;
  final String dibuatUid;
  final DateTime dibuat;
  final String keputusan;
  final String statusTindak; // '' | dipertimbangkan | disetujui | dilaksanakan | ditolak
  final DateTime? keputusanAt;
  final int total;
  final Map<String, int> hitung;
  final Map<String, int> perRw;
  final bool legacy;

  SuaraModel({
    required this.id,
    required this.pertanyaan,
    required this.penjelasan,
    required this.kategori,
    required this.tipe,
    required this.opsi,
    required this.maksPilih,
    required this.mulai,
    required this.tutup,
    required this.sasaran,
    required this.hasilLangsung,
    required this.foto,
    required this.dibuatOleh,
    required this.dibuatUid,
    required this.dibuat,
    required this.keputusan,
    required this.statusTindak,
    required this.keputusanAt,
    required this.total,
    required this.hitung,
    required this.perRw,
    required this.legacy,
  });

  factory SuaraModel.dari(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    DateTime t(dynamic v, DateTime def) => v is Timestamp ? v.toDate() : def;
    Map<String, int> peta(dynamic v) => v is Map
        ? v.map((k, x) => MapEntry('$k', (x as num).toInt()))
        : <String, int>{};
    final fotoL = <String>[
      if (m['foto_list'] is List) ...(m['foto_list'] as List).map((e) => '$e'),
      if (m['foto_list'] is! List && '${m['foto_url'] ?? ''}'.isNotEmpty) '${m['foto_url']}',
    ];
    return SuaraModel(
      id: d.id,
      pertanyaan: '${m['pertanyaan'] ?? ''}',
      penjelasan: '${m['penjelasan'] ?? ''}',
      kategori: '${m['kategori'] ?? 'lainnya'}',
      tipe: '${m['tipe'] ?? 'tunggal'}',
      opsi: m['opsi'] is List ? (m['opsi'] as List).map((e) => '$e').toList() : <String>[],
      maksPilih: (m['maks_pilih'] ?? 1) is int ? (m['maks_pilih'] ?? 1) as int : 1,
      mulai: t(m['mulai'], t(m['created_at'], DateTime.now())),
      tutup: t(m['tutup'], DateTime.now()),
      sasaran: '${m['sasaran'] ?? 'semua'}',
      hasilLangsung: m['hasil_langsung'] != false,
      foto: fotoL,
      dibuatOleh: '${m['dibuat_oleh'] ?? ''}',
      dibuatUid: '${m['dibuat_uid'] ?? ''}',
      dibuat: t(m['created_at'], DateTime.now()),
      keputusan: '${m['keputusan'] ?? ''}',
      statusTindak: '${m['status_tindak'] ?? ''}',
      keputusanAt: m['keputusan_at'] is Timestamp ? (m['keputusan_at'] as Timestamp).toDate() : null,
      total: (m['total'] ?? 0) is int ? (m['total'] ?? 0) as int : 0,
      hitung: peta(m['hitung']),
      perRw: peta(m['per_rw']),
      legacy: !m.containsKey('total'),
    );
  }

  bool get ditutup => DateTime.now().isAfter(tutup);
  bool get belumMulai => DateTime.now().isBefore(mulai);

  String get labelSasaran {
    if (sasaran == 'semua') return 'Seluruh warga Talagasari';
    if (sasaran.startsWith('rw:')) return 'Khusus warga RW ${sasaran.substring(3)}';
    if (sasaran.startsWith('dusun:')) return 'Khusus warga Kp. ${sasaran.substring(6)}';
    return sasaran;
  }

  /// Apakah warga ini termasuk sasaran?
  bool termasukSasaran(String rw, String dusun) {
    if (sasaran == 'semua') return true;
    String n(String s) => s.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (sasaran.startsWith('rw:')) return n(sasaran.substring(3)) == n(rw);
    if (sasaran.startsWith('dusun:')) {
      return sasaran.substring(6).trim().toLowerCase() == dusun.trim().toLowerCase();
    }
    return true;
  }

  String sisaWaktu() {
    if (belumMulai) return 'Mulai ${AppUtils.formatTanggal(mulai)}';
    if (ditutup) return 'Ditutup ${AppUtils.formatTanggal(tutup)}';
    final s = tutup.difference(DateTime.now());
    if (s.inDays >= 1) return 'Sisa ${s.inDays} hari';
    if (s.inHours >= 1) return 'Sisa ${s.inHours} jam';
    return 'Sisa ${s.inMinutes} menit';
  }
}

const Map<String, String> _labelTindak = {
  'dipertimbangkan': 'Sedang dipertimbangkan',
  'disetujui': 'Disetujui desa',
  'dilaksanakan': 'Sudah dilaksanakan',
  'ditolak': 'Tidak dilanjutkan',
};
const Map<String, Color> _warnaTindak = {
  'dipertimbangkan': Colors.orange,
  'disetujui': Colors.green,
  'dilaksanakan': Colors.blue,
  'ditolak': Colors.red,
};

// ─────────────────────────────────────────────────────────────
// PANDUAN
// ─────────────────────────────────────────────────────────────
class PanduanPollingView extends StatelessWidget {
  const PanduanPollingView({super.key});

  Widget _j(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _p(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Text(t, style: const TextStyle(fontSize: 13.5, height: 1.45)),
      );

  Widget _kotak(String judul, String isi, Color c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 4),
          Text(isi, style: const TextStyle(fontSize: 13, height: 1.4)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Panduan Suara Warga')),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        _j('Apa itu Suara Warga?'),
        _p('Suara Warga adalah musyawarah online. Sebelum desa memutuskan sesuatu (misalnya perbaikan jalan atau jadwal ronda), Kepala Desa dan perangkat bertanya dulu kepada warga lewat pertanyaan singkat. Warga menjawab dari HP, kapan saja, tanpa harus datang ke balai desa.'),
        _j('Kenapa penting?'),
        _kotak('Manfaat untuk warga', '• Suara Anda ikut menentukan keputusan desa.\n• Hasil terbuka, jadi semua tahu pilihan terbanyak.\n• Keputusan desa dicatat dan bisa dibaca kembali.', Colors.green.shade700),
        const SizedBox(height: 6),
        _kotak('Manfaat untuk desa', '• Mendengar suara warga yang tidak sempat datang rapat.\n• Keputusan didukung data, bukan perkiraan.\n• Lebih cepat dan hemat biaya dibanding rapat besar.', Colors.blue.shade700),
        _j('Contoh nyata'),
        _kotak('Pilih satu', 'Pertanyaan: "Jalan mana yang paling perlu diperbaiki lebih dulu?" Pilihan: Jalan Kampung, Jalan Utama, Gang sekolah. Warga memilih satu. Hasil: Gang sekolah 52%. Keputusan desa: "Gang sekolah diperbaiki bulan depan".', Colors.orange.shade800),
        const SizedBox(height: 6),
        _kotak('Setuju / Tidak', 'Pertanyaan: "Setujukah ronda malam bergilir per RT?" Warga memilih Setuju, Tidak setuju, atau Abstain.', Colors.teal.shade700),
        const SizedBox(height: 6),
        _kotak('Pilih beberapa', 'Pertanyaan: "Lomba apa yang ingin Anda ikuti saat 17 Agustus?" Pilih maksimal 3 lomba.', Colors.purple.shade700),
        const SizedBox(height: 6),
        _kotak('Penilaian 1–5', 'Pertanyaan: "Seberapa puas Anda dengan pelayanan kantor desa?" Beri nilai 1 sampai 5.', Colors.indigo.shade700),
        _j('Cara ikut memilih'),
        _p('1. Buka menu Layanan Desa → Suara Warga.\n'
            '2. Pilih topik yang berstatus "Berlangsung". Baca penjelasan dan lihat foto bila ada.\n'
            '3. Pilih jawaban Anda lalu tekan "Kirim suara".\n'
            '4. Lihat hasil dan ikut berdiskusi di bagian komentar.\n'
            '5. Setelah ditutup, baca keputusan desa di bagian "Keputusan desa".'),
        _j('Aturan penting'),
        _kotak('Perlu diketahui', '• Satu akun = satu suara dan tidak bisa diubah setelah dikirim.\n• Pilihan Anda RAHASIA: yang tampil hanya jumlah, bukan siapa memilih apa.\n• Anda wajib terverifikasi KTP Desa Talagasari.\n• Sebagian topik hanya untuk RW atau kampung tertentu. Bila bukan sasaran, Anda tetap bisa melihat dan berkomentar.\n• Sampaikan pendapat dengan sopan. Lihat Aturan Komunitas di menu Akun.', Colors.red.shade700),
        _j('Mengusulkan topik'),
        _p('Punya masalah yang perlu dimusyawarahkan? Di halaman Suara Warga tekan "Usulkan Topik", pilih kategori, tulis pertanyaan dan alasannya. Perangkat desa akan menjadikannya Suara Warga atau menolak disertai alasan.'),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DAFTAR
// ─────────────────────────────────────────────────────────────
class PollListView extends StatefulWidget {
  const PollListView({super.key});

  @override
  State<PollListView> createState() => _PollListViewState();
}

class _PollListViewState extends State<PollListView> {
  final db = FirebaseFirestore.instance;
  String _status = 'berlangsung'; // berlangsung | selesai | semua
  String _kat = 'semua';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      db.collection('polling').orderBy('created_at', descending: true).limit(150).snapshots();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final Color primary = AppTheme.primaryColor(auth.role);
    final bool staf = auth.isStaff;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text('Suara Warga'),
          actions: [
            IconButton(
                tooltip: 'Panduan',
                icon: const Icon(Icons.help_outline),
                onPressed: () => Get.to(() => const PanduanPollingView())),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Topik'),
              Tab(text: staf ? 'Usulan warga' : 'Usulan saya'),
            ],
          ),
        ),
        floatingActionButton: Builder(builder: (context) {
          return FloatingActionButton.extended(
            backgroundColor: primary,
            onPressed: () async {
              if (staf) {
                Get.to(() => const BuatPollingView());
              } else {
                if (!await wajibVerifikasi()) return;
                Get.to(() => const UsulPollView());
              }
            },
            icon: Icon(staf ? Icons.add : Icons.lightbulb_outline, color: Colors.white),
            label: Text(staf ? 'Buat Suara Warga' : 'Usulkan Topik',
                style: const TextStyle(color: Colors.white)),
          );
        }),
        body: TabBarView(children: [_tabTopik(primary), _UsulanTab(staf: staf)]),
      ),
    );
  }

  Widget _tabTopik(Color primary) {
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '';
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade100)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.how_to_vote_outlined, color: Colors.green.shade800),
            title: const Text('Apa itu Suara Warga?',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Musyawarah online: desa bertanya, warga menjawab dari HP. Pilihan Anda rahasia, hasilnya terbuka, dan keputusan desa dicatat di sini.',
                  style: TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 6),
              const Text(
                  'Contoh: "Jalan mana yang diperbaiki dulu?", "Setujukah ronda bergilir per RT?", "Lomba apa untuk 17 Agustus?"',
                  style: TextStyle(fontSize: 12.5, height: 1.4, fontStyle: FontStyle.italic)),
              TextButton(
                  onPressed: () => Get.to(() => const PanduanPollingView()),
                  child: const Text('Baca panduan lengkap')),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(spacing: 6, children: [
          for (final e in const [
            ['berlangsung', 'Berlangsung'],
            ['selesai', 'Selesai'],
            ['semua', 'Semua']
          ])
            ChoiceChip(
              label: Text(e[1], style: const TextStyle(fontSize: 12)),
              selected: _status == e[0],
              onSelected: (_) => setState(() => _status = e[0]),
            ),
        ]),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            _chipKat('semua', 'Semua topik', Icons.apps, primary),
            for (final k in kategoriPoll) _chipKat(k.id, k.label, k.ikon, k.warna),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Tidak dapat memuat',
                  subtitle: 'Periksa koneksi internet. Pastikan aturan Firestore terbaru sudah dipasang.');
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var list = snap.data!.docs.map(SuaraModel.dari).toList();
            if (_status == 'berlangsung') list = list.where((p) => !p.ditutup).toList();
            if (_status == 'selesai') list = list.where((p) => p.ditutup).toList();
            if (_kat != 'semua') list = list.where((p) => p.kategori == _kat).toList();
            if (list.isEmpty) {
              return EmptyState(
                  icon: Icons.how_to_vote_outlined,
                  title: _status == 'berlangsung' ? 'Belum ada topik berlangsung' : 'Tidak ada topik',
                  subtitle: 'Topik musyawarah desa akan muncul di sini. Anda juga bisa mengusulkan topik.');
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 90),
              itemCount: list.length,
              itemBuilder: (_, i) => _KartuPoll(p: list[i], uid: uid),
            );
          },
        ),
      ),
    ]);
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
}

class _KartuPoll extends StatelessWidget {
  final SuaraModel p;
  final String uid;
  const _KartuPoll({required this.p, required this.uid});

  @override
  Widget build(BuildContext context) {
    final k = katPoll(p.kategori);
    final aktif = !p.ditutup && !p.belumMulai;
    return InkWell(
      onTap: () => Get.to(() => PollDetailView(id: p.id)),
      child: kartu(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(k.ikon, size: 17, color: k.warna),
            const SizedBox(width: 5),
            Expanded(
              child: Text(k.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: k.warna, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: aktif ? Colors.green.shade600 : Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(aktif ? 'BERLANGSUNG' : (p.belumMulai ? 'SEGERA' : 'SELESAI'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(p.pertanyaan, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 2, children: [
            _info(Icons.schedule, p.sisaWaktu()),
            _info(Icons.groups_outlined, p.sasaran == 'semua' ? 'Semua warga' : p.labelSasaran),
            _info(Icons.how_to_vote_outlined, '${p.total} suara'),
          ]),
          if (p.statusTindak.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.flag_circle_outlined, size: 17, color: _warnaTindak[p.statusTindak]),
                const SizedBox(width: 4),
                Text(_labelTindak[p.statusTindak] ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _warnaTindak[p.statusTindak])),
              ]),
            ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('polling')
                .doc(p.id)
                .collection('suara')
                .doc(uid.isEmpty ? '-' : uid)
                .snapshots(),
            builder: (_, s) => (s.data?.exists ?? false)
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Anda sudah memilih',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _info(IconData ic, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(t, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]);
}

// ─────────────────────────────────────────────────────────────
// DETAIL + MEMILIH + HASIL + DISKUSI
// ─────────────────────────────────────────────────────────────
class PollDetailView extends StatefulWidget {
  final String id;
  const PollDetailView({super.key, required this.id});

  @override
  State<PollDetailView> createState() => _PollDetailViewState();
}

class _PollDetailViewState extends State<PollDetailView> {
  final db = FirebaseFirestore.instance;
  final Set<int> _pilih = {};
  bool _kirim = false;
  final _komen = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _ref => db.collection('polling').doc(widget.id);

  @override
  void dispose() {
    _komen.dispose();
    super.dispose();
  }

  Future<void> _kirimSuara(SuaraModel p) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _kirim) return;
    if (!await wajibVerifikasi()) return;
    if (_pilih.isEmpty) {
      showSnack(false, '', 'Pilih jawaban dulu.');
      return;
    }
    if (p.tipe == 'ganda' && _pilih.length > p.maksPilih) {
      showSnack(false, '', 'Maksimal ${p.maksPilih} pilihan.');
      return;
    }
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Kirim suara?'),
      content: const Text('Suara tidak bisa diubah setelah dikirim. Pilihan Anda dirahasiakan.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Periksa lagi')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
            onPressed: () => Get.back(result: true),
            child: const Text('Kirim')),
      ],
    ));
    if (ok != true) return;
    setState(() => _kirim = true);
    try {
      final rw = me.alamatRw.replaceAll(RegExp(r'[^0-9]'), '');
      final b = db.batch();
      b.set(_ref.collection('suara').doc(me.uid), {
        'uid': me.uid,
        'pilihan': _pilih.toList()..sort(),
        'opsi_index': _pilih.first,
        'rw': rw,
        'created_at': Timestamp.now(),
      });
      b.update(_ref, {
        'total': FieldValue.increment(1),
        for (final i in _pilih) 'hitung.$i': FieldValue.increment(1),
        if (rw.isNotEmpty) 'per_rw.$rw': FieldValue.increment(1),
      });
      await b.commit();
      showSnack(true, 'Suara Anda terkirim. Terima kasih!', '');
    } catch (_) {
      showSnack(false, '', 'Gagal mengirim suara. Mungkin Anda sudah memilih, atau topik sudah ditutup.');
    }
    if (mounted) setState(() => _kirim = false);
  }

  Future<void> _tutupSekarang(SuaraModel p) async {
    final ok = await _konfirmasi('Tutup sekarang?', 'Warga tidak bisa memilih lagi dan hasil dapat dilihat semua.');
    if (ok != true) return;
    await _ref.update({'tutup': Timestamp.now()});
    await AuditLog.catat(aksi: 'Menutup suara warga', targetTipe: 'polling', targetId: p.id, detail: p.pertanyaan);
  }

  Future<void> _hapus(SuaraModel p) async {
    final ok = await _konfirmasi('Hapus topik ini?', 'Topik, suara, dan komentar akan hilang permanen.');
    if (ok != true) return;
    try {
      await _ref.delete();
      await AuditLog.catat(aksi: 'Menghapus suara warga', targetTipe: 'polling', targetId: p.id, detail: p.pertanyaan);
      Get.back();
      showSnack(true, 'Topik dihapus.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menghapus.');
    }
  }

  Future<bool?> _konfirmasi(String t, String i) => Get.dialog<bool>(AlertDialog(
        title: Text(t),
        content: Text(i),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
              onPressed: () => Get.back(result: true),
              child: const Text('Ya')),
        ],
      ));

  Future<void> _tetapkan(SuaraModel p) async {
    final ctrl = TextEditingController(text: p.keputusan);
    String st = p.statusTindak.isEmpty ? 'disetujui' : p.statusTindak;
    final ok = await Get.dialog<bool>(StatefulBuilder(builder: (ctx, setS) {
      return AlertDialog(
        title: const Text('Keputusan desa'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Status tindak lanjut', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: [
              for (final e in _labelTindak.entries)
                ChoiceChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  selected: st == e.key,
                  onSelected: (_) => setS(() => st = e.key),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                  labelText: 'Penjelasan keputusan (wajib)',
                  hintText: 'Contoh: Berdasarkan 52% suara, gang sekolah diperbaiki bulan depan memakai dana desa.'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
              onPressed: () {
                if (ctrl.text.trim().length < 10) {
                  showSnack(false, '', 'Penjelasan minimal 10 huruf.');
                  return;
                }
                Get.back(result: true);
              },
              child: const Text('Simpan')),
        ],
      );
    }));
    if (ok != true) return;
    try {
      await _ref.update({
        'keputusan': ctrl.text.trim(),
        'status_tindak': st,
        'keputusan_at': Timestamp.now(),
      });
      await AuditLog.catat(aksi: 'Keputusan suara warga', targetTipe: 'polling', targetId: p.id, detail: '${_labelTindak[st]}: ${p.pertanyaan}');
      await notifPeran(['warga'],
          judul: 'Keputusan desa: ${_labelTindak[st]}',
          isi: p.pertanyaan,
          tipe: 'info',
          targetId: p.id);
      showSnack(true, 'Keputusan disimpan dan diumumkan.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan keputusan.');
    }
  }

  Future<void> _kirimKomen(SuaraModel p) async {
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
      showSnack(false, '', 'Gagal mengirim komentar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final me = auth.currentUser.value;
    final primary = AppTheme.primaryColor(auth.role);
    final staf = auth.isStaff;
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
                  icon: Icons.how_to_vote_outlined,
                  title: 'Topik tidak ditemukan',
                  subtitle: 'Topik ini sudah dihapus.'));
        }
        final p = SuaraModel.dari(snap.data!);
        final k = katPoll(p.kategori);
        final sasaran = me != null && p.termasukSasaran(me.alamatRw, me.alamatDusun);
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: primary,
            title: const Text('Suara Warga'),
            actions: [
              if (staf)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'tutup') _tutupSekarang(p);
                    if (v == 'keputusan') _tetapkan(p);
                    if (v == 'hapus') _hapus(p);
                  },
                  itemBuilder: (_) => [
                    if (!p.ditutup)
                      const PopupMenuItem(value: 'tutup', child: Text('Tutup sekarang')),
                    const PopupMenuItem(value: 'keputusan', child: Text('Tetapkan keputusan desa')),
                    const PopupMenuItem(value: 'hapus', child: Text('Hapus topik')),
                  ],
                ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            if (p.foto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GaleriFoto(foto: p.foto),
              ),
            kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(k.ikon, size: 18, color: k.warna),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(k.label,
                        style: TextStyle(color: k.warna, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                  Text(p.sisaWaktu(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.ditutup ? Colors.grey : Colors.green.shade800)),
                ]),
                const SizedBox(height: 8),
                Text(p.pertanyaan,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.3)),
                if (p.penjelasan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(p.penjelasan, style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
                const SizedBox(height: 10),
                _baris(Icons.groups_outlined, p.labelSasaran),
                _baris(Icons.event_outlined,
                    '${AppUtils.formatTanggalWaktu(p.mulai)} – ${AppUtils.formatTanggalWaktu(p.tutup)}'),
                _baris(Icons.lock_outline, 'Pilihan rahasia · satu akun satu suara'),
                _baris(Icons.person_outline, 'Dibuat oleh ${p.dibuatOleh}'),
              ]),
            ),
            _bagianMemilih(p, me?.uid ?? '', sasaran),
            if (p.statusTindak.isNotEmpty || p.keputusan.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: (_warnaTindak[p.statusTindak] ?? Colors.blueGrey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: (_warnaTindak[p.statusTindak] ?? Colors.blueGrey).withOpacity(0.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.gavel_outlined, color: _warnaTindak[p.statusTindak]),
                    const SizedBox(width: 6),
                    const Text('Keputusan desa',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 4),
                  Text(_labelTindak[p.statusTindak] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: _warnaTindak[p.statusTindak])),
                  const SizedBox(height: 4),
                  Text(p.keputusan, style: const TextStyle(fontSize: 13.5, height: 1.45)),
                  if (p.keputusanAt != null)
                    Text(AppUtils.formatTanggal(p.keputusanAt!),
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                ]),
              )
            else if (staf && p.ditutup)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _tetapkan(p),
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Tetapkan keputusan desa'),
                ),
              ),
            const SectionTitle('Diskusi warga'),
            _diskusi(p, me),
          ]),
        );
      },
    );
  }

  Widget _baris(IconData ic, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary))),
        ]),
      );

  Widget _bagianMemilih(SuaraModel p, String uid, bool sasaran) {
    final staf = Get.find<AuthController>().isStaff;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.collection('suara').doc(uid.isEmpty ? '-' : uid).snapshots(),
      builder: (context, s) {
        final sudah = s.data?.exists ?? false;
        final milik = <int>{
          if (sudah && s.data!.data()?['pilihan'] is List)
            ...(s.data!.data()!['pilihan'] as List).map((e) => (e as num).toInt()),
        };
        final bisaMemilih = !sudah && !p.ditutup && !p.belumMulai && sasaran;
        final tampilHasil = sudah || p.ditutup || staf;
        final hasilBolehLihat = p.hasilLangsung || p.ditutup || staf;
        return kartu(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.how_to_vote_outlined),
              const SizedBox(width: 6),
              Text(bisaMemilih ? 'Pilih jawaban Anda' : 'Hasil sementara',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text('${p.total} suara',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            ]),
            if (p.tipe == 'ganda')
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Boleh pilih sampai ${p.maksPilih} jawaban.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            if (!sasaran && !p.ditutup)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('Topik ini ${p.labelSasaran.toLowerCase()}. Anda tetap bisa melihat dan berkomentar.',
                    style: const TextStyle(fontSize: 12.5)),
              ),
            const SizedBox(height: 8),
            if (bisaMemilih) ...[
              for (var i = 0; i < p.opsi.length; i++) _opsiPilih(p, i),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                onPressed: _kirim ? null : () => _kirimSuara(p),
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(_kirim ? 'Mengirim...' : 'Kirim suara'),
              ),
            ] else ...[
              if (sudah)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 4),
                    Text('Anda sudah memilih. Terima kasih!',
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (p.belumMulai)
                const Text('Topik ini belum dimulai.')
              else if (!hasilBolehLihat)
                const Text('Hasil akan ditampilkan setelah pemungutan suara ditutup.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else if (tampilHasil || sasaran) ...[
                _hasil(p, milik),
                if (staf && p.perRw.isNotEmpty) _perRw(p),
              ],
            ],
          ]),
        );
      },
    );
  }

  Widget _opsiPilih(SuaraModel p, int i) {
    final sel = _pilih.contains(i);
    final ganda = p.tipe == 'ganda';
    return InkWell(
      onTap: () => setState(() {
        if (ganda) {
          if (sel) {
            _pilih.remove(i);
          } else if (_pilih.length < p.maksPilih) {
            _pilih.add(i);
          } else {
            showSnack(false, '', 'Maksimal ${p.maksPilih} pilihan.');
          }
        } else {
          _pilih
            ..clear()
            ..add(i);
        }
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Colors.green.shade700 : Colors.grey.shade300, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(
              ganda
                  ? (sel ? Icons.check_box : Icons.check_box_outline_blank)
                  : (sel ? Icons.radio_button_checked : Icons.radio_button_off),
              color: sel ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(p.opsi[i], style: const TextStyle(fontSize: 14.5))),
        ]),
      ),
    );
  }

  Widget _hasil(SuaraModel p, Set<int> milik) {
    final tot = p.hitung.values.fold<int>(0, (a, b) => a + b);
    var maks = 0;
    p.hitung.forEach((_, v) {
      if (v > maks) maks = v;
    });
    if (p.legacy) {
      return const Text('Topik lama ini dibuat sebelum fitur hasil terbaru, sehingga rincian suara tidak tersedia.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary));
    }
    return Column(children: [
      for (var i = 0; i < p.opsi.length; i++)
        Builder(builder: (_) {
          final v = p.hitung['$i'] ?? 0;
          final persen = tot == 0 ? 0.0 : v / tot;
          final menang = p.ditutup && v == maks && maks > 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.opsi[i] + (milik.contains(i) ? '  ✓ pilihan Anda' : ''),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: menang ? FontWeight.bold : FontWeight.w500)),
                ),
                if (menang) const Icon(Icons.emoji_events, size: 17, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${(persen * 100).round()}% · $v',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: persen,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  color: menang ? Colors.green.shade700 : Colors.green.shade300,
                ),
              ),
            ]),
          );
        }),
    ]);
  }

  Widget _perRw(SuaraModel p) {
    final e = p.perRw.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Partisipasi per RW (khusus perangkat desa)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        const SizedBox(height: 4),
        Wrap(spacing: 12, children: [
          for (final r in e) Text('RW ${r.key}: ${r.value}', style: const TextStyle(fontSize: 12.5)),
        ]),
      ]),
    );
  }

  Widget _diskusi(SuaraModel p, dynamic me) {
    final uid = me?.uid ?? '';
    return Column(children: [
      kartu(
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _komen,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Tulis pendapat Anda dengan sopan...', counterText: ''),
            ),
          ),
          IconButton(
              onPressed: () => _kirimKomen(p),
              icon: Icon(Icons.send, color: Colors.green.shade700)),
        ]),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ref.collection('komentar').orderBy('at', descending: true).limit(60).snapshots(),
        builder: (_, s) {
          final docs = s.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Belum ada komentar. Jadilah yang pertama.',
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
                        child: Text(
                            '${d.data()['nama'] ?? 'Warga'}${d.data()['role'] != null && d.data()['role'] != 'warga' ? ' · ${AppTheme.labelRole('${d.data()['role']}')}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    if ('${d.data()['uid']}' != uid)
                      InkWell(
                        onTap: () => laporkan(
                          tipe: 'komentar',
                          targetId: d.id,
                          targetUid: '${d.data()['uid']}',
                          targetNama: '${d.data()['nama'] ?? 'Warga'}',
                          cuplikan: '${d.data()['isi'] ?? ''}',
                          targetPath: 'polling/${p.id}/komentar/${d.id}',
                        ),
                        child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Text('Laporkan', style: TextStyle(fontSize: 11, color: Colors.red))),
                      ),
                  ]),
                  const SizedBox(height: 2),
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
// BUAT SUARA WARGA (perangkat desa)
// ─────────────────────────────────────────────────────────────
class BuatPollingView extends StatefulWidget {
  final String? usulanId; // bila berasal dari usulan warga
  final String? kategoriAwal;
  final String? pertanyaanAwal;
  final String? penjelasanAwal;
  final List<String>? opsiAwal;
  const BuatPollingView(
      {super.key, this.usulanId, this.kategoriAwal, this.pertanyaanAwal, this.penjelasanAwal, this.opsiAwal});

  @override
  State<BuatPollingView> createState() => _BuatPollingViewState();
}

class _BuatPollingViewState extends State<BuatPollingView> {
  final _tanya = TextEditingController();
  final _jelas = TextEditingController();
  final _sasaranTeks = TextEditingController();
  final List<TextEditingController> _opsi = [];
  String _kat = '';
  String _tipe = 'tunggal';
  int _maks = 2;
  String _sasaran = 'semua'; // semua | rw | dusun
  DateTime _tutup = DateTime.now().add(const Duration(days: 7));
  bool _hasilLangsung = true;
  List<File> _fotoBaru = [];
  bool _simpan = false;

  @override
  void initState() {
    super.initState();
    _kat = widget.kategoriAwal ?? '';
    _tanya.text = widget.pertanyaanAwal ?? '';
    _jelas.text = widget.penjelasanAwal ?? '';
    final o = widget.opsiAwal ?? const ['', ''];
    for (final x in (o.length < 2 ? ['', ''] : o)) {
      _opsi.add(TextEditingController(text: x));
    }
  }

  @override
  void dispose() {
    _tanya.dispose();
    _jelas.dispose();
    _sasaranTeks.dispose();
    for (final c in _opsi) {
      c.dispose();
    }
    super.dispose();
  }

  void _pakaiTemplate(TemplatePoll t) {
    setState(() {
      _kat = t.kategori;
      _tanya.text = t.pertanyaan;
      _jelas.text = t.penjelasan;
      _tipe = t.tipe;
      if (t.tipe == 'ganda') {
        final m = RegExp(r'maksimal (\d)').firstMatch(t.penjelasan);
        _maks = m != null ? int.parse(m.group(1)!) : 2;
      }
      for (final c in _opsi) {
        c.dispose();
      }
      _opsi
        ..clear()
        ..addAll(t.opsi.map((e) => TextEditingController(text: e)));
    });
  }

  Future<void> _pilihTutup() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _tutup,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 180)));
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_tutup));
    setState(() => _tutup = DateTime(d.year, d.month, d.day, t?.hour ?? 23, t?.minute ?? 59));
  }

  Future<void> _kirim() async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _simpan) return;
    if (_kat.isEmpty) {
      showSnack(false, '', 'Langkah 1: pilih kategori topik.');
      return;
    }
    if (_tanya.text.trim().length < 10) {
      showSnack(false, '', 'Langkah 2: tulis pertanyaan yang jelas (minimal 10 huruf).');
      return;
    }
    List<String> opsi;
    if (_tipe == 'setuju') {
      opsi = _opsiSetuju;
    } else if (_tipe == 'skala') {
      opsi = _opsiSkala;
    } else {
      opsi = _opsi.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
      if (opsi.length < 2) {
        showSnack(false, '', 'Langkah 3: isi minimal 2 pilihan jawaban.');
        return;
      }
    }
    if (_tipe == 'ganda' && (_maks < 2 || _maks > opsi.length)) {
      showSnack(false, '', 'Batas pilihan harus antara 2 dan jumlah jawaban.');
      return;
    }
    String sasaran = 'semua';
    if (_sasaran != 'semua') {
      final t = _sasaranTeks.text.trim();
      if (t.isEmpty) {
        showSnack(false, '', 'Langkah 4: isi nomor RW atau nama kampung sasaran.');
        return;
      }
      sasaran = _sasaran == 'rw' ? 'rw:${t.replaceAll(RegExp(r'[^0-9]'), '')}' : 'dusun:$t';
    }
    if (_tutup.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      showSnack(false, '', 'Batas waktu minimal 30 menit dari sekarang.');
      return;
    }
    setState(() => _simpan = true);
    try {
      final foto = <String>[];
      for (final f in _fotoBaru) {
        final e = await ImageUtil.encode(f);
        if (e != null) foto.add(e);
      }
      final ref = await FirebaseFirestore.instance.collection('polling').add({
        'pertanyaan': _tanya.text.trim(),
        'penjelasan': _jelas.text.trim(),
        'kategori': _kat,
        'tipe': _tipe,
        'opsi': opsi,
        'maks_pilih': _tipe == 'ganda' ? _maks : 1,
        'mulai': Timestamp.now(),
        'tutup': Timestamp.fromDate(_tutup),
        'sasaran': sasaran,
        'hasil_langsung': _hasilLangsung,
        'foto_list': foto,
        'dibuat_oleh': me.nama,
        'dibuat_uid': me.uid,
        'created_at': Timestamp.now(),
        'total': 0,
        'hitung': <String, dynamic>{},
        'per_rw': <String, dynamic>{},
      });
      if (widget.usulanId != null) {
        await FirebaseFirestore.instance.collection('usulan_polling').doc(widget.usulanId).update({
          'status': 'dijadikan',
          'poll_id': ref.id,
          'diputus_oleh': me.nama,
          'diputus_at': Timestamp.now(),
        });
      }
      await AuditLog.catat(aksi: 'Membuat suara warga', targetTipe: 'polling', targetId: ref.id, detail: _tanya.text.trim());
      await notifPeran(['warga'],
          judul: 'Suara Warga baru', isi: _tanya.text.trim(), tipe: 'info', targetId: ref.id);
      Get.back();
      showSnack(true, 'Suara Warga dibuka dan warga sudah diberi tahu.', '');
    } catch (e) {
      setState(() => _simpan = false);
      showSnack(false, '', 'Gagal membuat topik: $e');
    }
  }

  Widget _langkah(int n, String judul, String bantu) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: Colors.green.shade700,
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5))),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(bantu,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    final tp = tipePoll.firstWhere((t) => t.id == _tipe);
    final tetap = _tipe == 'setuju' || _tipe == 'skala';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Buat Suara Warga')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Text(
              'Isi 5 langkah. Mau cepat? Pilih satu CONTOH di bawah, isinya terisi otomatis dan bisa Anda ubah.',
              style: TextStyle(fontSize: 13, height: 1.4)),
        ),
        const SizedBox(height: 8),
        const Text('Contoh siap pakai', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(
          height: 112,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final t in templatePoll)
              InkWell(
                onTap: () => _pakaiTemplate(t),
                child: Container(
                  width: 190,
                  margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: katPoll(t.kategori).warna.withOpacity(0.5))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(katPoll(t.kategori).label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: katPoll(t.kategori).warna, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(t.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(t.pertanyaan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ]),
                ),
              ),
          ]),
        ),
        _langkah(1, 'Kategori topik', 'Pilih kelompok yang paling sesuai agar warga mudah mencari.'),
        Wrap(spacing: 6, children: [
          for (final k in kategoriPoll)
            ChoiceChip(
              avatar: Icon(k.ikon, size: 16, color: _kat == k.id ? Colors.white : k.warna),
              label: Text(k.label, style: TextStyle(fontSize: 12, color: _kat == k.id ? Colors.white : null)),
              selected: _kat == k.id,
              selectedColor: k.warna,
              showCheckmark: false,
              onSelected: (_) => setState(() => _kat = k.id),
            ),
        ]),
        if (_kat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Contoh topik: ${katPoll(_kat).contoh}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        _langkah(2, 'Pertanyaan dan penjelasan',
            'Tulis pertanyaan yang singkat dan mudah dipahami, lalu jelaskan latar belakangnya agar warga memilih dengan paham.'),
        TextField(
          controller: _tanya,
          maxLines: 2,
          maxLength: 150,
          decoration: const InputDecoration(
              labelText: 'Pertanyaan',
              hintText: 'Contoh: Jalan mana yang paling perlu diperbaiki lebih dulu?'),
        ),
        TextField(
          controller: _jelas,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
              labelText: 'Penjelasan (disarankan)',
              hintText: 'Contoh: Dana terbatas sehingga perbaikan dilakukan bertahap. Pilih satu yang paling mendesak.'),
        ),
        _langkah(3, 'Jenis jawaban', tp.bantu),
        Wrap(spacing: 6, children: [
          for (final t in tipePoll)
            ChoiceChip(
              label: Text(t.label, style: const TextStyle(fontSize: 12)),
              selected: _tipe == t.id,
              onSelected: (_) => setState(() => _tipe = t.id),
            ),
        ]),
        const SizedBox(height: 8),
        if (tetap)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Text(
                'Pilihan jawaban otomatis: ${(_tipe == 'setuju' ? _opsiSetuju : _opsiSkala).join(' · ')}',
                style: const TextStyle(fontSize: 12.5)),
          )
        else ...[
          for (var i = 0; i < _opsi.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _opsi[i],
                    maxLength: 80,
                    decoration: InputDecoration(
                        labelText: 'Jawaban ${i + 1}', counterText: '', hintText: 'Contoh: Gang menuju sekolah'),
                  ),
                ),
                IconButton(
                  onPressed: _opsi.length <= 2
                      ? null
                      : () => setState(() => _opsi.removeAt(i).dispose()),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ]),
            ),
          if (_opsi.length < 8)
            TextButton.icon(
              onPressed: () => setState(() => _opsi.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah jawaban'),
            ),
          if (_tipe == 'ganda')
            Row(children: [
              const Text('Boleh pilih maksimal '),
              DropdownButton<int>(
                value: _maks.clamp(2, 8),
                items: [for (var i = 2; i <= 8; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                onChanged: (v) => setState(() => _maks = v ?? 2),
              ),
              const Text(' jawaban'),
            ]),
        ],
        _langkah(4, 'Sasaran dan waktu',
            'Pilih siapa yang boleh memilih dan kapan ditutup. Semua warga tetap bisa melihat dan berkomentar.'),
        Wrap(spacing: 6, children: [
          for (final e in const [
            ['semua', 'Seluruh warga'],
            ['rw', 'RW tertentu'],
            ['dusun', 'Kampung tertentu']
          ])
            ChoiceChip(
              label: Text(e[1], style: const TextStyle(fontSize: 12)),
              selected: _sasaran == e[0],
              onSelected: (_) => setState(() => _sasaran = e[0]),
            ),
        ]),
        if (_sasaran != 'semua')
          TextField(
            controller: _sasaranTeks,
            keyboardType: _sasaran == 'rw' ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
                labelText: _sasaran == 'rw' ? 'Nomor RW' : 'Nama kampung',
                hintText: _sasaran == 'rw' ? 'Contoh: 3' : 'Contoh: Talagasari Kidul'),
          ),
        const SizedBox(height: 10),
        const Text('Ditutup dalam', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, children: [
          for (final d in const [1, 3, 7, 14, 30])
            ActionChip(
              label: Text('$d hari', style: const TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _tutup = DateTime.now().add(Duration(days: d))),
            ),
        ]),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
          onPressed: _pilihTutup,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text('Tutup: ${AppUtils.formatTanggalWaktu(_tutup)}'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasilLangsung,
          onChanged: (v) => setState(() => _hasilLangsung = v),
          title: const Text('Hasil terlihat langsung', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
              _hasilLangsung
                  ? 'Warga yang sudah memilih bisa melihat hasil sementara.'
                  : 'Hasil disembunyikan sampai topik ditutup (mencegah warga ikut-ikutan).',
              style: const TextStyle(fontSize: 12)),
        ),
        _langkah(5, 'Foto pendukung (opsional)', 'Misalnya foto jalan rusak atau denah lokasi. Maksimal 3.'),
        FotoPicker(
          maks: 3,
          label: 'Foto pendukung',
          onChanged: (baru, lama) => _fotoBaru = baru,
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52)),
          onPressed: _simpan ? null : _kirim,
          icon: const Icon(Icons.how_to_vote, color: Colors.white),
          label: Text(_simpan ? 'Membuka...' : 'Buka Suara Warga'),
        ),
        const SizedBox(height: 6),
        const Text('Setelah dibuka, pertanyaan dan jawaban tidak dapat diubah. Seluruh warga akan mendapat notifikasi.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USULAN TOPIK DARI WARGA
// ─────────────────────────────────────────────────────────────
class UsulPollView extends StatefulWidget {
  const UsulPollView({super.key});

  @override
  State<UsulPollView> createState() => _UsulPollViewState();
}

class _UsulPollViewState extends State<UsulPollView> {
  String _kat = '';
  final _tanya = TextEditingController();
  final _alasan = TextEditingController();
  final _opsi = TextEditingController();
  bool _kirim = false;

  @override
  void dispose() {
    _tanya.dispose();
    _alasan.dispose();
    _opsi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null || _kirim) return;
    if (_kat.isEmpty) {
      showSnack(false, '', 'Pilih kategori dulu.');
      return;
    }
    if (_tanya.text.trim().length < 10) {
      showSnack(false, '', 'Tulis pertanyaan yang jelas (minimal 10 huruf).');
      return;
    }
    if (_alasan.text.trim().length < 15) {
      showSnack(false, '', 'Jelaskan alasan topik ini penting (minimal 15 huruf).');
      return;
    }
    setState(() => _kirim = true);
    try {
      await FirebaseFirestore.instance.collection('usulan_polling').add({
        'uid': me.uid,
        'nama': me.nama,
        'kategori': _kat,
        'pertanyaan': _tanya.text.trim(),
        'alasan': _alasan.text.trim(),
        'opsi_saran': _opsi.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(8)
            .toList(),
        'status': 'baru',
        'created_at': Timestamp.now(),
      });
      await notifPeran(['admin', 'kades'],
          judul: 'Usulan topik dari warga', isi: _tanya.text.trim(), tipe: 'info');
      Get.back();
      showSnack(true, 'Usulan terkirim. Perangkat desa akan menilai.', '');
    } catch (_) {
      setState(() => _kirim = false);
      showSnack(false, '', 'Gagal mengirim usulan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Usulkan Topik')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Text(
              'Punya hal yang perlu dimusyawarahkan warga? Tulis di sini. Contoh: "Setujukah lampu jalan dipasang di Gang Mawar?" dengan alasan "Gang gelap, rawan kejahatan".',
              style: TextStyle(fontSize: 13, height: 1.4)),
        ),
        const SizedBox(height: 12),
        const Text('1. Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 6, children: [
          for (final k in kategoriPoll)
            ChoiceChip(
              label: Text(k.label, style: TextStyle(fontSize: 12, color: _kat == k.id ? Colors.white : null)),
              selected: _kat == k.id,
              selectedColor: k.warna,
              showCheckmark: false,
              onSelected: (_) => setState(() => _kat = k.id),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _tanya,
          maxLines: 2,
          maxLength: 150,
          decoration: const InputDecoration(
              labelText: '2. Pertanyaan yang diusulkan',
              hintText: 'Contoh: Setujukah lampu jalan dipasang di Gang Mawar?'),
        ),
        TextField(
          controller: _alasan,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
              labelText: '3. Alasan topik ini penting',
              hintText: 'Contoh: Gang gelap dan sudah dua kali ada kehilangan motor.'),
        ),
        TextField(
          controller: _opsi,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: '4. Saran pilihan jawaban (opsional, satu baris satu)',
              hintText: 'Setuju\nTidak setuju'),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52)),
          onPressed: _kirim ? null : _simpan,
          icon: const Icon(Icons.send, color: Colors.white),
          label: Text(_kirim ? 'Mengirim...' : 'Kirim usulan'),
        ),
      ]),
    );
  }
}

class _UsulanTab extends StatelessWidget {
  final bool staf;
  const _UsulanTab({required this.staf});

  Future<void> _tolak(DocumentSnapshot<Map<String, dynamic>> d) async {
    final c = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Tolak usulan'),
      content: TextField(
        controller: c,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Alasan (wajib)'),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
            onPressed: () {
              if (c.text.trim().length < 10) {
                showSnack(false, '', 'Alasan minimal 10 huruf.');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Tolak')),
      ],
    ));
    if (ok != true) return;
    final me = Get.find<AuthController>().currentUser.value;
    try {
      await d.reference.update({
        'status': 'ditolak',
        'alasan_tolak': c.text.trim(),
        'diputus_oleh': me?.nama ?? '',
        'diputus_at': Timestamp.now(),
      });
      showSnack(true, 'Usulan ditolak.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '';
    final col = FirebaseFirestore.instance.collection('usulan_polling');
    final Query<Map<String, dynamic>> q =
        staf ? col.orderBy('created_at', descending: true).limit(100) : col.where('uid', isEqualTo: uid).limit(50);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
              icon: Icons.error_outline,
              title: 'Tidak dapat memuat',
              subtitle: 'Periksa koneksi internet.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return EmptyState(
              icon: Icons.lightbulb_outline,
              title: staf ? 'Belum ada usulan warga' : 'Anda belum mengusulkan topik',
              subtitle: staf
                  ? 'Usulan topik dari warga akan muncul di sini.'
                  : 'Tekan "Usulkan Topik" untuk menyampaikan hal yang perlu dimusyawarahkan.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 90),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final st = '${m['status']}';
            final k = katPoll('${m['kategori']}');
            final warna = st == 'baru'
                ? Colors.orange
                : st == 'ditolak'
                    ? Colors.red
                    : Colors.green;
            return kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(k.ikon, size: 16, color: k.warna),
                  const SizedBox(width: 4),
                  Expanded(child: Text(k.label, style: TextStyle(fontSize: 11.5, color: k.warna, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(8)),
                    child: Text(st == 'baru' ? 'MENUNGGU' : st == 'ditolak' ? 'DITOLAK' : 'DIJADIKAN SUARA',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('${m['pertanyaan']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text('Alasan: ${m['alasan']}', style: const TextStyle(fontSize: 12.5)),
                if (staf)
                  Text('Oleh ${m['nama']}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                if (st == 'ditolak')
                  Text('Alasan penolakan: ${m['alasan_tolak']}',
                      style: TextStyle(fontSize: 12.5, color: Colors.red.shade800)),
                if (st == 'dijadikan' && m['poll_id'] != null)
                  TextButton(
                      onPressed: () => Get.to(() => PollDetailView(id: '${m['poll_id']}')),
                      child: const Text('Lihat topiknya')),
                if (staf && st == 'baru')
                  Row(children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => Get.to(() => BuatPollingView(
                            usulanId: d.id,
                            kategoriAwal: '${m['kategori']}',
                            pertanyaanAwal: '${m['pertanyaan']}',
                            penjelasanAwal: '${m['alasan']}',
                            opsiAwal: (m['opsi_saran'] is List && (m['opsi_saran'] as List).length >= 2)
                                ? (m['opsi_saran'] as List).map((e) => '$e').toList()
                                : null,
                          )),
                      child: const Text('Jadikan Suara Warga'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: Colors.red),
                      onPressed: () => _tolak(d),
                      child: const Text('Tolak'),
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
