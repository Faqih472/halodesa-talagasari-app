// ============================================================
// complaint_view.dart — Pengaduan Warga + Verifikasi KTP
//
// Warga : PengaduanWargaTab (di tab Pengajuan), BuatPengaduanView,
//         KtpVerifikasiView, PengaduanDetailView
// Admin : PengaduanStaffTab, KtpStaffTab, KtpReviewView
// Kades : PengaduanStaffTab (hanya kategori berat)
// ============================================================

import '../core/tema_app.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/complaint_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart' show pilihAlasanTolak, PemilihPeta, AlamatDesaCtrl, BlokAlamatDesa;
import 'chat_view.dart' show ChatAction;
import 'verification_view.dart';

// ─────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────
void _snack(bool ok, String okMsg, String errMsg) {
  Get.snackbar(
    ok ? 'success'.tr : 'failed'.tr,
    ok ? okMsg : errMsg,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}

Widget _loading() => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

/// Dialog isian teks (alasan penolakan / tanggapan). Null bila dibatalkan.
Future<String?> _mintaTeks(String judul, String label) async {
  final ctrl = TextEditingController();
  final hasil = await Get.dialog<String>(
    AlertDialog(
      title: Text(judul),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().length < 3) return;
            Get.back(result: ctrl.text.trim());
          },
          child: Text('cmp_send'.tr),
        ),
      ],
    ),
  );
  return hasil;
}

Widget _statusChip(String status) {
  final c = ComplaintModel.warnaStatus(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(ComplaintModel.labelStatus(status),
        style: TextStyle(
            fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

Widget _kartuPengaduan(ComplaintModel c, VoidCallback onTap,
    {String? subtitle}) {
  return Card(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    elevation: 0,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.kremTua)),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ComplaintModel.ikonKategori(c.kategori),
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ComplaintModel.labelKategori(c.kategori),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500)),
                ),
                if (c.lewatBatas)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: StatusBadge(
                        text: 'cmp_overdue'.tr, color: Colors.red.shade700),
                  ),
                _statusChip(c.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.judul,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(c.isi,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 8),
            Text(
              '${subtitle != null ? '$subtitle • ' : ''}${AppUtils.formatRelatif(c.createdAt)}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// WARGA — tab "Pengaduan" di dalam tab Pengajuan
// ============================================================
class PengaduanWargaTab extends StatefulWidget {
  const PengaduanWargaTab({super.key});

  @override
  State<PengaduanWargaTab> createState() => PengaduanWargaTabState();
}

class PengaduanWargaTabState extends State<PengaduanWargaTab> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();

  @override
  void initState() {
    super.initState();
    muat();
  }

  Future<void> muat() async {
    await _ctrl.fetchMyKtp();
    await _ctrl.fetchMine();
  }

  Future<void> _buat() async {
    if (!await wajibVerifikasi()) return;
    Get.to(() => const BuatPengaduanView())?.then((_) => _ctrl.fetchMine());
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor('warga');

    return Obx(() {
      final ktp = _ctrl.myKtp.value;
      final list = _ctrl.myComplaints;

      return RefreshIndicator(
        color: primary,
        onRefresh: muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (!_ctrl.ktpOk) _bannerKtp(ktp),
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _ringkas('cmp_total'.tr, list.length, primary),
                    _ringkas(
                        'cmp_in_progress'.tr,
                        list
                            .where((c) =>
                                c.status == 'menunggu_review' ||
                                c.status == 'pending_kades' ||
                                c.status == 'diproses')
                            .length,
                        const Color(0xFFE65100)),
                    _ringkas('cmp_done'.tr,
                        list.where((c) => c.status == 'selesai').length,
                        Colors.green.shade700),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _buat,
                  icon: const Icon(Icons.add_comment_outlined,
                      color: Colors.white),
                  label: Text('cmp_create'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
            if (_ctrl.isLoading.value && list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: primary)),
              )
            else if (list.isEmpty)
              SizedBox(
                height: 340,
                child: EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'cmp_empty_title'.tr,
                  subtitle: 'cmp_empty_sub'.tr,
                  color: primary,
                ),
              )
            else
              ...list.map((c) => _kartuPengaduan(c, () {
                    Get.to(() => PengaduanDetailView(complaint: c));
                  })),
          ],
        ),
      );
    });
  }

  Widget _ringkas(String label, int n, Color warna) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [warna.withOpacity(0.16), warna.withOpacity(0.06)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: warna.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            AngkaHitung(n,
                gaya: TextStyle(
                    fontFamily: AppTheme.fontJudul,
                    fontSize: 26,
                    color: warna)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: warna, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _bannerKtp(KtpModel ktp) {
    Color warna;
    IconData ikon;
    String judul;
    String isi;
    switch (ktp.status) {
      case 'menunggu':
        warna = const Color(0xFFE65100);
        ikon = Icons.hourglass_top_outlined;
        judul = 'ktp_wait_title'.tr;
        isi = 'ktp_wait_sub'.tr;
        break;
      case 'ditolak':
        warna = Colors.red.shade700;
        ikon = Icons.cancel_outlined;
        judul = 'ktp_rejected_title'.tr;
        isi = '${'cmp_reason'.tr}: ${ktp.alasan ?? '-'}';
        break;
      case 'diblokir':
        warna = Colors.red.shade700;
        ikon = Icons.block;
        judul = 'ktp_blocked_title'.tr;
        isi = '${'cmp_reason'.tr}: ${ktp.alasan ?? '-'}';
        break;
      default:
        warna = const Color(0xFF1565C0);
        ikon = Icons.badge_outlined;
        judul = 'ktp_need_title'.tr;
        isi = 'ktp_need_sub'.tr;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withOpacity(0.4)),
      ),
      child: InkWell(
        onTap: (ktp.status == 'menunggu' || ktp.status == 'diblokir')
            ? null
            : () => Get.to(() => const KtpVerifikasiView())
                ?.then((_) => _ctrl.fetchMyKtp()),
        child: Row(
          children: [
            Icon(ikon, color: warna),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: warna)),
                  const SizedBox(height: 2),
                  Text(isi,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (ktp.status != 'menunggu') Icon(Icons.chevron_right, color: warna),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WARGA — Form Buat Pengaduan
// ============================================================
class BuatPengaduanView extends StatefulWidget {
  const BuatPengaduanView({super.key});

  @override
  State<BuatPengaduanView> createState() => _BuatPengaduanViewState();
}

class _BuatPengaduanViewState extends State<BuatPengaduanView> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();
  final _formKey = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _isiCtrl = TextEditingController();
  final List<File> _foto = [];
  final _terlaporCtrl = TextEditingController();
  String _kategori = ComplaintModel.daftarKategori.first['value']!;
  bool _rahasia = false;
  DateTime? _tglKejadian;
  LatLng? _titik;
  String _urgensi = 'biasa';
  String _dampak = '';
  bool _sudahLapor = false;
  final _harapanCtrl = TextEditingController();
  final AlamatDesaCtrl _almt = AlamatDesaCtrl();

  @override
  void initState() {
    super.initState();
    final u = Get.find<AuthController>().currentUser.value;
    if (u != null) {
      _almt.isiDari(
          jalanTeks: u.alamatLengkap, rtTeks: u.alamatRt, rwTeks: u.alamatRw);
    }
  }

  Map<String, dynamic> get _info =>
      ComplaintModel.infoKategori(_kategori) ?? const {};

  void _pakaiContoh() {
    setState(() {
      _judulCtrl.text = '${_info['judul'] ?? ''}';
      _isiCtrl.text = '${_info['isi'] ?? ''}';
    });
  }

  Future<void> _pilihKategori() async {
    final v = await Get.bottomSheet<String>(
      Container(
        height: Get.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Apa yang ingin dilaporkan?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Pilih yang paling dekat dengan masalah Anda. Contoh ada di bawah tiap pilihan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: ComplaintModel.kelompokKategori.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                      child: Text('${g['label']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    ...(g['isi'] as List).map((k) {
                      final v = k['value'] as String;
                      final pilih = v == _kategori;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: pilih ? AppTheme.primaryColor('warga').withOpacity(0.10) : TemaApp.warnaKartu,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: pilih ? AppTheme.primaryColor('warga') : Colors.grey.shade300),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(ComplaintModel.ikonKategori(v)),
                          onTap: () => Get.back(result: v),
                          title: Text('${k['label']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: Text('${k['contoh']}', style: const TextStyle(fontSize: 11.5)),
                          trailing: pilih
                              ? Icon(Icons.check_circle, color: AppTheme.primaryColor('warga'))
                              : null,
                        ),
                      );
                    }),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (v != null) setState(() => _kategori = v);
  }

  @override
  void dispose() {
    _harapanCtrl.dispose();
    _almt.dispose();
    _judulCtrl.dispose();
    _isiCtrl.dispose();
    _terlaporCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tglKejadian ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _tglKejadian = picked);
  }

  Future<void> _tambahFoto() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 50, maxWidth: 800);
    if (picked.isEmpty) return;
    setState(() {
      _foto.addAll(picked.map((x) => File(x.path)));
      if (_foto.length > 3) _foto.removeRange(3, _foto.length);
    });
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    final ga = _almt.galat();
    if (ga != null) {
      _snack(false, '', ga);
      return;
    }
    final ok = await _ctrl.kirim(
      kategori: _kategori,
      judul: _judulCtrl.text,
      isi: _isiCtrl.text,
      foto: _foto,
      rahasia: _rahasia,
      tglKejadian: _tglKejadian,
      terlapor: _terlaporCtrl.text,
      lat: _titik?.latitude,
      lng: _titik?.longitude,
      urgensi: _urgensi,
      dampak: _dampak,
      sudahLaporRt: _sudahLapor,
      harapan: _harapanCtrl.text,
      alamatKejadian: _almt.teks,
    );
    if (ok) Get.back();
    _snack(ok, 'cmp_sent'.tr, _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final Color primary = AppTheme.primaryColor(auth.role);
    final LatLng pusat = LatLng(
      auth.currentUser.value?.lokasiLat ?? -6.239265,
      auth.currentUser.value?.lokasiLng ?? 106.530200,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('cmp_create'.tr),
        backgroundColor: primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('cmp_form_info'.tr,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor('warga').withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor('warga').withOpacity(0.35)),
                  ),
                  child: const Text(
                      'Cara melapor (mudah):\n'
                      '1. Pilih jenis masalah.\n'
                      '2. Tulis judul & ceritakan kejadiannya (tekan "Pakai contoh" bila bingung).\n'
                      '3. Tandai lokasi di peta dan tambah foto.\n'
                      '4. Kirim. Admin memeriksa, lalu laporan ditangani dan Anda dapat kabar.\n'
                      'Untuk keadaan darurat jiwa, gunakan tombol SOS, bukan pengaduan.',
                      style: TextStyle(fontSize: 12.5, height: 1.5)),
                ),
                const Text('Langkah 1 — Pilih kelompok masalah',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  for (final g in ComplaintModel.kelompokKategori)
                    ChoiceChip(
                      label: Text('${g['label']}', style: const TextStyle(fontSize: 12)),
                      selected: ComplaintModel.idKelompok(_kategori) == g['id'],
                      onSelected: (_) => setState(() =>
                          _kategori = (g['isi'] as List).first['value'] as String),
                    ),
                ]),
                const SizedBox(height: 12),
                const Text('Langkah 2 — Pilih jenis masalahnya',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                ...(ComplaintModel.kelompokKategori
                        .firstWhere((g) => g['id'] == ComplaintModel.idKelompok(_kategori))['isi']
                    as List)
                    .map((k) {
                  final v = k['value'] as String;
                  final pilih = v == _kategori;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: pilih ? AppTheme.primaryColor('warga').withOpacity(0.10) : TemaApp.warnaKartu,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: pilih ? AppTheme.primaryColor('warga') : Colors.grey.shade300),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(ComplaintModel.ikonKategori(v)),
                      title: Text('${k['label']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      subtitle: Text('${k['contoh']}', style: const TextStyle(fontSize: 11.5)),
                      trailing: pilih
                          ? Icon(Icons.check_circle, color: AppTheme.primaryColor('warga'))
                          : null,
                      onTap: () => setState(() => _kategori = v),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Contoh laporan untuk jenis ini',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text('Judul: ${_info['judul'] ?? ''}',
                        style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    Text('Isi: ${_info['isi'] ?? ''}',
                        style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ]),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pakaiContoh,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Pakai contoh ini (lalu ubah sesuai kejadian Anda)'),
                  ),
                ),
                if (ComplaintModel.kategoriBerat.contains(_kategori)) ...[
                  const SizedBox(height: 6),
                  Text('cmp_heavy_note'.tr,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.orange.shade800)),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _judulCtrl,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'cmp_title_min'.tr
                      : null,
                  decoration: InputDecoration(labelText: 'cmp_title'.tr),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _isiCtrl,
                  maxLines: 5,
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? 'cmp_body_min'.tr
                      : null,
                  decoration: InputDecoration(
                    labelText: 'cmp_body'.tr,
                    hintText: 'cmp_body_hint'.tr,
                    alignLabelWithHint: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      if (_isiCtrl.text.trim().isEmpty) {
                        _isiCtrl.text = 'Apa yang terjadi: \nSejak kapan: \nSiapa yang terdampak: \nYang diharapkan: ';
                      }
                    }),
                    icon: const Icon(Icons.checklist, size: 16),
                    label: const Text('Bingung menulis? Pakai kerangka 4 pertanyaan'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Seberapa mendesak?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final u in const ['biasa', 'penting', 'darurat'])
                    ChoiceChip(
                      label: Text(ComplaintModel.labelUrgensi(u)),
                      selected: _urgensi == u,
                      onSelected: (_) => setState(() => _urgensi = u),
                    ),
                ]),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Biasa: bisa menunggu. Penting: mengganggu banyak orang. Mendesak: berbahaya bila dibiarkan.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 14),
                const Text('Siapa yang terdampak?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final d in const ['keluarga', 'rt', 'dusun'])
                    ChoiceChip(
                      label: Text(ComplaintModel.labelDampak(d)),
                      selected: _dampak == d,
                      onSelected: (_) => setState(() => _dampak = _dampak == d ? '' : d),
                    ),
                ]),
                const SizedBox(height: 14),
                const Text('Lokasi kejadian',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                BlokAlamatDesa(c: _almt),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sudahLapor,
                  onChanged: (v) => setState(() => _sudahLapor = v),
                  title: const Text('Sudah dilaporkan ke RT/RW?',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                TextFormField(
                  controller: _harapanCtrl,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Harapan penyelesaian (opsional)',
                    hintText: 'Contoh: jalan ditambal / petugas datang memeriksa',
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pilihTanggal,
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'cmp_date'.tr,
                        prefixIcon: const Icon(Icons.event_outlined)),
                    child: Text(
                      _tglKejadian == null
                          ? 'cmp_date_hint'.tr
                          : AppUtils.formatTanggal(_tglKejadian!),
                      style: TextStyle(
                          color: _tglKejadian == null
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _terlaporCtrl,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'cmp_accused'.tr,
                    hintText: 'cmp_accused_hint'.tr,
                    prefixIcon: const Icon(Icons.person_search_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Tandai lokasi di peta (opsional)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                PemilihPeta(
                  titik: _titik ?? pusat,
                  tinggi: 190,
                  onChanged: (p) => setState(() => _titik = p),
                ),
                const SizedBox(height: 4),
                Text('cmp_map_hint'.tr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                Text('cmp_photos'.tr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_foto.length < 3)
                        BouncyTap(
                          onTap: _tambahFoto,
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: primary.withOpacity(0.4)),
                            ),
                            child: Icon(Icons.add_photo_alternate_outlined,
                                color: primary),
                          ),
                        ),
                      ..._foto.asMap().entries.map((e) => Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                      image: FileImage(e.value),
                                      fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _foto.removeAt(e.key)),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('cmp_photos_note'.tr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rahasia,
                  onChanged: (v) => setState(() => _rahasia = v),
                  activeColor: primary,
                  title: Text('cmp_secret'.tr,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('cmp_secret_sub'.tr,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 10),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                        child: _ctrl.isSubmitting.value
                            ? _loading()
                            : Text('cmp_submit'.tr),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL PENGADUAN (warga / Admin / Kades)
// ============================================================
class PengaduanDetailView extends StatelessWidget {
  final ComplaintModel complaint;
  const PengaduanDetailView({super.key, required this.complaint});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();
    final ComplaintController ctrl = Get.find<ComplaintController>();
    final c = complaint;
    final String role = auth.role;
    final String? myUid = auth.currentUser.value?.uid;
    final Color primary = AppTheme.primaryColor(role);

    final bool saya = c.uidPelapor == myUid;
    final bool sembunyi = role == 'kades' && c.rahasia && !saya;
    final String nama =
        sembunyi ? 'cmp_hidden_reporter'.tr : c.namaPelapor;

    final bool adminReview = role == 'admin' && c.status == 'menunggu_review';
    final bool adminTangani =
        role == 'admin' && c.status == 'diproses' && c.penanganan == 'admin';
    final bool kadesReview = role == 'kades' && c.status == 'pending_kades';
    final bool kadesTangani =
        role == 'kades' && c.status == 'diproses' && c.penanganan == 'kades';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('cmp_detail'.tr),
        backgroundColor: primary,
        actions: [
          if (role == 'admin' && !saya)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'warn') {
                  final t =
                      await _mintaTeks('cmp_warn'.tr, 'cmp_warn_text'.tr);
                  if (t == null) return;
                  final ok = await ctrl.peringati(c, t);
                  _snack(ok, 'cmp_warn_ok'.tr, ctrl.errorMsg.value);
                } else {
                  final a =
                      await _mintaTeks('cmp_block'.tr, 'cmp_block_reason'.tr);
                  if (a == null) return;
                  final ok = await ctrl.blokirPelapor(c, a);
                  _snack(ok, 'cmp_block_ok'.tr, ctrl.errorMsg.value);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'warn', child: Text('cmp_warn'.tr)),
                PopupMenuItem(value: 'block', child: Text('cmp_block'.tr)),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Kepala: kategori, status, judul ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(ComplaintModel.ikonKategori(c.kategori), size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ComplaintModel.labelKategori(c.kategori),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(c.judul,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: _statusChip(c.status),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Info ringkas ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _baris(Icons.person_outline, 'Pelapor', nama),
                _baris(Icons.schedule, 'Dilaporkan', AppUtils.formatTanggalWaktu(c.createdAt)),
                if (!sembunyi && c.alamat.isNotEmpty) _baris(Icons.location_on_outlined, 'Lokasi', c.alamat),
                if (c.tglKejadian != null)
                  _baris(Icons.event_outlined, 'Tanggal kejadian', AppUtils.formatTanggal(c.tglKejadian!)),
                if (c.terlapor.isNotEmpty) _baris(Icons.report_outlined, 'Pihak terlapor', c.terlapor),
                if (c.harapan.isNotEmpty) _baris(Icons.flag_outlined, 'Harapan pelapor', c.harapan),
              ]),
            ),
            if (c.urgensi != 'biasa' || c.dampak.isNotEmpty || c.sudahLaporRt)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (c.urgensi != 'biasa')
                    _pil('Urgensi: ${ComplaintModel.labelUrgensi(c.urgensi)}',
                        c.urgensi == 'darurat' ? Colors.red.shade700 : Colors.orange.shade800),
                  if (c.dampak.isNotEmpty)
                    _pil('Terdampak: ${ComplaintModel.labelDampak(c.dampak)}', Colors.blueGrey.shade700),
                  if (c.sudahLaporRt) _pil('Sudah lapor RT/RW', Colors.teal.shade700),
                ]),
              ),
            if (c.rahasia && role == 'admin')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('cmp_secret_admin_note'.tr,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
              ),

            // ── Isi laporan ──
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Isi laporan',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text(c.isi, style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.textPrimary)),
              ]),
            ),
            if (c.fotoUrls.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(children: [
                  for (final u in c.fotoUrls)
                    GestureDetector(
                      onTap: () => Get.dialog(Dialog(
                          child: InteractiveViewer(child: ImageUtil.image(u, fit: BoxFit.contain)))),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SizedBox(
                            width: double.infinity,
                            height: 220,
                            child: ImageUtil.image(u, fit: BoxFit.cover)),
                      ),
                    ),
                ]),
              ),
            ],
            if (c.status == 'ditolak' &&
                (c.alasanPenolakan ?? '').isNotEmpty)
              _kotak(Colors.red.shade700, 'cmp_reason'.tr, c.alasanPenolakan!),
            if (c.status == 'selesai' && (c.tanggapan ?? '').isNotEmpty)
              _kotak(Colors.green.shade700, 'cmp_response'.tr, c.tanggapan!),
            _AktivitasSection(complaint: c, sembunyiPelapor: sembunyi),
            const SizedBox(height: 24),

            // ── Aksi ──
            if (adminReview || kadesReview)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final a = await pilihAlasanTolak('pengaduan',
                            judul: 'Tolak pengaduan');
                        if (a == null) return;
                        final ok = await ctrl.tolak(c, a);
                        if (ok) Get.back();
                        _snack(ok, 'cmp_rejected_ok'.tr, ctrl.errorMsg.value);
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
                            ? await ctrl.setujui(c)
                            : await ctrl.terimaKades(c);
                        if (ok) Get.back();
                        _snack(ok, 'cmp_approved_ok'.tr, ctrl.errorMsg.value);
                      },
                      child: Text(
                          adminReview && c.isBerat
                              ? 'cmp_forward'.tr
                              : 'cmp_approve'.tr,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            if (adminTangani || kadesTangani)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final t = await _mintaTeks(
                        'cmp_finish'.tr, 'cmp_response'.tr);
                    if (t == null) return;
                    final ok = await ctrl.selesaikan(c, t);
                    if (ok) Get.back();
                    _snack(ok, 'cmp_finished_ok'.tr, ctrl.errorMsg.value);
                  },
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  label: Text('cmp_finish'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _baris(IconData ikon, String label, String nilai) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
              width: 104,
              child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary))),
          Expanded(
              child: Text(nilai,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3))),
        ]),
      );

  Widget _pil(String t, Color w) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: w.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: w)),
      );

  Widget _kotak(Color warna, String judul, String isi) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warna.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: warna)),
          const SizedBox(height: 4),
          Text(isi, style: const TextStyle(fontSize: 13.5, height: 1.4)),
        ],
      ),
    );
  }
}

// ============================================================
// STAFF — antrian pengaduan (Admin & Kades)
// ============================================================
class PengaduanStaffTab extends StatefulWidget {
  const PengaduanStaffTab({super.key});

  @override
  State<PengaduanStaffTab> createState() => _PengaduanStaffTabState();
}

class _PengaduanStaffTabState extends State<PengaduanStaffTab> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();

  @override
  void initState() {
    super.initState();
    _ctrl.fetchAntrian();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();
    final Color primary = AppTheme.primaryColor(auth.role);

    return Obx(() {
      final list = _ctrl.antrian;
      final String? myUid = auth.currentUser.value?.uid;

      return RefreshIndicator(
        color: primary,
        onRefresh: _ctrl.fetchAntrian,
        child: list.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'cmp_staff_empty'.tr,
                    subtitle: 'cmp_staff_empty_sub'.tr,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final bool sembunyi = auth.role == 'kades' &&
                      c.rahasia &&
                      c.uidPelapor != myUid;
                  return _kartuPengaduan(
                    c,
                    () => Get.to(() => PengaduanDetailView(complaint: c))
                        ?.then((_) => _ctrl.fetchAntrian()),
                    subtitle:
                        sembunyi ? 'cmp_hidden_reporter'.tr : c.namaPelapor,
                  );
                },
              ),
      );
    });
  }
}

// ============================================================
// Timeline status + balasan dua arah + rating kepuasan
// ============================================================
class _AktivitasSection extends StatefulWidget {
  final ComplaintModel complaint;
  final bool sembunyiPelapor;
  const _AktivitasSection(
      {required this.complaint, required this.sembunyiPelapor});

  @override
  State<_AktivitasSection> createState() => _AktivitasSectionState();
}

class _AktivitasSectionState extends State<_AktivitasSection> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();
  final AuthController _auth = Get.find<AuthController>();
  final _teksCtrl = TextEditingController();
  final _ulasanCtrl = TextEditingController();
  int _bintang = 0;
  bool _kirimKomentarLoading = false;
  bool _ratingLoading = false;
  late int _ratingTersimpan;

  ComplaintModel get c => widget.complaint;

  @override
  void initState() {
    super.initState();
    _ratingTersimpan = c.rating;
  }

  @override
  void dispose() {
    _teksCtrl.dispose();
    _ulasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirimKomentar() async {
    if (_teksCtrl.text.trim().isEmpty) return;
    setState(() => _kirimKomentarLoading = true);
    final ok = await _ctrl.kirimKomentar(c, _teksCtrl.text.trim());
    if (!mounted) return;
    setState(() => _kirimKomentarLoading = false);
    if (ok) _teksCtrl.clear();
    if (!ok) _snack(false, '', _ctrl.errorMsg.value);
  }

  Future<void> _kirimRating() async {
    if (_bintang == 0) return;
    setState(() => _ratingLoading = true);
    final ok = await _ctrl.beriRating(c, _bintang, _ulasanCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _ratingLoading = false;
      if (ok) _ratingTersimpan = _bintang;
    });
    _snack(ok, 'cmp_rating_ok'.tr, _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final String? myUid = _auth.currentUser.value?.uid;
    final bool saya = c.uidPelapor == myUid;
    final bool bolehBalas = c.status != 'ditolak' &&
        c.status != 'menunggu_review' &&
        (saya || _auth.isStaff);
    final Color primary = AppTheme.primaryColor(_auth.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('cmp_timeline'.tr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<ActivityModel>>(
          stream: _ctrl.aktivitasStream(c.id),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return Text('cmp_timeline_empty'.tr,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary));
            }
            return Column(
              children: list.map((a) {
                final bool status = a.tipe == 'status';
                final bool hide = widget.sembunyiPelapor && a.peran == 'warga';
                final String nama = hide ? 'cmp_hidden_reporter'.tr : a.oleh;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: status
                        ? Colors.grey.shade100
                        : primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(status ? Icons.timeline : Icons.chat_bubble_outline,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                '$nama • ${AppUtils.formatTanggalWaktu(a.createdAt)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.isi,
                          style: const TextStyle(fontSize: 13.5, height: 1.4)),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (bolehBalas)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teksCtrl,
                  decoration: InputDecoration(
                      hintText: 'cmp_reply_hint'.tr, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _kirimKomentarLoading ? null : _kirimKomentar,
                icon: Icon(Icons.send, color: primary),
              ),
            ],
          ),
        if (c.status == 'selesai' && (_ratingTersimpan > 0 || saya)) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('cmp_rating_title'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_ratingTersimpan > 0) ...[
                  RatingStars(rating: _ratingTersimpan.toDouble()),
                  if (c.ulasanRating.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(c.ulasanRating),
                    ),
                ] else ...[
                  RatingStars(
                      rating: _bintang.toDouble(),
                      size: 32,
                      onChanged: (v) => setState(() => _bintang = v)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ulasanCtrl,
                    decoration: InputDecoration(
                        hintText: 'cmp_rating_hint'.tr, isDense: true),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _ratingLoading ? null : _kirimRating,
                    child: _ratingLoading
                        ? _loading()
                        : Text('cmp_send'.tr,
                            style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}


// ============================================================
// TAB UTAMA WARGA — Pengaduan
// ============================================================
class TabPengaduanView extends StatelessWidget {
  const TabPengaduanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('cmp_title_tab'.tr),
        backgroundColor: AppTheme.primaryColor('warga'),
        actions: const [ChatAction()],
      ),
      body: const PengaduanWargaTab(),
    );
  }
}
