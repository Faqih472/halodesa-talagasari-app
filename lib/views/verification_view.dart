// ============================================================
// verification_view.dart — Verifikasi Identitas (1x untuk semua fitur)
//   Warga : KtpVerifikasiView (form data KTP + unggah foto KTP)
//   Admin : KtpStaffTab + KtpReviewView (cocokkan data lalu ACC)
//   Helper: wajibVerifikasi(), VerifiedBadge
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/complaint_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';
import 'camera_view.dart';

/// Pagar fitur: kembalikan true bila akun sudah terverifikasi (atau staf).
/// Bila belum, tampilkan dialog yang mengarahkan ke form verifikasi.
Future<bool> wajibVerifikasi() async {
  final auth = Get.find<AuthController>();
  if (auth.isStaff) return true;
  final c = Get.find<ComplaintController>();
  await c.fetchMyKtp();
  if (c.ktpOk) return true;
  final ke = await Get.dialog<bool>(AlertDialog(
    title: Text('need_verified_title'.tr),
    content: Text('need_verified'.tr),
    actions: [
      TextButton(
          onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
      ElevatedButton(
          onPressed: () => Get.back(result: true),
          child: Text('verify_now'.tr,
              style: const TextStyle(color: Colors.white))),
    ],
  ));
  if (ke == true) await Get.to(() => const KtpVerifikasiView());
  return false;
}

/// Lencana "Terverifikasi"
class VerifiedBadge extends StatelessWidget {
  final bool onDark;
  const VerifiedBadge({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final Color c = onDark ? Colors.white : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 13, color: c),
          const SizedBox(width: 4),
          Text('verified'.tr,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

// ============================================================
// WARGA — form verifikasi identitas
// ============================================================
class KtpVerifikasiView extends StatefulWidget {
  const KtpVerifikasiView({super.key});

  @override
  State<KtpVerifikasiView> createState() => _KtpVerifikasiViewState();
}

class _KtpVerifikasiViewState extends State<KtpVerifikasiView> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();
  final AuthController _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  final _nikCtrl = TextEditingController();
  final _tempatCtrl = TextEditingController();
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _rtCtrl;
  late final TextEditingController _rwCtrl;
  DateTime? _lahir;
  String _jk = '';
  String _fotoSelfie = ''; // foto 1 (kamera depan, pegang KTP)
  String _fotoKtp = ''; // foto 2 (KTP saja)

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser.value;
    _namaCtrl = TextEditingController(text: u?.nama ?? '');
    _alamatCtrl = TextEditingController(text: u?.alamatLengkap ?? '');
    _rtCtrl = TextEditingController(text: u?.alamatRt ?? '');
    _rwCtrl = TextEditingController(text: u?.alamatRw ?? '');
    _lahir = u?.tanggalLahir;
    _jk = u?.jenisKelamin ?? '';
    _ctrl.fetchMyKtp();
  }

  @override
  void dispose() {
    for (final c in [_namaCtrl, _nikCtrl, _tempatCtrl, _alamatCtrl, _rtCtrl, _rwCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pilihLahir() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _lahir ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (p != null) setState(() => _lahir = p);
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lahir == null || _jk.isEmpty) {
      showSnack(false, '', 'ktp_complete'.tr);
      return;
    }
    if (_fotoSelfie.isEmpty || _fotoKtp.isEmpty) {
      showSnack(false, '',
          'Ambil 2 foto dulu: selfie memegang KTP, lalu foto KTP saja.');
      return;
    }
    final ok = await _ctrl.kirimKtp(
      fotoSelfie: _fotoSelfie,
      fotoKtp: _fotoKtp,
      nama: _namaCtrl.text,
      nik: _nikCtrl.text,
      tempatLahir: _tempatCtrl.text,
      tanggalLahir: _lahir!,
      jenisKelamin: _jk,
      alamat: _alamatCtrl.text,
      rt: _rtCtrl.text,
      rw: _rwCtrl.text,
    );
    if (ok) Get.back();
    showSnack(ok, 'ktp_sent'.tr, _ctrl.errorMsg.value);
  }

  String? _wajib(String? v) =>
      (v == null || v.trim().isEmpty) ? 'field_required'.tr : null;

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('ktp_title'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final ktp = _ctrl.myKtp.value;
          final bool menunggu = ktp.status == 'menunggu';
          final bool ok = _ctrl.ktpOk;

          if (ok) {
            return _pesan(Icons.verified, Colors.green.shade700, 'ktp_ok'.tr);
          }
          if (ktp.status == 'diblokir') {
            return _pesan(Icons.block, Colors.red.shade700,
                '${'ktp_blocked'.tr} ${'cmp_reason'.tr}: ${ktp.alasan ?? '-'}');
          }
          if (menunggu) {
            return _pesan(Icons.hourglass_top_outlined,
                const Color(0xFFE65100), 'ktp_wait_sub'.tr);
          }

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kartu(
                  margin: EdgeInsets.zero,
                  child: Text('ktp_info'.tr,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5)),
                ),
                if (ktp.status == 'ditolak')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _pesan(Icons.cancel_outlined, Colors.red.shade700,
                        '${'ktp_rejected_title'.tr}. ${'cmp_reason'.tr}: ${ktp.alasan ?? '-'}'),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _namaCtrl,
                  validator: _wajib,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'ktp_name'.tr),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nikCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  validator: (v) => RegExp(r'^\d{16}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'ktp_nik_invalid'.tr,
                  decoration: InputDecoration(
                      labelText: 'ktp_nik'.tr,
                      prefixIcon: const Icon(Icons.badge_outlined)),
                ),
                TextFormField(
                  controller: _tempatCtrl,
                  validator: _wajib,
                  decoration: InputDecoration(labelText: 'ktp_birthplace'.tr),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pilihLahir,
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'profile_birth'.tr,
                        prefixIcon: const Icon(Icons.cake_outlined)),
                    child: Text(_lahir == null
                        ? '-'
                        : AppUtils.formatTanggal(_lahir!)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _jk.isEmpty ? null : _jk,
                  decoration: InputDecoration(labelText: 'profile_gender'.tr),
                  items: [
                    DropdownMenuItem(
                        value: 'laki-laki', child: Text('profile_male'.tr)),
                    DropdownMenuItem(
                        value: 'perempuan', child: Text('profile_female'.tr)),
                  ],
                  onChanged: (v) => setState(() => _jk = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _alamatCtrl,
                  validator: _wajib,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: 'ktp_address'.tr, alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rtCtrl,
                        validator: _wajib,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'RT'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rwCtrl,
                        validator: _wajib,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'RW'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionTitle('FOTO VERIFIKASI (WAJIB, 2 FOTO)'),
                _kotakFoto(
                  nomor: 1,
                  judul: 'Selfie memegang KTP',
                  bantuan:
                      'Kamera depan. Posisikan wajah, bahu, dan KTP di garis panduan.',
                  foto: _fotoSelfie,
                  onTap: () async {
                    final f = await ambilFotoVerifikasi(selfie: true);
                    if (f != null) setState(() => _fotoSelfie = f);
                  },
                ),
                const SizedBox(height: 10),
                _kotakFoto(
                  nomor: 2,
                  judul: 'Foto KTP saja',
                  bantuan:
                      'Letakkan KTP di bingkai, tulisan harus jelas dan tidak silau.',
                  foto: _fotoKtp,
                  onTap: () async {
                    final f = await ambilFotoVerifikasi(selfie: false);
                    if (f != null) setState(() => _fotoKtp = f);
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Foto hanya dilihat Admin untuk mencocokkan data, dan DIHAPUS otomatis setelah diperiksa. Hanya bisa lewat kamera (tidak dari galeri).',
                  style: TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                    child: _ctrl.isSubmitting.value
                        ? loadingChild()
                        : Text('ktp_submit'.tr),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _kotakFoto({
    required int nomor,
    required String judul,
    required String bantuan,
    required String foto,
    required VoidCallback onTap,
  }) {
    final bool ada = foto.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: ada ? Colors.green.shade600 : Colors.grey.shade400),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 76,
                child: ada
                    ? ImageUtil.image(foto)
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                            nomor == 1
                                ? Icons.face_retouching_natural
                                : Icons.badge_outlined,
                            size: 34,
                            color: Colors.grey.shade600),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Foto $nomor: $judul',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(bantuan,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.3)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(ada ? Icons.check_circle : Icons.photo_camera_outlined,
                        size: 16,
                        color: ada ? Colors.green.shade700 : AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(ada ? 'Sudah diambil (ketuk untuk ulang)' : 'Ketuk untuk buka kamera',
                        style: TextStyle(
                            fontSize: 12,
                            color: ada ? Colors.green.shade700 : AppTheme.textSecondary)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pesan(IconData ikon, Color warna, String teks) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(ikon, color: warna),
          const SizedBox(width: 10),
          Expanded(
              child: Text(teks, style: TextStyle(fontSize: 12.5, color: warna))),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN — daftar & pemeriksaan verifikasi
// ============================================================
class KtpStaffTab extends StatefulWidget {
  const KtpStaffTab({super.key});

  @override
  State<KtpStaffTab> createState() => _KtpStaffTabState();
}

class _KtpStaffTabState extends State<KtpStaffTab> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();

  @override
  void initState() {
    super.initState();
    _ctrl.fetchKtpMenunggu();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor('admin');
    return Obx(() {
      final list = _ctrl.ktpMenunggu;
      return RefreshIndicator(
        color: primary,
        onRefresh: _ctrl.fetchKtpMenunggu,
        child: list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'ktp_staff_empty'.tr,
                  subtitle: 'ktp_staff_empty_sub'.tr,
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final k = list[i];
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primary.withOpacity(0.1),
                        child: Icon(Icons.badge_outlined, color: primary),
                      ),
                      title: Text(k.nama,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('NIK ${k.nik}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.to(() => KtpReviewView(ktp: k)),
                    ),
                  );
                },
              ),
      );
    });
  }
}

class KtpReviewView extends StatelessWidget {
  final KtpModel ktp;
  const KtpReviewView({super.key, required this.ktp});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ComplaintController>();
    final Color primary = AppTheme.primaryColor('admin');
    final k = ktp;

    Widget baris(String a, String b, {String? bandingkan}) {
      final bool beda = bandingkan != null &&
          bandingkan.trim().isNotEmpty &&
          bandingkan.trim().toLowerCase() != b.trim().toLowerCase();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(a,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary))),
            Expanded(
              child: Text(b.isEmpty ? '-' : b,
                  style: TextStyle(
                      color: beda ? Colors.red.shade700 : null,
                      fontWeight: beda ? FontWeight.bold : null)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('ktp_review'.tr), backgroundColor: primary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ktp_review_note'.tr,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 10),
          if (k.fotoSelfie.isNotEmpty || k.fotoKtp.isNotEmpty) ...[
            const SectionTitle('COCOKKAN FOTO (ketuk untuk memperbesar)'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(children: [
                    const Text('Foto 1: Selfie + KTP',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    k.fotoSelfie.isEmpty
                        ? const Text('-')
                        : fotoBanner(k.fotoSelfie, tinggi: 200),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(children: [
                    const Text('Foto 2: KTP saja',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    k.fotoKtp.isEmpty
                        ? const Text('-')
                        : fotoBanner(k.fotoKtp, tinggi: 200),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
                'Cocokkan wajah di selfie dengan foto di KTP, dan data KTP dengan isian di bawah.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tidak ada foto pada pengajuan ini.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12.5)),
            ),
          SectionTitle('ktp_data_submitted'.tr),
          kartu(
            margin: EdgeInsets.zero,
            child: Column(children: [
              baris('ktp_name'.tr, k.nama),
              baris('NIK', k.nik),
              baris('ktp_birthplace'.tr, k.tempatLahir),
              baris('profile_birth'.tr,
                  k.tanggalLahir == null ? '-' : AppUtils.formatTanggal(k.tanggalLahir!)),
              baris('profile_gender'.tr, k.jenisKelamin),
              baris('ktp_address'.tr, k.alamat),
              baris('RT / RW', '${k.rt} / ${k.rw}'),
            ]),
          ),
          SectionTitle('ktp_data_account'.tr),
          kartu(
            margin: EdgeInsets.zero,
            child: Column(children: [
              baris('profile_name'.tr, k.nama),
              baris('profile_email'.tr, k.email),
              baris('profile_phone'.tr, k.telepon),
            ]),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final a = await pilihAlasanTolak('ktp',
                        judul: 'Tolak verifikasi identitas');
                    if (a == null) return;
                    final ok = await ctrl.putuskanKtp(k, setuju: false, alasan: a);
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
                    final ok = await ctrl.putuskanKtp(k, setuju: true);
                    if (ok) Get.back();
                    showSnack(ok, 'ktp_verified_ok'.tr, ctrl.errorMsg.value);
                  },
                  child: Text('ktp_verify'.tr,
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
