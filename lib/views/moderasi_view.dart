// ============================================================
// moderasi_view.dart — Profil publik, laporan (report), pembekuan akun,
// reaksi emoji, dan aturan komunitas Desa Talagasari.
// Semua gratis: Firestore saja (tanpa Functions/Storage).
// ============================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../core/app_contact.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';
import '../core/models_extra.dart' show LowonganModel;
import 'admin_tools_view.dart' show warnaKategori;
import 'chat_view.dart';
import 'info_sosial.dart' show GaleriFoto, InfoAksi, catatDilihat;
import 'jasa_view.dart' show JasaDetailView, LowonganDetailView;
import 'lapak_view.dart' show KartuLapak, LapakModel;

// ─────────────────────────────────────────────────────────────
// REAKSI EMOJI (ala WhatsApp / Facebook)
// ─────────────────────────────────────────────────────────────
const List<String> daftarEmoji = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];

/// Dialog pilih emoji. Mengembalikan emoji yang dipilih, atau null.
Future<String?> pilihEmoji({String? sekarang}) {
  return Get.dialog<String>(Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final e in daftarEmoji)
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Get.back(result: e),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: e == sekarang ? Colors.blue.shade50 : null,
                ),
                child: Text(e, style: const TextStyle(fontSize: 30)),
              ),
            ),
        ],
      ),
    ),
  ));
}

/// Simpan / hapus reaksi pada dokumen yang punya field map `reaksi`.
Future<void> setReaksiDoc(DocumentReference ref, String? emoji) async {
  final uid = Get.find<AuthController>().currentUser.value?.uid;
  if (uid == null) return;
  try {
    await ref.update({
      'reaksi.$uid': emoji == null ? FieldValue.delete() : emoji,
    });
  } catch (_) {
    showSnack(false, '', 'Gagal mengirim reaksi. Periksa koneksi internet.');
  }
}

/// Lencana ringkas: emoji unik + jumlah.
Widget lencanaReaksi(Map<String, String> r, {Color? latar}) {
  if (r.isEmpty) return const SizedBox.shrink();
  final hitung = <String, int>{};
  for (final e in r.values) {
    hitung[e] = (hitung[e] ?? 0) + 1;
  }
  final urut = hitung.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: latar ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
    ),
    child: Text(
      '${urut.take(3).map((e) => e.key).join()} ${r.length}',
      style: const TextStyle(fontSize: 11.5),
    ),
  );
}

Map<String, String> bacaReaksi(dynamic v) {
  if (v is Map) {
    return Map<String, String>.from(v.map((k, x) => MapEntry('$k', '$x')));
  }
  return const {};
}

// ─────────────────────────────────────────────────────────────
// KATEGORI PELANGGARAN (dipakai laporan & pembekuan)
// ─────────────────────────────────────────────────────────────
class Pelanggaran {
  final String id;
  final String label;
  final String contoh;
  final int saranHari; // 0 = permanen
  const Pelanggaran(this.id, this.label, this.contoh, this.saranHari);
}

const List<Pelanggaran> daftarPelanggaran = [
  Pelanggaran('kasar', 'Kata-kata kasar / menghina',
      'Memaki, merendahkan, mengejek warga.', 3),
  Pelanggaran('fitnah', 'Fitnah / menjelekkan orang, usaha, atau desa',
      'Menuduh tanpa bukti, menjelekkan warga atau usaha lain.', 14),
  Pelanggaran('hoaks', 'Kabar bohong (hoaks)',
      'Berita palsu yang membuat warga resah.', 7),
  Pelanggaran('luar_desa', 'Di luar wilayah Desa Talagasari',
      'Info, jasa, lapak, atau lowongan yang bukan di Talagasari.', 3),
  Pelanggaran('kekerasan', 'Kekerasan / ancaman',
      'Mengancam, mengajak berkelahi, menyebar kekerasan.', 90),
  Pelanggaran('penipuan', 'Penipuan / pungli',
      'Meminta uang di muka lalu hilang, harga menipu, pungutan liar.', 180),
  Pelanggaran('dewasa', 'Konten dewasa / tidak pantas',
      'Foto atau kata-kata asusila.', 30),
  Pelanggaran('sara', 'SARA / provokasi',
      'Menyerang suku, agama, ras, atau mengadu domba warga.', 90),
  Pelanggaran('spam', 'Spam / iklan di tempat yang salah',
      'Pesan berulang, promosi tidak nyambung dengan fitur.', 3),
  Pelanggaran('salah_guna', 'Menyalahgunakan fitur aplikasi',
      'SOS iseng, pengaduan palsu, pesanan atau lamaran main-main, ulasan palsu.', 30),
  Pelanggaran('akun_palsu', 'Akun palsu / menyamar',
      'Memakai nama atau foto orang lain.', 90),
  Pelanggaran('pelecehan', 'Pelecehan / mengganggu lewat chat',
      'Chat berulang yang tidak diinginkan, merayu, menekan.', 90),
  Pelanggaran('lainnya', 'Alasan lain', 'Tulis jelas alasan Anda.', 7),
];

Pelanggaran _cariPelanggaran(String id) => daftarPelanggaran
    .firstWhere((p) => p.id == id, orElse: () => daftarPelanggaran.last);

// ─────────────────────────────────────────────────────────────
// LAPORKAN (report) — ke Admin
// tipe: profil | info | komentar | chat | jasa | lowongan | lapak
// ─────────────────────────────────────────────────────────────
Future<void> laporkan({
  required String tipe,
  required String targetId,
  required String targetUid,
  required String targetNama,
  String cuplikan = '',
  String targetPath = '',
}) async {
  final auth = Get.find<AuthController>();
  final me = auth.currentUser.value;
  if (me == null) return;
  if (targetUid == me.uid) {
    showSnack(false, '', 'Ini milik Anda sendiri, tidak bisa dilaporkan.');
    return;
  }

  String pilih = '';
  final ctrl = TextEditingController();
  bool kirim = false;

  await Get.dialog(StatefulBuilder(builder: (ctx, setS) {
    final lain = pilih == 'lainnya';
    return AlertDialog(
      title: Text('Laporkan ke Admin'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Yang dilaporkan: $targetNama',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
                'Pilih alasan yang paling sesuai. Laporan dibaca Admin dan tidak terlihat oleh yang dilaporkan.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            for (final p in daftarPelanggaran)
              InkWell(
                onTap: () => setS(() => pilih = p.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(pilih == p.id ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: pilih == p.id ? Colors.red.shade700 : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.label,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Text(p.contoh,
                            style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                      ]),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: lain ? 'Jelaskan alasan (wajib)' : 'Keterangan tambahan (opsional)',
                hintText: 'Contoh: Dia mengirim pesan kasar berulang kali setelah saya menolak.',
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(110, 42), backgroundColor: Colors.red.shade700),
          onPressed: kirim
              ? null
              : () async {
                  if (pilih.isEmpty) {
                    showSnack(false, '', 'Pilih alasan laporan dulu.');
                    return;
                  }
                  if (lain && ctrl.text.trim().length < 10) {
                    showSnack(false, '', 'Alasan lain harus dijelaskan (minimal 10 huruf).');
                    return;
                  }
                  setS(() => kirim = true);
                  try {
                    await FirebaseFirestore.instance
                        .collection('laporan_konten')
                        .doc('${tipe}_${targetId}_${me.uid}')
                        .set({
                      'tipe': tipe,
                      'target_id': targetId,
                      'target_uid': targetUid,
                      'target_nama': targetNama,
                      'target_path': targetPath,
                      'kategori': pilih,
                      'alasan': ctrl.text.trim(),
                      'cuplikan': cuplikan.length > 200 ? cuplikan.substring(0, 200) : cuplikan,
                      'uid_pelapor': me.uid,
                      'nama_pelapor': me.nama,
                      'status': 'baru',
                      'created_at': Timestamp.now(),
                    });
                    Get.back();
                    showSnack(true, 'Laporan terkirim. Admin akan memeriksa.', '');
                  } catch (_) {
                    setS(() => kirim = false);
                    showSnack(false, '',
                        'Gagal mengirim. Mungkin Anda sudah pernah melaporkan ini.');
                  }
                },
          child: Text(kirim ? 'Mengirim...' : 'Kirim laporan',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }));
}

// ─────────────────────────────────────────────────────────────
// BEKUKAN / BUKA AKUN (khusus Admin)
// ─────────────────────────────────────────────────────────────
const List<List<dynamic>> _pilihanDurasi = [
  [1, '1 hari'],
  [3, '3 hari'],
  [7, '1 minggu'],
  [14, '2 minggu'],
  [30, '1 bulan'],
  [90, '3 bulan'],
  [180, '6 bulan'],
  [365, '1 tahun'],
  [0, 'Permanen'],
];

String labelDurasi(int hari) {
  for (final d in _pilihanDurasi) {
    if (d[0] == hari) return d[1] as String;
  }
  return '$hari hari';
}

Future<void> dialogBekukan({
  required String uid,
  required String nama,
  String kategoriAwal = '',
}) async {
  final auth = Get.find<AuthController>();
  final admin = auth.currentUser.value;
  if (admin == null || admin.role != 'admin') {
    showSnack(false, '', 'Hanya Admin yang dapat membekukan akun.');
    return;
  }
  if (uid == admin.uid) {
    showSnack(false, '', 'Tidak bisa membekukan akun sendiri.');
    return;
  }
  final db = FirebaseFirestore.instance;
  final tujuan = await db.collection('users').doc(uid).get();
  final peran = (tujuan.data()?['role'] ?? 'warga') as String;
  if (peran != 'warga') {
    showSnack(false, '', 'Akun Admin / Kepala Desa tidak bisa dibekukan dari sini.');
    return;
  }

  String kat = kategoriAwal.isEmpty ? '' : kategoriAwal;
  int hari = kat.isEmpty ? 7 : _cariPelanggaran(kat).saranHari;
  final ctrl = TextEditingController();
  bool proses = false;

  await Get.dialog(StatefulBuilder(builder: (ctx, setS) {
    return AlertDialog(
      title: Text('Bekukan akun: $nama'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('1. Jenis pelanggaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: kat.isEmpty ? null : kat,
              isExpanded: true,
              hint: const Text('Pilih pelanggaran'),
              items: [
                for (final p in daftarPelanggaran)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text(p.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setS(() {
                kat = v ?? '';
                if (kat.isNotEmpty) hari = _cariPelanggaran(kat).saranHari;
              }),
            ),
            const SizedBox(height: 12),
            const Text('2. Lama pembekuan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final d in _pilihanDurasi)
                ChoiceChip(
                  label: Text(d[1] as String, style: const TextStyle(fontSize: 12)),
                  selected: hari == d[0],
                  onSelected: (_) => setS(() => hari = d[0] as int),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
                hari == 0
                    ? 'Permanen: akun tidak bisa dipakai sampai Admin membukanya.'
                    : 'Akun otomatis aktif lagi setelah ${labelDurasi(hari)}.',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            const SizedBox(height: 12),
            const Text('3. Alasan (dibaca oleh yang bersangkutan)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText:
                    'Contoh: Mengirim chat kasar ke beberapa warga pada 3 November.',
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(110, 42), backgroundColor: Colors.red.shade700),
          onPressed: proses
              ? null
              : () async {
                  if (kat.isEmpty) {
                    showSnack(false, '', 'Pilih jenis pelanggaran dulu.');
                    return;
                  }
                  if (ctrl.text.trim().length < 10) {
                    showSnack(false, '', 'Alasan wajib diisi (minimal 10 huruf).');
                    return;
                  }
                  setS(() => proses = true);
                  final sampai = hari == 0
                      ? null
                      : Timestamp.fromDate(DateTime.now().add(Duration(days: hari)));
                  final pel = _cariPelanggaran(kat);
                  final alasan = '${pel.label}. ${ctrl.text.trim()}';
                  try {
                    await db.collection('users').doc(uid).update({
                      'dibekukan': true,
                      'suspend_permanen': hari == 0,
                      'suspend_sampai': sampai,
                      'suspend_alasan': alasan,
                      'suspend_kategori': kat,
                      'suspend_oleh': admin.nama,
                      'suspend_at': Timestamp.now(),
                      'suspend_jumlah': FieldValue.increment(1),
                    });
                    await db.collection('riwayat_moderasi').add({
                      'uid': uid,
                      'nama': nama,
                      'aksi': 'bekukan',
                      'durasi_hari': hari,
                      'kategori': kat,
                      'alasan': alasan,
                      'oleh': admin.nama,
                      'oleh_uid': admin.uid,
                      'at': Timestamp.now(),
                    });
                    try {
                      await Get.find<NotificationController>().kirimKe(
                        uidTujuan: uid,
                        judul: 'Akun Anda dibekukan',
                        isi:
                            '${hari == 0 ? 'Permanen' : labelDurasi(hari)}. Alasan: $alasan',
                        tipe: 'info',
                      );
                    } catch (_) {}
                    Get.back();
                    showSnack(true, 'Akun $nama dibekukan (${hari == 0 ? 'permanen' : labelDurasi(hari)}).', '');
                  } catch (e) {
                    setS(() => proses = false);
                    showSnack(false, '', 'Gagal membekukan. Pastikan aturan Firestore terbaru sudah dipasang.');
                  }
                },
          child: Text(proses ? 'Memproses...' : 'Bekukan',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }));
}

Future<void> bukaBekuan({required String uid, required String nama}) async {
  final admin = Get.find<AuthController>().currentUser.value;
  if (admin == null || admin.role != 'admin') return;
  final ctrl = TextEditingController();
  final ok = await Get.dialog<bool>(AlertDialog(
    title: Text('Buka pembekuan: $nama'),
    content: TextField(
      controller: ctrl,
      maxLines: 2,
      decoration: const InputDecoration(
          labelText: 'Catatan (opsional)', hintText: 'Contoh: Sudah minta maaf.'),
    ),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
          onPressed: () => Get.back(result: true),
          child: const Text('Buka sekarang')),
    ],
  ));
  if (ok != true) return;
  final db = FirebaseFirestore.instance;
  try {
    await db.collection('users').doc(uid).update({
      'dibekukan': false,
      'suspend_permanen': false,
      'suspend_sampai': null,
      'suspend_alasan': '',
    });
    await db.collection('riwayat_moderasi').add({
      'uid': uid,
      'nama': nama,
      'aksi': 'buka',
      'alasan': ctrl.text.trim(),
      'oleh': admin.nama,
      'oleh_uid': admin.uid,
      'at': Timestamp.now(),
    });
    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: uid,
        judul: 'Akun Anda sudah aktif kembali',
        isi: 'Pembekuan dibuka Admin. Mohon patuhi aturan komunitas.',
        tipe: 'info',
      );
    } catch (_) {}
    showSnack(true, 'Pembekuan $nama dibuka.', '');
  } catch (_) {
    showSnack(false, '', 'Gagal membuka pembekuan.');
  }
}

// ─────────────────────────────────────────────────────────────
// PENJAGA: bila akun dibekukan, seluruh aplikasi diganti layar ini
// ─────────────────────────────────────────────────────────────
class PenjagaBekuan extends StatefulWidget {
  final Widget child;
  const PenjagaBekuan({super.key, required this.child});

  @override
  State<PenjagaBekuan> createState() => _PenjagaBekuanState();
}

class _PenjagaBekuanState extends State<PenjagaBekuan> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  UserModel? _u;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final uid = Get.find<AuthController>().currentUser.value?.uid;
    if (uid != null) {
      _stream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    }
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) return widget.child;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        try {
          final d = snap.data;
          if (d != null && d.exists) _u = UserModel.fromFirestore(d);
        } catch (_) {}
        final u = _u;
        if (u != null && u.role == 'warga' && u.terbekukan) {
          return AkunDibekukanView(user: u);
        }
        return widget.child;
      },
    );
  }
}

class AkunDibekukanView extends StatelessWidget {
  final UserModel user;
  const AkunDibekukanView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final sampai = user.suspendSampai;
    final String lama = user.suspendPermanen
        ? 'Permanen'
        : (sampai == null
            ? '-'
            : 'Sampai ${AppUtils.formatTanggalWaktu(sampai)} (sisa ${sampai.difference(DateTime.now()).inDays + 1} hari)');
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 30),
          Icon(Icons.block, size: 80, color: Colors.red.shade700),
          const SizedBox(height: 12),
          const Text('Akun Anda sedang dibekukan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          kartu(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lama pembekuan',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text(lama, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Alasan dari Admin',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text(user.suspendAlasan.isEmpty ? '-' : user.suspendAlasan),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
              'Selama dibekukan Anda tidak bisa memakai aplikasi. Akun otomatis aktif lagi bila masa pembekuan selesai (kecuali permanen). Bila merasa ini keliru, hubungi Admin.',
              style: TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => const AturanKomunitasView()),
            icon: const Icon(Icons.rule, color: Colors.white),
            label: const Text('Baca aturan komunitas'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => bukaUri(Uri.parse(
                'https://wa.me/${AppContact.adminTelp}?text=${Uri.encodeComponent('Halo Admin, akun saya (${user.nama}) dibekukan. Mohon bantuannya.')}')),
            icon: const Icon(Icons.support_agent),
            label: const Text('Hubungi Admin (banding)'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Get.find<AuthController>().logout(),
            child: const Text('Keluar dari akun'),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFIL PUBLIK
// ─────────────────────────────────────────────────────────────
void bukaProfil(String uid, {String nama = ''}) {
  if (uid.isEmpty) return;
  Get.to(() => ProfilPublikView(uid: uid, namaAwal: nama));
}

class ProfilPublikView extends StatefulWidget {
  final String uid;
  final String namaAwal;
  const ProfilPublikView({super.key, required this.uid, this.namaAwal = ''});

  @override
  State<ProfilPublikView> createState() => _ProfilPublikViewState();
}

class _ProfilPublikViewState extends State<ProfilPublikView> {
  final db = FirebaseFirestore.instance;
  int _tab = 0;
  bool _muat = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _info = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _jasa = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lapak = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lowongan = [];

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _q(
      String koleksi, String field, String status, {String? statusField}) async {
    try {
      final r = await db.collection(koleksi).where(field, isEqualTo: widget.uid).limit(60).get();
      return r.docs.where((d) => d.data()[statusField ?? 'status'] == status).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _ambil() async {
    final h = await Future.wait([
      _q('announcements', 'authorId', 'published'),
      _q('penyedia_jasa', 'uid_penyedia', 'aktif'),
      _q('lapak_umkm', 'uid', 'aktif'),
      _q('lowongan_warga', 'uid', 'aktif'),
    ]);
    _info = h[0]
      ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
          .compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
    _jasa = h[1];
    _lapak = h[2];
    _lowongan = h[3];
    if (mounted) setState(() => _muat = false);
  }

  Future<void> _chat(UserModel u) async {
    try {
      final chat = Get.find<ChatController>();
      final me = Get.find<AuthController>().currentUser.value!;
      final room = await chat.bukaAtauBuatRoom(
          otherUid: u.uid, otherNama: u.nama, otherFoto: u.fotoUrl);
      await Get.to(() => ChatRoomView(
            roomId: room.id,
            otherUid: u.uid,
            namaLawan: room.namaLawan(me.uid),
            fotoLawan: room.fotoLawan(me.uid),
          ));
    } catch (e) {
      showSnack(false, '', 'Tidak dapat membuka obrolan: $e');
    }
  }

  String _lama(DateTime t) {
    final h = DateTime.now().difference(t).inDays;
    if (h < 1) return 'hari ini';
    if (h < 30) return '$h hari lalu';
    if (h < 365) return '${h ~/ 30} bulan lalu';
    return '${h ~/ 365} tahun ${(h % 365) ~/ 30} bulan lalu';
  }

  int _usia(DateTime l) {
    final n = DateTime.now();
    var u = n.year - l.year;
    if (n.month < l.month || (n.month == l.month && n.day < l.day)) u--;
    return u;
  }

  Widget _stat(String angka, String label, int idx) {
    final aktif = _tab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = idx),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Text(angka,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: aktif ? Colors.green.shade800 : Colors.black87)),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                    color: aktif ? Colors.green.shade800 : AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Container(
                height: 3,
                width: 28,
                decoration: BoxDecoration(
                    color: aktif ? Colors.green.shade700 : Colors.transparent,
                    borderRadius: BorderRadius.circular(2))),
          ]),
        ),
      ),
    );
  }

  Widget _baris(IconData ic, String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 19, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
              width: 108,
              child: Text(l, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
        ]),
      );

  void _bukaInfo(NewsModel n) {
    catatDilihat(n.id);
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            if (n.semuaFoto.isNotEmpty) GaleriFoto(foto: n.semuaFoto),
            const SizedBox(height: 10),
            Text(n.judul, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                '${NewsModel.labelKategori(n.kategori)} · ${AppUtils.formatTanggal(n.publishedAt ?? n.createdAt)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Text(n.isi, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            if (n.punyaLokasi) ...[
              const SizedBox(height: 12),
              if (n.lokasiNama.isNotEmpty)
                Text('📍 ${n.lokasiNama}', style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 10),
            InfoAksi(news: n),
          ]),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _kosong(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
            child: Text(t,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary))),
      );

  List<Widget> _isiTab(bool sendiri) {
    if (_muat) {
      return [const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))];
    }
    switch (_tab) {
      case 0:
        if (_info.isEmpty) {
          return [_kosong(sendiri ? 'Anda belum memposting info.' : 'Belum ada postingan info.')];
        }
        return [
          for (final d in _info)
            Builder(builder: (_) {
              final n = NewsModel.fromFirestore(d);
              final m = d.data();
              final suka = (m['jumlah_suka'] ?? 0) as int;
              final kom = (m['jumlah_komentar'] ?? 0) as int;
              final w = warnaKategori(n.kategori);
              return InkWell(
                onTap: () => _bukaInfo(n),
                child: kartu(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: w.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(NewsModel.labelKategori(n.kategori),
                            style: TextStyle(fontSize: 11, color: w, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Text(AppUtils.formatRelatif(n.publishedAt ?? n.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    Text(n.judul,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(n.isi,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                    if (n.semuaFoto.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                            height: 130,
                            width: double.infinity,
                            child: ImageUtil.image(n.semuaFoto.first, fit: BoxFit.cover)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('👍 $suka', style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(width: 14),
                      Text('💬 $kom', style: const TextStyle(fontSize: 12.5)),
                      if (n.fotoList.length > 1) ...[
                        const SizedBox(width: 14),
                        Text('🖼 ${n.fotoList.length}', style: const TextStyle(fontSize: 12.5)),
                      ],
                      if (n.punyaLokasi) ...[
                        const SizedBox(width: 14),
                        const Icon(Icons.place, size: 15, color: Colors.red),
                      ],
                    ]),
                  ]),
                ),
              );
            }),
        ];
      case 1:
        if (_jasa.isEmpty) return [_kosong('Belum ada jasa yang aktif.')];
        return [
          for (final d in _jasa)
            Builder(builder: (_) {
              final s = ServiceModel.fromFirestore(d);
              return InkWell(
                onTap: () => Get.to(() => JasaDetailView(service: s)),
                child: kartu(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.handyman_outlined, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.namaUsaha.trim().isNotEmpty ? s.namaUsaha : AppUtils.labelKategoriJasa(s.kategori),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text(AppUtils.labelKategoriJasa(s.kategori),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        if (s.ratingCount > 0)
                          Row(children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(' ${s.ratingAvg.toStringAsFixed(1)} (${s.ratingCount} ulasan)',
                                style: const TextStyle(fontSize: 12)),
                          ]),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              );
            }),
        ];
      case 2:
        if (_lapak.isEmpty) return [_kosong('Belum ada lapak usaha.')];
        return [for (final d in _lapak) KartuLapak(l: LapakModel.dari(d), saya: '')];
      default:
        if (_lowongan.isEmpty) return [_kosong('Belum ada lowongan yang aktif.')];
        return [
          for (final d in _lowongan)
            Builder(builder: (_) {
              final l = LowonganModel.fromFirestore(d);
              return InkWell(
                onTap: () => Get.to(() => LowonganDetailView(lowongan: l)),
                child: kartu(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.groups_outlined, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text(
                            '${l.upah > 0 ? '${rupiah(l.upah)} ${l.satuanUpah}' : 'Upah dibicarakan'} · butuh ${l.jumlahOrang} orang',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Batas: ${AppUtils.formatTanggal(l.batas)}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              );
            }),
        ];
    }
  }

  Widget _panelAdmin(UserModel u) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.collection('laporan_konten').where('target_uid', isEqualTo: u.uid).limit(100).get(),
        db.collection('riwayat_moderasi').where('uid', isEqualTo: u.uid).limit(20).get(),
      ]).then((v) => v).catchError((_) => <dynamic>[]),
      builder: (_, s) {
        final lap = (s.data != null && s.data!.length == 2)
            ? (s.data![0] as QuerySnapshot<Map<String, dynamic>>).docs
            : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final riw = (s.data != null && s.data!.length == 2)
            ? (s.data![1] as QuerySnapshot<Map<String, dynamic>>).docs
            : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return kartu(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.admin_panel_settings_outlined, color: Colors.red.shade700),
              const SizedBox(width: 6),
              const Text('Data khusus Admin', style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            _baris(Icons.email_outlined, 'Email', u.email),
            _baris(Icons.phone_outlined, 'Telepon', u.nomorTelepon.isEmpty ? '-' : u.nomorTelepon),
            _baris(Icons.home_work_outlined, 'Alamat lengkap',
                u.alamatLengkap.isEmpty ? '-' : u.alamatLengkap),
            if (u.alamatPatokan.isNotEmpty) _baris(Icons.flag_outlined, 'Patokan', u.alamatPatokan),
            _baris(Icons.flag_circle_outlined, 'Laporan diterima', '${lap.length}'),
            _baris(Icons.gavel_outlined, 'Riwayat sanksi',
                riw.isEmpty ? 'Belum pernah' : '${riw.where((e) => e.data()['aksi'] == 'bekukan').length} kali dibekukan'),
            for (final r in riw.take(5))
              Padding(
                padding: const EdgeInsets.only(left: 29, top: 2),
                child: Text(
                    '• ${r.data()['aksi'] == 'bekukan' ? 'Beku ${(r.data()['durasi_hari'] ?? 0) == 0 ? 'permanen' : labelDurasi((r.data()['durasi_hari'] ?? 0) as int)}' : 'Dibuka'}: ${r.data()['alasan'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Get.find<AuthController>().currentUser.value;
    final bool admin = me?.role == 'admin';
    final bool sendiri = me?.uid == widget.uid;
    final Color primary = AppTheme.primaryColor(me?.role ?? 'warga');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(widget.namaAwal.isEmpty ? 'Profil' : widget.namaAwal),
        actions: [
          if (!sendiri)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final d = await db.collection('users').doc(widget.uid).get();
                if (!d.exists) return;
                final u = UserModel.fromFirestore(d);
                if (v == 'lapor') {
                  await laporkan(
                      tipe: 'profil', targetId: u.uid, targetUid: u.uid, targetNama: u.nama);
                } else if (v == 'bekukan') {
                  await dialogBekukan(uid: u.uid, nama: u.nama);
                } else if (v == 'buka') {
                  await bukaBekuan(uid: u.uid, nama: u.nama);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'lapor',
                    child: ListTile(
                        leading: Icon(Icons.flag_outlined, color: Colors.red),
                        title: Text('Laporkan akun ini'),
                        contentPadding: EdgeInsets.zero)),
                if (admin)
                  const PopupMenuItem(
                      value: 'bekukan',
                      child: ListTile(
                          leading: Icon(Icons.block, color: Colors.red),
                          title: Text('Bekukan akun (Admin)'),
                          contentPadding: EdgeInsets.zero)),
                if (admin)
                  const PopupMenuItem(
                      value: 'buka',
                      child: ListTile(
                          leading: Icon(Icons.lock_open, color: Colors.green),
                          title: Text('Buka pembekuan (Admin)'),
                          contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').doc(widget.uid).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(
                icon: Icons.error_outline,
                title: 'Profil tidak dapat dimuat',
                subtitle: 'Periksa koneksi internet Anda.');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) {
            return const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Akun tidak ditemukan',
                subtitle: 'Akun ini mungkin sudah dihapus.');
          }
          final u = UserModel.fromFirestore(snap.data!);
          final totalSuka =
              _info.fold<int>(0, (a, d) => a + ((d.data()['jumlah_suka'] ?? 0) as int));
          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            // ── Sampul + avatar ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primary.withOpacity(0.65)]),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: primary.withOpacity(0.15),
                    backgroundImage: u.fotoUrl.isNotEmpty ? ImageUtil.provider(u.fotoUrl) : null,
                    child: u.fotoUrl.isEmpty
                        ? Text(AppUtils.inisial(u.nama),
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold, color: primary))
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(u.nama,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  if (u.isVerified)
                    const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.verified, color: Colors.white, size: 21)),
                ]),
                if (u.namaPanggilan.trim().isNotEmpty)
                  Text('"${u.namaPanggilan}"',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
                  _lencana(AppTheme.labelRole(u.role), Icons.badge_outlined),
                  if (u.isVerified) _lencana('KTP terverifikasi', Icons.verified_user_outlined),
                  if (_jasa.isNotEmpty) _lencana('Penyedia jasa', Icons.handyman_outlined),
                  if (_lapak.isNotEmpty) _lencana('Pemilik usaha', Icons.storefront_outlined),
                  if (admin && u.terbekukan)
                    _lencana('DIBEKUKAN', Icons.block, merah: true),
                ]),
              ]),
            ),
            // ── Tombol aksi ──
            if (!sendiri)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: () => _chat(u),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text('Kirim pesan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700)),
                    onPressed: () => laporkan(
                        tipe: 'profil', targetId: u.uid, targetUid: u.uid, targetNama: u.nama),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Laporkan'),
                  ),
                ]),
              ),
            // ── Tentang ──
            kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tentang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                const SizedBox(height: 4),
                if (u.bio.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(u.bio, style: const TextStyle(fontSize: 14, height: 1.45)),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Belum menulis bio.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ),
                _baris(Icons.event_available_outlined, 'Bergabung',
                    '${AppUtils.formatTanggal(u.createdAt)} (${_lama(u.createdAt)})'),
                if (u.jenisKelamin.isNotEmpty)
                  _baris(Icons.wc_outlined, 'Jenis kelamin', u.jenisKelamin),
                if (u.tanggalLahir != null)
                  _baris(Icons.cake_outlined, 'Usia', '${_usia(u.tanggalLahir!)} tahun'),
                _baris(Icons.location_city_outlined, 'Domisili',
                    'Desa Talagasari, Kec. Cikupa'),
                if (u.alamatDusun.trim().isNotEmpty)
                  _baris(Icons.home_outlined, 'Kampung / Dusun', u.alamatDusun),
                if (u.alamatRt.isNotEmpty || u.alamatRw.isNotEmpty)
                  _baris(Icons.signpost_outlined, 'RT / RW', 'RT ${u.alamatRt} / RW ${u.alamatRw}'),
                _baris(
                    u.isVerified ? Icons.verified_outlined : Icons.pending_outlined,
                    'Status warga',
                    u.isVerified
                        ? 'Warga terverifikasi (KTP Talagasari)'
                        : 'Belum diverifikasi'),
                if (!admin)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Nomor telepon dan alamat lengkap disembunyikan demi privasi. Hubungi lewat Kirim pesan.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  ),
              ]),
            ),
            if (admin) _panelAdmin(u),
            // ── Statistik + tab ──
            kartu(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Row(children: [
                  _stat('${_info.length}', 'Postingan', 0),
                  _stat('${_jasa.length}', 'Jasa', 1),
                  _stat('${_lapak.length}', 'Lapak', 2),
                  _stat('${_lowongan.length}', 'Lowongan', 3),
                ]),
                if (_info.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('👍 $totalSuka reaksi diterima dari postingan',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
              ]),
            ),
            ..._isiTab(sendiri),
          ]);
        },
      ),
    );
  }

  Widget _lencana(String t, IconData ic, {bool merah = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: merah ? Colors.red.shade700 : Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// ADMIN: tab "Laporan & Blokir"
// ─────────────────────────────────────────────────────────────
class ModerasiTab extends StatefulWidget {
  const ModerasiTab({super.key});

  @override
  State<ModerasiTab> createState() => _ModerasiTabState();
}

class _ModerasiTabState extends State<ModerasiTab> {
  int _mode = 0; // 0 laporan baru, 1 akun dibekukan, 2 riwayat
  final db = FirebaseFirestore.instance;

  Future<void> _putuskan(DocumentSnapshot<Map<String, dynamic>> d, String status) async {
    final admin = Get.find<AuthController>().currentUser.value;
    try {
      await d.reference.update({
        'status': status,
        'diputus_oleh': admin?.nama ?? '',
        'diputus_at': Timestamp.now(),
      });
    } catch (_) {
      showSnack(false, '', 'Gagal menyimpan keputusan.');
    }
  }

  Future<void> _hapusKonten(DocumentSnapshot<Map<String, dynamic>> d) async {
    final path = '${d.data()?['target_path'] ?? ''}';
    if (path.isEmpty) {
      showSnack(false, '', 'Konten ini tidak punya alamat hapus. Bekukan akunnya bila perlu.');
      return;
    }
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Hapus konten ini?'),
      content: const Text('Konten yang dilaporkan akan dihapus permanen.'),
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
      await db.doc(path).delete();
      await _putuskan(d, 'ditindak');
      showSnack(true, 'Konten dihapus.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menghapus konten.');
    }
  }

  Widget _chipMode(int i, String t) => ChoiceChip(
        label: Text(t, style: const TextStyle(fontSize: 12.5)),
        selected: _mode == i,
        onSelected: (_) => setState(() => _mode = i),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Wrap(spacing: 8, children: [
          _chipMode(0, 'Laporan masuk'),
          _chipMode(1, 'Akun dibekukan'),
          _chipMode(2, 'Riwayat'),
        ]),
      ),
      Expanded(
        child: _mode == 0
            ? _laporan()
            : _mode == 1
                ? _dibekukan()
                : _riwayat(),
      ),
    ]);
  }

  Widget _laporan() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('laporan_konten')
          .orderBy('created_at', descending: true)
          .limit(150)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
              icon: Icons.error_outline,
              title: 'Laporan tidak dapat dimuat',
              subtitle: 'Pastikan aturan Firestore terbaru sudah dipasang.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final baru = snap.data!.docs.where((d) => d.data()['status'] == 'baru').toList();
        if (baru.isEmpty) {
          return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Tidak ada laporan baru',
              subtitle: 'Laporan warga akan muncul di sini.');
        }
        final jumlah = <String, int>{};
        for (final d in baru) {
          final u = '${d.data()['target_uid']}';
          jumlah[u] = (jumlah[u] ?? 0) + 1;
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: baru.length,
          itemBuilder: (_, i) {
            final d = baru[i];
            final m = d.data();
            final p = _cariPelanggaran('${m['kategori']}');
            final t = (m['created_at'] as Timestamp?)?.toDate();
            final tuid = '${m['target_uid']}';
            return kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Chip(
                      label: Text('${m['tipe']}'.toUpperCase(),
                          style: const TextStyle(fontSize: 10.5)),
                      visualDensity: VisualDensity.compact),
                  const SizedBox(width: 6),
                  if ((jumlah[tuid] ?? 0) > 1)
                    Text('${jumlah[tuid]} laporan pada akun ini',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (t != null)
                    Text(AppUtils.formatRelatif(t),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text('${m['target_nama']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(p.label,
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if ('${m['alasan']}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Keterangan: ${m['alasan']}', style: const TextStyle(fontSize: 13)),
                  ),
                if ('${m['cuplikan']}'.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text('"${m['cuplikan']}"',
                        style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 4),
                Text('Dilaporkan oleh ${m['nama_pelapor']}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 0, children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => bukaProfil(tuid, nama: '${m['target_nama']}'),
                    child: const Text('Lihat profil'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        backgroundColor: Colors.red.shade700),
                    onPressed: () async {
                      await dialogBekukan(
                          uid: tuid,
                          nama: '${m['target_nama']}',
                          kategoriAwal: '${m['kategori']}');
                      final u = await db.collection('users').doc(tuid).get();
                      if (u.exists && UserModel.fromFirestore(u).terbekukan) {
                        await _putuskan(d, 'ditindak');
                      }
                    },
                    child: const Text('Bekukan akun', style: TextStyle(color: Colors.white)),
                  ),
                  if ('${m['target_path']}'.isNotEmpty)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: Colors.red.shade700),
                      onPressed: () => _hapusKonten(d),
                      child: const Text('Hapus konten'),
                    ),
                  TextButton(
                    onPressed: () => _putuskan(d, 'diabaikan'),
                    child: const Text('Abaikan'),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _dibekukan() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').where('dibekukan', isEqualTo: true).limit(100).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
              icon: Icons.error_outline,
              title: 'Daftar tidak dapat dimuat',
              subtitle: 'Periksa koneksi internet.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs.map((d) => UserModel.fromFirestore(d)).toList();
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.lock_open_outlined,
              title: 'Tidak ada akun dibekukan',
              subtitle: 'Akun yang Anda bekukan akan tercatat di sini.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final u = list[i];
            final aktifLagi = !u.terbekukan;
            return kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                    u.suspendPermanen
                        ? 'Permanen'
                        : aktifLagi
                            ? 'Masa bekunya sudah lewat (otomatis aktif lagi)'
                            : 'Sampai ${AppUtils.formatTanggalWaktu(u.suspendSampai!)}',
                    style: TextStyle(
                        color: aktifLagi ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (u.suspendAlasan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(u.suspendAlasan, style: const TextStyle(fontSize: 13)),
                  ),
                const SizedBox(height: 6),
                Row(children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                    onPressed: () => bukaProfil(u.uid, nama: u.nama),
                    child: const Text('Lihat profil'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38), backgroundColor: Colors.green.shade700),
                    onPressed: () => bukaBekuan(uid: u.uid, nama: u.nama),
                    child: Text(aktifLagi ? 'Hapus tanda' : 'Buka sekarang',
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

  Widget _riwayat() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('riwayat_moderasi').orderBy('at', descending: true).limit(100).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
              icon: Icons.history,
              title: 'Belum ada riwayat',
              subtitle: 'Pembekuan dan pembukaan akun tercatat di sini.');
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = docs[i].data();
            final bekukan = m['aksi'] == 'bekukan';
            final t = (m['at'] as Timestamp?)?.toDate();
            return ListTile(
              leading: Icon(bekukan ? Icons.block : Icons.lock_open,
                  color: bekukan ? Colors.red : Colors.green),
              title: Text(
                  '${m['nama']} — ${bekukan ? 'dibekukan (${(m['durasi_hari'] ?? 0) == 0 ? 'permanen' : labelDurasi((m['durasi_hari'] ?? 0) as int)})' : 'dibuka'}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${m['alasan'] ?? ''}\nOleh ${m['oleh']}${t != null ? ' · ${AppUtils.formatTanggalWaktu(t)}' : ''}',
                  style: const TextStyle(fontSize: 12)),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATURAN KOMUNITAS
// ─────────────────────────────────────────────────────────────
class AturanKomunitasView extends StatelessWidget {
  const AturanKomunitasView({super.key});

  Widget _judul(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _butir(IconData ic, Color c, String judul, String contoh) => kartu(
        margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, color: c, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(contoh,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Aturan Komunitas')),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200)),
          child: const Text(
              'Talagasari Hub adalah aplikasi khusus warga Desa Talagasari, Kec. Cikupa, Kab. Tangerang. Pakai dengan sopan supaya desa kita tetap rukun. Pelanggaran bisa dilaporkan warga dan ditindak Admin.',
              style: TextStyle(fontSize: 13.5, height: 1.4)),
        ),
        _judul('1. Ranah aplikasi: hanya Desa Talagasari'),
        _butir(Icons.place_outlined, Colors.green.shade700, 'Semua isi harus tentang Talagasari',
            'Info, jasa, lowongan, lapak UMKM, dan pengaduan hanya untuk kejadian atau usaha di wilayah Desa Talagasari. Contoh yang tidak boleh: info lomba di desa lain, lowongan kerja di luar desa, lapak yang berjualan dan berlokasi di luar Talagasari.'),
        _judul('2. Yang tidak boleh dilakukan'),
        _butir(Icons.public_off_outlined, Colors.orange.shade800, 'Info di luar Talagasari',
            'Jangan menyebarkan info, iklan, atau ajakan yang bukan untuk warga Talagasari.'),
        _butir(Icons.record_voice_over_outlined, Colors.red.shade700,
            'Menjelekkan atau memfitnah',
            'Jangan menjelekkan warga, aparat, usaha, desa ini maupun desa lain. Contoh: "Warung X bikin keracunan" tanpa bukti. Bila ada masalah nyata, pakai fitur Pengaduan.'),
        _butir(Icons.gavel_outlined, Colors.red.shade700, 'Kekerasan, ancaman, dan pelecehan',
            'Dilarang mengancam, mengintimidasi, mengajak berkelahi, atau mengganggu warga lewat chat.'),
        _butir(Icons.sos_outlined, Colors.red.shade700, 'Menyalahgunakan fitur aplikasi',
            'SOS hanya untuk darurat sungguhan. Jangan membuat pengaduan palsu, pesanan atau lamaran main-main, ulasan palsu, atau laporan palsu untuk menjatuhkan orang.'),
        _butir(Icons.report_gmailerrorred_outlined, Colors.red.shade700, 'Hoaks dan kabar bohong',
            'Pastikan info benar sebelum diposting. Kabar bohong membuat warga resah.'),
        _butir(Icons.payments_outlined, Colors.red.shade700, 'Penipuan dan pungli',
            'Dilarang menipu pembeli/pelanggan, meminta uang di muka lalu menghilang, atau memungut biaya tidak resmi. Dilarang menjual barang terlarang (narkoba, miras ilegal, senjata, judi).'),
        _butir(Icons.diversity_3_outlined, Colors.red.shade700, 'SARA dan provokasi',
            'Dilarang menyerang suku, agama, ras, atau mengadu domba warga. Dilarang kampanye politik praktis.'),
        _butir(Icons.no_adult_content, Colors.red.shade700, 'Konten dewasa / tidak pantas',
            'Foto dan kata-kata asusila dilarang.'),
        _butir(Icons.badge_outlined, Colors.red.shade700, 'Akun palsu dan data pribadi orang lain',
            'Jangan memakai nama atau foto orang lain. Jangan menyebar alamat, nomor HP, atau foto orang lain tanpa izin.'),
        _butir(Icons.mark_email_unread_outlined, Colors.orange.shade800, 'Spam',
            'Jangan mengirim promosi atau pesan berulang yang tidak sesuai dengan fiturnya.'),
        _judul('3. Aturan khusus per fitur'),
        _butir(Icons.campaign_outlined, Colors.green.shade700, 'Info Beranda',
            'Isi harus benar, terjadi di Talagasari, dan bermanfaat bagi warga. Foto harus asli (bukan curian). Dilarang beriklan di info atau menyindir orang lain.'),
        _butir(Icons.chat_bubble_outline, Colors.green.shade700, 'Chat',
            'Bicara sopan. Dilarang mengirim pesan berulang yang mengganggu, merayu, menekan, atau meminta uang, kode OTP, PIN, dan data pribadi.'),
        _butir(Icons.handyman_outlined, Colors.green.shade700, 'Jasa (tukang, bengkel, servis, salon, laundry, dll.)',
            'Layanan dan harga harus sesuai deskripsi. Datang sesuai janji. Dilarang membatalkan sepihak tanpa kabar, menaikkan harga seenaknya setelah dipesan, atau memakai foto portofolio milik orang lain. Hanya untuk jasa yang dikerjakan di Talagasari.'),
        _butir(Icons.groups_outlined, Colors.green.shade700, 'Lowongan (Butuh Pekerja)',
            'Pekerjaan harus nyata dan di Talagasari, upah dan syarat ditulis jelas. Dilarang meminta uang pendaftaran, MLM/investasi bodong, atau pekerjaan terlarang.'),
        _butir(Icons.storefront_outlined, Colors.green.shade700, 'Lapak UMKM (jual barang & makanan)',
            'Barang sesuai foto dan deskripsi, harga jelas, makanan layak dan aman. Tandai "habis" bila stok kosong. Dilarang menjual barang terlarang, barang curian, atau berjualan dari luar Talagasari. Bedanya dengan Jasa: Lapak = menjual BARANG, Jasa = menawarkan TENAGA/keahlian.'),
        _butir(Icons.star_half_outlined, Colors.green.shade700, 'Ulasan dan rating',
            'Beri ulasan hanya setelah benar-benar memakai/membeli, jujur dan sopan. Dilarang ulasan palsu, membayar ulasan, atau menjatuhkan pesaing.'),
        _butir(Icons.report_problem_outlined, Colors.green.shade700, 'Pengaduan',
            'Untuk masalah nyata di desa dengan data yang benar. Dilarang mengadukan karena dendam atau mencemarkan nama seseorang.'),
        _butir(Icons.sos_outlined, Colors.green.shade700, 'SOS Darurat',
            'Hanya untuk keadaan darurat sungguhan. SOS iseng atau palsu menghambat bantuan bagi warga yang benar-benar butuh dan dapat dibekukan.'),
        _judul('4. Cara melapor'),
        _butir(Icons.flag_outlined, Colors.blue.shade700, 'Ketuk tanda ⋮ atau tahan pesan',
            'Pada info, komentar, chat, profil, jasa, lowongan, dan lapak ada pilihan "Laporkan". Pilih alasan lalu kirim. Admin yang memeriksa; pelapor tidak diketahui yang dilaporkan.'),
        _judul('5. Sanksi dari Admin'),
        kartu(
          margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Admin menilai tiap kasus dan wajib menuliskan alasan. Pedoman lama pembekuan akun:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            _sanksi('Ringan', '1 – 7 hari', 'kata kasar, spam, info di luar desa'),
            _sanksi('Sedang', '2 minggu – 3 bulan', 'fitnah, hoaks, penyalahgunaan fitur, konten tidak pantas'),
            _sanksi('Berat', '3 bulan – 1 tahun', 'kekerasan/ancaman, penipuan, SARA, pelecehan'),
            _sanksi('Sangat berat / berulang', 'Permanen', 'pelanggaran berat yang diulang atau membahayakan warga'),
            const SizedBox(height: 6),
            const Text('Konten yang melanggar juga dapat dihapus. Merasa dibekukan keliru? Hubungi Admin lewat Pusat Bantuan.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  Widget _sanksi(String t, String lama, String contoh) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 96,
              child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
          Expanded(
            child: Text('$lama — $contoh', style: const TextStyle(fontSize: 12.5, height: 1.3)),
          ),
        ]),
      );
}
