// ============================================================
// letter_view.dart — Surat Online
//   Warga : LetterHomeView (daftar + ajukan + unduh PDF)
//   Admin : cek berkas → teruskan ke Kades
//   Kades : setujui → surat terbit (PDF siap tanda tangan basah)
//   Staf  : CekSuratView (cek keaslian dari kode surat)
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  pw.Widget baris(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 120, child: pw.Text(k)),
            pw.Text(': '),
            pw.Expanded(child: pw.Text(v)),
          ],
        ),
      );

  String isiUtama() {
    switch (l.jenis) {
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

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(children: [
              pw.Text(AppContact.kopPemerintah,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppContact.kopKecamatan,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppContact.kopDesa,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppContact.kopAlamat, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(LetterModel.labelJenis(l.jenis).toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline)),
          ),
          pw.Center(child: pw.Text('Nomor: ${l.nomor}')),
          pw.SizedBox(height: 18),
          pw.Text('Yang bertanda tangan di bawah ini, Kepala Desa Talagasari, '
              'Kecamatan Cikupa, Kabupaten Tangerang, menerangkan bahwa:'),
          pw.SizedBox(height: 8),
          baris('Nama', l.nama),
          baris('NIK', l.nik),
          baris('Jenis Kelamin', jk),
          baris('Tempat/Tgl Lahir', ttl),
          baris('Alamat', l.alamat),
          pw.SizedBox(height: 8),
          pw.Text(isiUtama()),
          pw.SizedBox(height: 6),
          pw.Text('Keperluan: ${l.keperluan}'),
          pw.SizedBox(height: 10),
          pw.Text('Demikian surat ini dibuat untuk dipergunakan sebagaimana mestinya.'),
          pw.SizedBox(height: 8),
          pw.Text(
              'Surat ini berlaku ${LetterModel.masaBulan(l.jenis)} bulan sejak tanggal ditandatangani.',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Kode surat: ${l.kode}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Keaslian surat dicek oleh petugas desa.',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Talagasari, ............................'),
                  pw.Text('Kepala Desa Talagasari'),
                  pw.SizedBox(height: 70), // ruang tanda tangan basah + stempel
                  pw.Text('( ${l.penandatangan} )',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
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
              onPressed: () async {
                if (!await wajibVerifikasi()) return;
                await Get.to(() => const AjukanSuratView());
                _muat();
              },
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
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                        icon: Icons.description_outlined,
                        title: 'letter_empty'.tr,
                        subtitle: staf
                            ? 'letter_empty_staff'.tr
                            : 'letter_empty_sub'.tr),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final l = list[i];
                    final bool kad = l.kadaluarsa;
                    final Color w = kad
                        ? Colors.red.shade700
                        : LetterModel.warnaStatus(l.status);
                    return InkWell(
                      onTap: () async {
                        await Get.to(() => LetterDetailView(letter: l));
                        _muat();
                      },
                      child: kartu(
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, color: w),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(LetterModel.labelJenis(l.jenis),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${staf ? '${l.nama} • ' : ''}${AppUtils.formatRelatif(l.createdAt)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            StatusBadge(
                                text: kad
                                    ? 'letter_expired'.tr
                                    : LetterModel.labelStatus(l.status),
                                color: w),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Form pengajuan (data otomatis dari profil)
// ─────────────────────────────────────────────────────────────
class AjukanSuratView extends StatefulWidget {
  const AjukanSuratView({super.key});

  @override
  State<AjukanSuratView> createState() => _AjukanSuratViewState();
}

class _AjukanSuratViewState extends State<AjukanSuratView> {
  final LetterController _ctrl = Get.find<LetterController>();
  final AuthController _auth = Get.find<AuthController>();
  final _keperluanCtrl = TextEditingController();
  String _jenis = 'domisili';

  @override
  void dispose() {
    _keperluanCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (_keperluanCtrl.text.trim().length < 5) {
      showSnack(false, '', 'letter_purpose_min'.tr);
      return;
    }
    final ok = await _ctrl.ajukan(
        jenis: _jenis, keperluan: _keperluanCtrl.text.trim());
    if (ok) Get.back();
    showSnack(ok, 'letter_sent'.tr, _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final u = _auth.currentUser.value;
    final ktp = Get.find<ComplaintController>().myKtp.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('letter_request'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _jenis,
              decoration: InputDecoration(labelText: 'letter_type'.tr),
              items: LetterModel.daftarJenis
                  .map((j) => DropdownMenuItem(
                      value: j['value']!, child: Text(j['label']!)))
                  .toList(),
              onChanged: (v) => setState(() => _jenis = v ?? 'domisili'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _keperluanCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: 'letter_purpose'.tr, alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
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
