// ============================================================
// letter_view.dart — Surat Online
//   Warga : LetterHomeView (daftar + ajukan + unduh PDF)
//   Admin : cek berkas → teruskan ke Kades
//   Kades : setujui → surat terbit (PDF siap tanda tangan basah)
//   Staf  : CekSuratView (cek keaslian dari kode surat)
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../controllers/auth_controller.dart';
import '../controllers/complaint_controller.dart';
import '../controllers/village_controller.dart';
import '../core/app_contact.dart';
import '../core/core.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'verification_view.dart' show wajibVerifikasi;

// ─────────────────────────────────────────────────────────────
// PDF surat
// ─────────────────────────────────────────────────────────────
Future<Uint8List> buatPdfSurat(LetterModel l) async {
  final doc = pw.Document();
  final String ttl =
      '${l.tempatLahir.isNotEmpty ? '${l.tempatLahir}, ' : ''}${l.tanggalLahir != null ? AppUtils.formatTanggal(l.tanggalLahir!) : '-'}';
  final String jk = l.jenisKelamin == 'laki-laki'
      ? 'Laki-laki'
      : (l.jenisKelamin == 'perempuan' ? 'Perempuan' : '-');
  String isi(String v) => v.trim().isEmpty ? '-' : v.trim();

  pw.Widget baris(String no, String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 18, child: pw.Text(no)),
            pw.SizedBox(width: 118, child: pw.Text(k)),
            pw.Text(': '),
            pw.Expanded(child: pw.Text(v)),
          ],
        ),
      );

  final pw.TextStyle tebal = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  const pw.TextStyle kecil = pw.TextStyle(fontSize: 8);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(54, 40, 54, 44),
      theme: pw.ThemeData.withFont(),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                  'Kode surat: ${l.kode}  |  Dibuat lewat aplikasi Halodesa Talagasari. '
                  'Keaslian dapat dicek petugas desa dengan memasukkan kode surat.',
                  style: kecil),
            ),
            pw.Text('Hal. ${ctx.pageNumber}/${ctx.pagesCount}', style: kecil),
          ],
        ),
      ),
      build: (_) => [
        pw.Center(
          child: pw.Column(children: [
            pw.Text(AppContact.kopPemerintah.toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(AppContact.kopKecamatan.toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(AppContact.kopDesa.toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(AppContact.kopAlamat, style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 2.2, height: 3),
        pw.Divider(thickness: 0.6, height: 3),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Text(LetterModel.labelJenis(l.jenis).toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline)),
        ),
        pw.Center(child: pw.Text('Nomor: ${l.nomor}')),
        pw.SizedBox(height: 16),
        pw.Text(
            'Yang bertanda tangan di bawah ini, Kepala Desa Talagasari, Kecamatan Cikupa, '
            'Kabupaten Tangerang, menerangkan dengan sebenarnya bahwa:',
            textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 8),
        baris('1.', 'Nama Lengkap', l.nama),
        baris('2.', 'NIK', isi(l.nik)),
        baris('3.', 'Tempat/Tgl Lahir', ttl),
        baris('4.', 'Jenis Kelamin', jk),
        baris('5.', 'Kewarganegaraan', 'Indonesia (WNI)'),
        baris('6.', 'Agama', isi(l.t('agama'))),
        baris('7.', 'Status Perkawinan', isi(l.t('status_kawin'))),
        baris('8.', 'Pekerjaan', isi(l.t('pekerjaan'))),
        baris('9.', 'Alamat', isi(l.alamat)),
        pw.SizedBox(height: 10),
        pw.Text(LetterModel.isiSurat(l.jenis, l.tambahan),
            textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 8),
        pw.Text('Surat keterangan ini dibuat untuk keperluan:'),
        pw.SizedBox(height: 2),
        pw.Text(l.keperluan, style: tebal, textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 10),
        pw.Text(
            'Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan '
            'sebagaimana mestinya. Pemohon menyatakan bahwa data dalam surat ini benar '
            'dan bersedia mempertanggungjawabkannya sesuai ketentuan yang berlaku.',
            textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 6),
        pw.Text(
            'Surat ini berlaku ${LetterModel.masaBulan(l.jenis)} bulan sejak tanggal ditandatangani.',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(children: [
                pw.Text(''),
                pw.Text('Pemohon,'),
                pw.SizedBox(height: 62),
                pw.Text('( ${l.nama} )', style: tebal, textAlign: pw.TextAlign.center),
                pw.Text('Tanda tangan pemohon', style: kecil),
              ]),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Center(
                child: pw.Container(
                  width: 57,
                  height: 76,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                  child: pw.Text('Pas foto\n3 x 4',
                      textAlign: pw.TextAlign.center, style: kecil),
                ),
              ),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Column(children: [
                pw.Text('Talagasari, ............................'),
                pw.Text('Kepala Desa Talagasari,'),
                pw.SizedBox(height: 62), // ruang tanda tangan basah + stempel
                pw.Text('( ${l.penandatangan} )', style: tebal),
                pw.Text('Tanda tangan dan stempel', style: kecil),
              ]),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

// ─────────────────────────────────────────────────────────────
// Beranda surat (tarik ke bawah untuk memuat ulang)
// ─────────────────────────────────────────────────────────────
class LetterHomeView extends StatefulWidget {
  const LetterHomeView({super.key});

  @override
  State<LetterHomeView> createState() => _LetterHomeViewState();
}

class _LetterHomeViewState extends State<LetterHomeView> {
  final LetterController _ctrl = Get.find<LetterController>();
  final AuthController _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    if (_auth.isStaff) {
      await _ctrl.fetchAntrian();
    } else {
      await _ctrl.fetchMine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final bool staf = _auth.isStaff;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(staf ? 'letter_queue'.tr : 'letter_title'.tr),
        backgroundColor: primary,
        actions: [
          if (staf)
            IconButton(
              tooltip: 'hub_check_letter'.tr,
              icon: const Icon(Icons.verified_outlined),
              onPressed: () => Get.to(() => const CekSuratView()),
            ),
        ],
      ),
      floatingActionButton: staf
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: () => _ajukan(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('letter_request'.tr,
                  style: const TextStyle(color: Colors.white)),
            ),
      body: Obx(() {
        final list = staf ? _ctrl.antrian : _ctrl.mine;
        if (_ctrl.isLoading.value && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _muat,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            children: [
              if (!staf) _PanduanBeranda(onPilih: _ajukan, warna: primary),
              if (!staf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Surat saya',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                ),
              if (list.isEmpty && staf) ...[
                const SizedBox(height: 80),
                EmptyState(
                    icon: Icons.description_outlined,
                    title: 'letter_empty'.tr,
                    subtitle: 'letter_empty_staff'.tr),
              ],
              if (list.isEmpty && !staf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                      'Belum ada surat. Pilih jenis surat di atas lalu tekan "Ajukan Surat".',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.textSecondary)),
                ),
              ...list.map((l) => _kartuSurat(l, staf)),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _ajukan([String jenis = 'domisili']) async {
    if (!await wajibVerifikasi()) return;
    await Get.to(() => AjukanSuratView(jenisAwal: jenis));
    _muat();
  }

  Widget _kartuSurat(LetterModel l, bool staf) {
    final bool kad = l.kadaluarsa;
    final Color w =
        kad ? Colors.red.shade700 : LetterModel.warnaStatus(l.status);
    return InkWell(
      onTap: () async {
        await Get.to(() => LetterDetailView(letter: l));
        _muat();
      },
      child: kartu(
        child: Row(
          children: [
            Icon(LetterModel.panduan(l.jenis).ikon, color: w),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(LetterModel.labelJenis(l.jenis),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      '${staf ? '${l.nama} • ' : ''}${AppUtils.formatRelatif(l.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            StatusBadge(
                text: kad ? 'letter_expired'.tr : LetterModel.labelStatus(l.status),
                color: w),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Panduan di beranda surat: apa itu surat online, cara kerja,
// dan pilihan surat lengkap dengan kegunaannya.
// ─────────────────────────────────────────────────────────────
class _PanduanBeranda extends StatelessWidget {
  final void Function(String jenis) onPilih;
  final Color warna;
  const _PanduanBeranda({required this.onPilih, required this.warna});

  @override
  Widget build(BuildContext context) {
    const langkah = [
      'Pilih surat & isi keperluan',
      'Admin desa memeriksa data',
      'Kepala Desa menyetujui',
      'Cetak PDF, tanda tangan di kantor desa',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline, color: warna),
                const SizedBox(width: 8),
                const Text('Apa itu Surat Online?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Anda bisa mengajukan surat keterangan dari desa lewat HP, tanpa antre di kantor. '
                  'Surat dicetak sendiri lalu cukup ditandatangani Kepala Desa di kantor desa.',
                  style: TextStyle(fontSize: 13, height: 1.45)),
              const SizedBox(height: 12),
              for (int i = 0; i < langkah.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 11,
                        backgroundColor: warna,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(langkah[i],
                            style: const TextStyle(fontSize: 12.5))),
                  ]),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Pilih surat yang Anda butuhkan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        for (final j in LetterModel.daftarJenis)
          InkWell(
            onTap: () => onPilih(j['value']!),
            child: kartu(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: warna.withOpacity(0.12),
                    child: Icon(LetterModel.panduan(j['value']!).ikon, color: warna),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j['label']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(LetterModel.panduan(j['value']!).singkat,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text(
                            'Contoh: ${LetterModel.panduan(j['value']!).untuk.first}',
                            style: const TextStyle(fontSize: 12, height: 1.35)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Form pengajuan berpanduan: pilih surat → baca kegunaannya →
// isi keperluan (ada contoh) → cek data → lihat pratinjau → kirim.
// ─────────────────────────────────────────────────────────────
class AjukanSuratView extends StatefulWidget {
  final String jenisAwal;
  const AjukanSuratView({super.key, this.jenisAwal = 'domisili'});

  @override
  State<AjukanSuratView> createState() => _AjukanSuratViewState();
}

class _AjukanSuratViewState extends State<AjukanSuratView> {
  final LetterController _ctrl = Get.find<LetterController>();
  final AuthController _auth = Get.find<AuthController>();
  final _keperluanCtrl = TextEditingController();
  late String _jenis;
  String _agama = '';
  String _kawin = '';
  final Map<String, TextEditingController> _f = {};

  static const List<String> _daftarAgama = [
    'Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'
  ];
  static const List<String> _daftarKawin = [
    'Belum Kawin', 'Kawin', 'Cerai Hidup', 'Cerai Mati'
  ];

  TextEditingController _c(String k) =>
      _f.putIfAbsent(k, () => TextEditingController()..addListener(() => setState(() {})));

  Map<String, String> _tambahan() => {
        'agama': _agama,
        'status_kawin': _kawin,
        for (final k in ['pekerjaan', 'tinggal_sejak', 'penghasilan', 'tanggungan',
          'nama_usaha', 'jenis_usaha', 'alamat_usaha', 'lama_usaha', 'instansi'])
          if (_f[k] != null) k: _f[k]!.text.trim(),
      };

  /// Pesan galat bila data wajib belum lengkap, null bila lengkap.
  String? _cekWajib() {
    final t = _tambahan();
    String v(String k) => t[k] ?? '';
    if (_agama.isEmpty) return 'Pilih agama Anda.';
    if (_kawin.isEmpty) return 'Pilih status perkawinan Anda.';
    if (v('pekerjaan').length < 3) return 'Isi pekerjaan Anda (contoh: Pelajar/Mahasiswa, Karyawan Swasta, Wiraswasta, Belum Bekerja).';
    switch (_jenis) {
      case 'tidak_mampu':
        if (v('penghasilan').isEmpty) return 'Isi penghasilan per bulan (angka saja, isi 0 bila tidak ada).';
        if (v('tanggungan').isEmpty) return 'Isi jumlah tanggungan keluarga.';
        break;
      case 'usaha':
        if (v('nama_usaha').length < 3) return 'Isi nama usaha.';
        if (v('jenis_usaha').length < 3) return 'Isi jenis usaha (contoh: warung makan).';
        break;
      case 'pengantar':
        if (v('instansi').length < 3) return 'Isi instansi tujuan (contoh: Polres Metro Tangerang).';
        break;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _jenis = widget.jenisAwal;
    _keperluanCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    _keperluanCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (_keperluanCtrl.text.trim().length < 10) {
      showSnack(false, '',
          'Keperluan terlalu singkat. Tulis tujuan dan tempat surat dipakai (minimal 10 huruf). Lihat contoh di atas kolom.');
      return;
    }
    final galat = _cekWajib();
    if (galat != null) {
      showSnack(false, '', galat);
      return;
    }
    final ok = await _ctrl.ajukan(
        jenis: _jenis,
        keperluan: _keperluanCtrl.text.trim(),
        tambahan: _tambahan());
    if (ok) Get.back();
    showSnack(ok, 'letter_sent'.tr, _ctrl.errorMsg.value);
  }

  void _isiContoh(String teks) {
    _keperluanCtrl.text = teks;
    _keperluanCtrl.selection = TextSelection.collapsed(offset: teks.length);
  }

  Future<void> _lihatContoh(PanduanSurat g) async {
    final pakai = await Get.dialog<bool>(AlertDialog(
      title: const Text('Contoh isian lengkap'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200)),
            child: Text(g.contohIsian, style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 10),
          Text('Tips: ${g.tips}',
              style: const TextStyle(fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 6),
          const Text('Ini hanya contoh. Ganti dengan keperluan Anda yang sebenarnya.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Tutup')),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Pakai contoh ini')),
      ],
    ));
    if (pakai == true) _isiContoh(g.contohIsian);
  }

  Widget _judul(String no, String teks, Color warna) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Row(children: [
          CircleAvatar(
              radius: 12,
              backgroundColor: warna,
              child: Text(no,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(teks,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _butir(List<String> isi, IconData ikon, Color warna) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in isi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ikon, size: 16, color: warna),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(t,
                          style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final u = _auth.currentUser.value;
    final ktp = Get.find<ComplaintController>().myKtp.value;
    final PanduanSurat g = LetterModel.panduan(_jenis);
    final int masa = LetterModel.masaBulan(_jenis);
    final String keperluan = _keperluanCtrl.text.trim();
    final bool dataKurang = ktp.nik.isEmpty || (u?.alamatLengkap ?? '').isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('letter_request'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul('1', 'Pilih surat yang Anda butuhkan', primary),
            for (final j in LetterModel.daftarJenis)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _jenis = j['value']!),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _jenis == j['value']
                          ? primary.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _jenis == j['value']
                              ? primary
                              : Colors.grey.shade300,
                          width: _jenis == j['value'] ? 1.8 : 1),
                    ),
                    child: Row(children: [
                      Icon(LetterModel.panduan(j['value']!).ikon,
                          color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(j['label']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(LetterModel.panduan(j['value']!).singkat,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (_jenis == j['value'])
                        Icon(Icons.check_circle, color: primary),
                    ]),
                  ),
                ),
              ),

            kartu(
              margin: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Surat ini cocok untuk:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _butir(g.untuk, Icons.check, primary),
                  const SizedBox(height: 12),
                  const Text('Yang perlu disiapkan:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _butir(g.siapkan, Icons.arrow_right, primary),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'Setelah ditandatangani, surat berlaku $masa bulan.',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary))),
                  ]),
                ],
              ),
            ),

            _judul('2', 'Tulis keperluan Anda', primary),
            const Text('Ketuk salah satu contoh untuk mengisi otomatis, lalu ubah sesuai kebutuhan:',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final c in g.contohKeperluan)
                  ActionChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _isiContoh(c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keperluanCtrl,
              maxLines: 3,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: 'letter_purpose'.tr,
                hintText: 'Contoh: ${g.contohIsian}',
                hintMaxLines: 3,
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _lihatContoh(g),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Lihat contoh isian lengkap'),
              ),
            ),

            _judul('3', 'Lengkapi data surat', primary),
            const Text('Data ini dicetak di surat. Isi sesuai KTP/keadaan sebenarnya.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            _pilih('Agama', _agama, _daftarAgama, (v) => setState(() => _agama = v)),
            _pilih('Status perkawinan', _kawin, _daftarKawin,
                (v) => setState(() => _kawin = v)),
            _isian('pekerjaan', 'Pekerjaan', 'Contoh: Pelajar/Mahasiswa'),
            if (_jenis == 'domisili')
              _isian('tinggal_sejak', 'Tinggal di desa sejak tahun (opsional)',
                  'Contoh: 2015', angka: true, maks: 4),
            if (_jenis == 'tidak_mampu') ...[
              _isian('penghasilan', 'Penghasilan keluarga per bulan (Rp)',
                  'Angka saja, contoh: 1500000', angka: true, maks: 10),
              _isian('tanggungan', 'Jumlah tanggungan keluarga (orang)',
                  'Contoh: 4', angka: true, maks: 2),
            ],
            if (_jenis == 'usaha') ...[
              _isian('nama_usaha', 'Nama usaha', 'Contoh: Warung Bu Sari'),
              _isian('jenis_usaha', 'Jenis usaha', 'Contoh: warung makan'),
              _isian('alamat_usaha', 'Alamat usaha (opsional)',
                  'Kosongkan bila sama dengan alamat rumah'),
              _isian('lama_usaha', 'Lama usaha (opsional)', 'Contoh: 2 tahun'),
            ],
            if (_jenis == 'pengantar')
              _isian('instansi', 'Instansi tujuan',
                  'Contoh: Polres Metro Tangerang'),

            _judul('4', 'Cek data Anda', primary),
            Text('letter_auto'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            kartu(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info('profile_name'.tr, u?.nama ?? '-'),
                  _info('NIK', ktp.nik.isEmpty ? '-' : ktp.nik),
                  _info('addr_full'.tr,
                      (u?.alamatLengkap ?? '').isEmpty ? '-' : u!.alamatLengkap),
                ],
              ),
            ),
            if (dataKurang)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Ada data yang masih kosong ("-"). Lengkapi lewat Akun → Verifikasi Identitas / Alamat agar surat tidak ditolak.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
              ),

            _judul('5', 'Begini bunyi surat Anda nanti', primary),
            kartu(
              child: Text(
                'Yang bertanda tangan di bawah ini, Kepala Desa Talagasari, menerangkan bahwa '
                '${u?.nama ?? '(nama Anda)'} (${_agama.isEmpty ? 'agama' : _agama}, '
                '${_kawin.isEmpty ? 'status kawin' : _kawin}, '
                '${_c('pekerjaan').text.trim().isEmpty ? 'pekerjaan' : _c('pekerjaan').text.trim()}).\n\n'
                '${LetterModel.isiSurat(_jenis, _tambahan())}\n\n'
                'Dibuat untuk keperluan: ${keperluan.isEmpty ? '(belum diisi)' : keperluan}',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const Text('Surat ini baru sah setelah ditandatangani Kepala Desa di kantor desa.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),

            const SizedBox(height: 20),
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                    child: _ctrl.isSubmitting.value
                        ? loadingChild()
                        : Text('cmp_send'.tr),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _pilih(String label, String nilai, List<String> opsi, void Function(String) ubah) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          value: nilai.isEmpty ? null : nilai,
          decoration: InputDecoration(
              labelText: label, filled: true, fillColor: Colors.white),
          items: [for (final o in opsi) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) {
            if (v != null) ubah(v);
          },
        ),
      );

  Widget _isian(String k, String label, String hint,
          {bool angka = false, int maks = 60}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _c(k),
          maxLength: maks,
          keyboardType: angka ? TextInputType.number : TextInputType.text,
          inputFormatters: angka ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              counterText: '',
              filled: true,
              fillColor: Colors.white),
        ),
      );

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Detail surat + aksi
// ─────────────────────────────────────────────────────────────
class LetterDetailView extends StatelessWidget {
  final LetterModel letter;
  const LetterDetailView({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final ctrl = Get.find<LetterController>();
    final l = letter;
    final String role = auth.role;
    final Color primary = AppTheme.primaryColor(role);
    final bool adminReview = role == 'admin' && l.status == 'menunggu_review';
    final bool kadesReview = role == 'kades' && l.status == 'pending_kades';
    final bool adminTtd = role == 'admin' && l.menungguTtd;
    final Color w = l.kadaluarsa
        ? Colors.red.shade700
        : LetterModel.warnaStatus(l.status);

    Widget baris(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 100,
                  child: Text(k,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('letter_detail'.tr), backgroundColor: primary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(LetterModel.labelJenis(l.jenis),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              StatusBadge(
                  text: l.kadaluarsa
                      ? 'letter_expired'.tr
                      : LetterModel.labelStatus(l.status),
                  color: w),
            ],
          ),
          const SizedBox(height: 12),
          kartu(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                baris('profile_name'.tr, l.nama),
                baris('NIK', l.nik),
                baris('addr_full'.tr, l.alamat),
                baris('letter_purpose'.tr, l.keperluan),
                for (final e in LetterModel.labelTambahan.entries)
                  if (l.t(e.key).isNotEmpty)
                    baris(e.value, e.key == 'penghasilan' ? LetterModel.rupiah(l.t(e.key)) : l.t(e.key)),
                if (l.bisaCetak) baris('letter_number'.tr, l.nomor),
                if (l.bisaCetak) baris('letter_code'.tr, l.kode),
                if (l.sah && l.berlakuSampai != null)
                  baris('letter_valid_until'.tr,
                      AppUtils.formatTanggal(l.berlakuSampai!)),
              ],
            ),
          ),
          if (l.menungguTtd)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('letter_sign_info'.tr,
                  style: TextStyle(color: Colors.blue.shade800, height: 1.4)),
            ),
          if (l.status == 'ditolak' && (l.alasan ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${'cmp_reason'.tr}: ${l.alasan}',
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 20),
          if (l.bisaCetak && !l.kadaluarsa)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final bytes = await buatPdfSurat(l);
                  await Printing.layoutPdf(
                      name: 'Surat_${l.nomor.replaceAll('/', '-')}',
                      onLayout: (_) async => bytes);
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: Text('letter_pdf'.tr,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          if (adminTtd) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await ctrl.tandaiDitandatangani(l);
                  if (ok) Get.back();
                  showSnack(ok, 'letter_signed_ok'.tr, ctrl.errorMsg.value);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
                icon: const Icon(Icons.draw_outlined, color: Colors.white),
                label: Text('letter_mark_signed'.tr,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
          if (adminReview || kadesReview)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final a = await pilihAlasanTolak('surat',
                          judul: 'Tolak pengajuan surat');
                      if (a == null) return;
                      final ok = await ctrl.tolak(l, a);
                      if (ok) Get.back();
                      showSnack(ok, 'cmp_rejected_ok'.tr, ctrl.errorMsg.value);
                    },
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                    child: Text('cmp_reject'.tr,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = adminReview
                          ? await ctrl.teruskanKeKades(l)
                          : await ctrl.terbitkan(l);
                      if (ok) Get.back();
                      showSnack(ok, 'letter_done_ok'.tr, ctrl.errorMsg.value);
                    },
                    child: Text(
                        adminReview ? 'letter_forward'.tr : 'letter_issue'.tr,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cek keaslian surat — khusus Admin & Kades (dibuka dari halaman surat)
// ─────────────────────────────────────────────────────────────
class CekSuratView extends StatefulWidget {
  const CekSuratView({super.key});

  @override
  State<CekSuratView> createState() => _CekSuratViewState();
}

class _CekSuratViewState extends State<CekSuratView> {
  final _kodeCtrl = TextEditingController();
  Map<String, dynamic>? _hasil;
  bool _sudahCek = false;
  bool _loading = false;

  @override
  void dispose() {
    _kodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cek() async {
    if (_kodeCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final h = await Get.find<LetterController>().cekKode(_kodeCtrl.text);
    if (!mounted) return;
    setState(() {
      _hasil = h;
      _sudahCek = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primary =
        AppTheme.primaryColor(Get.find<AuthController>().role);
    final h = _hasil;
    final DateTime? sampai = (h?['berlaku_sampai'] as Timestamp?)?.toDate();
    final bool sah = h?['status'] == 'sah';
    final bool kadaluarsa =
        sah && sampai != null && DateTime.now().isAfter(sampai);

    String judul = 'letter_real'.tr;
    String sub = '';
    Color warna = Colors.green.shade700;
    IconData ikon = Icons.verified;
    if (h != null && !sah) {
      judul = 'letter_not_signed'.tr;
      warna = Colors.orange.shade800;
      ikon = Icons.hourglass_top;
    } else if (kadaluarsa) {
      judul = 'letter_expired'.tr.toUpperCase();
      warna = Colors.red.shade700;
      ikon = Icons.event_busy;
      sub = '${'letter_valid_until'.tr}: ${AppUtils.formatTanggal(sampai)}';
    } else if (sah && sampai != null) {
      sub = '${'letter_valid_until'.tr}: ${AppUtils.formatTanggal(sampai)}';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('hub_check_letter'.tr), backgroundColor: primary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('letter_check_info'.tr,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _kodeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'letter_code'.tr),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _cek,
              child: _loading ? loadingChild() : Text('letter_check'.tr),
            ),
          ),
          const SizedBox(height: 16),
          if (_sudahCek && h == null)
            kartu(
              margin: EdgeInsets.zero,
              child: Row(children: [
                Icon(Icons.cancel, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text('letter_fake'.tr)),
              ]),
            ),
          if (h != null)
            kartu(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(ikon, color: warna),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(judul,
                          style: TextStyle(
                              color: warna, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(sub, style: TextStyle(color: warna)),
                    ),
                  const SizedBox(height: 10),
                  Text('${h['jenis'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${'letter_number'.tr}: ${h['nomor'] ?? ''}'),
                  Text('${'profile_name'.tr}: ${h['nama_samar'] ?? ''}'),
                  Text('${'letter_signer'.tr}: ${h['penandatangan'] ?? ''}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
