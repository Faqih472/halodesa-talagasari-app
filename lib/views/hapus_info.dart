import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../controllers/chat_controller.dart' show NotificationController;
import '../controllers/village_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';

/// Alasan hapus siap pakai. Setiap pilihan mengisi contoh kalimat yang boleh diubah.
const List<(String, String)> alasanHapusInfo = [
  ('Sudah tidak berlaku', 'Acara atau kegiatan sudah selesai dan informasinya sudah tidak berlaku lagi.'),
  ('Informasi salah', 'Terdapat kesalahan data pada informasi ini (tanggal, tempat, atau nominal) sehingga perlu dihapus.'),
  ('Duplikat', 'Informasi yang sama sudah diunggah sebelumnya sehingga yang ini dihapus agar tidak ganda.'),
  ('Melanggar aturan', 'Isi informasi melanggar aturan komunitas (mengandung hoaks, SARA, atau kata kasar).'),
  ('Bukan info desa', 'Isi informasi bukan kepentingan warga Desa Talagasari atau berupa iklan yang tidak pantas.'),
  ('Data pribadi', 'Informasi memuat data pribadi warga (nomor telepon, alamat, atau foto) yang tidak boleh disebar.'),
  ('Permintaan pembuat', 'Pembuat informasi meminta informasi ini dihapus karena sudah tidak diperlukan.'),
  ('Lainnya', ''),
];

/// Lembar pilih alasan. Mengembalikan teks alasan atau null bila dibatalkan.
const List<(String, String)> alasanHapusPolling = [
  ('Salah buat', 'Topik ini salah dibuat (pertanyaan atau pilihan keliru) dan akan dibuat ulang dengan benar.'),
  ('Sudah diputuskan', 'Hal ini sudah diputuskan dalam musyawarah langsung sehingga pemungutan suara tidak diperlukan.'),
  ('Duplikat', 'Topik yang sama sudah ada sebelumnya sehingga yang ini dihapus agar tidak ganda.'),
  ('Tidak relevan', 'Topik tidak lagi relevan atau bukan kewenangan desa.'),
  ('Lainnya', ''),
];

const List<(String, String)> alasanHapusAgenda = [
  ('Salah buat', 'Agenda ini salah dibuat dan akan dibuat ulang dengan data yang benar.'),
  ('Duplikat', 'Agenda yang sama sudah ada sebelumnya sehingga yang ini dihapus agar tidak ganda.'),
  ('Kegiatan tidak jadi', 'Kegiatan tidak jadi dilaksanakan dan sudah diumumkan kepada warga.'),
  ('Lainnya', ''),
];

const List<(String, String)> alasanBatalAduan = [
  ('Sudah selesai', 'Masalah sudah selesai diatasi sendiri sehingga pengaduan tidak diperlukan lagi.'),
  ('Salah kirim', 'Pengaduan terkirim tidak sengaja atau isinya salah, akan saya buat ulang dengan benar.'),
  ('Sudah ditangani RT/RW', 'Masalah sudah ditangani oleh pengurus RT/RW setempat.'),
  ('Dobel', 'Pengaduan ini sama dengan pengaduan lain yang sudah saya kirim.'),
  ('Lainnya', ''),
];

const List<(String, String)> alasanHapusLapak = [
  ('Usaha tutup', 'Usaha sudah tutup permanen sehingga lapak ini tidak diperlukan lagi.'),
  ('Berhenti berjualan', 'Saya berhenti berjualan dan ingin lapak ini dihapus.'),
  ('Dibuat ganda', 'Lapak ini sama dengan lapak lain yang sudah saya buat sebelumnya.'),
  ('Data salah', 'Data lapak salah dan akan saya buat ulang dengan data yang benar.'),
  ('Pindah dari desa', 'Saya pindah dari Desa Talagasari sehingga lapak ini dihapus.'),
  ('Lainnya', ''),
];

Future<String?> dialogAlasanHapusInfo({
  required String judulInfo,
  bool ajukan = false,
  String? awal,
  List<(String, String)>? daftar,
  String? judulSheet,
  String? tombol,
}) {
  final ctrl = TextEditingController();
  String? terpilih;
  final warna = Colors.red.shade700;
  return Get.bottomSheet<String>(
    StatefulBuilder(builder: (ctx, setS) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.delete_outline, color: warna),
              const SizedBox(width: 8),
              Expanded(
                child: Text(judulSheet ?? (ajukan ? 'Ajukan hapus info' : 'Hapus info'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('"$judulInfo"', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                ajukan
                    ? 'Tetap tayang sampai Admin menyetujui. Pilih alasan, lalu ubah kalimatnya bila perlu.'
                    : 'Pembuat info akan diberi tahu beserta alasannya. Pilih alasan, lalu ubah kalimatnya bila perlu.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final a in (daftar ?? alasanHapusInfo))
                ChoiceChip(
                  label: Text(a.$1, style: TextStyle(fontSize: 12.5, color: terpilih == a.$1 ? Colors.white : null)),
                  selected: terpilih == a.$1,
                  selectedColor: warna,
                  onSelected: (_) => setS(() {
                    terpilih = a.$1;
                    ctrl.text = a.$2;
                    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Alasan (wajib, minimal 10 huruf)',
                hintText: 'Contoh: Acara sudah selesai pada hari Minggu lalu.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () => Get.back(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: warna),
                  onPressed: () {
                    final t = ctrl.text.trim();
                    if (t.length < 10) {
                      showSnack(false, '', 'Alasan wajib diisi, minimal 10 huruf. Pilih salah satu contoh di atas.');
                      return;
                    }
                    Get.back(result: t);
                  },
                  child: Text(tombol ?? (ajukan ? 'Kirim ke Admin' : 'Hapus'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      );
    }),
    isScrollControlled: true,
  );
}

/// Staf (Admin/Kades): hapus langsung, tetapi wajib ada alasan.
Future<void> konfirmasiHapusInformasi(NewsModel n) async {
  final alasan = await dialogAlasanHapusInfo(judulInfo: n.judul);
  if (alasan == null) return;
  final dataCtrl = Get.find<DataController>();
  final ok = await dataCtrl.hapusInformasi(n, alasan: alasan);
  showSnack(ok, 'Informasi dihapus. Pembuat diberi tahu alasannya.', dataCtrl.errorMsg.value);
}

/// Warga: ajukan hapus info miliknya (perlu ACC Admin).
Future<void> ajukanHapusInfo(NewsModel n) async {
  final alasan = await dialogAlasanHapusInfo(judulInfo: n.judul, ajukan: true);
  if (alasan == null) return;
  try {
    final u = Get.find<AuthController>().currentUser.value!;
    await FirebaseFirestore.instance.collection('announcements').doc(n.id).update({
      'hapus_status': 'diajukan',
      'hapus_alasan': alasan,
      'hapus_at': Timestamp.now(),
    });
    final sensitif = AppUtils.isKategoriSensitif(n.kategori);
    await notifPeran(sensitif ? ['admin', 'kades'] : ['admin'],
        judul: 'Permintaan hapus info', isi: '${u.nama}: ${n.judul}', tipe: 'info', targetId: n.id);
    showSnack(true, 'Permintaan hapus terkirim. Info tetap tayang sampai Admin menyetujui.', '');
  } catch (_) {
    showSnack(false, '', 'Gagal mengirim permintaan. Coba lagi.');
  }
}

/// Tab Admin/Kades: permintaan hapus info dari warga.
class HapusInfoTab extends StatelessWidget {
  const HapusInfoTab({super.key});

  Future<void> _setujui(NewsModel n) async {
    final ok = await Get.find<DataController>()
        .hapusInformasi(n, alasan: 'Atas permintaan pembuat. ${n.hapusAlasan}');
    showSnack(ok, 'Info dihapus sesuai permintaan.', Get.find<DataController>().errorMsg.value);
  }

  Future<void> _tolak(NewsModel n) async {
    final ctrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Tolak permintaan hapus'),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
            labelText: 'Alasan menolak (wajib)',
            hintText: 'Contoh: Info masih dibutuhkan warga sampai akhir bulan.'),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42), backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (ctrl.text.trim().length < 10) {
                showSnack(false, '', 'Alasan wajib diisi (minimal 10 huruf).');
                return;
              }
              Get.back(result: true);
            },
            child: const Text('Tolak')),
      ],
    ));
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('announcements').doc(n.id).update({
        'hapus_status': 'ditolak',
        'hapus_alasan': FieldValue.delete(),
        'hapus_catatan': ctrl.text.trim(),
      });
      await AuditLog.catat(
          aksi: 'Menolak permintaan hapus info', targetTipe: 'informasi', targetId: n.id, detail: ctrl.text.trim());
      try {
        await Get.find<NotificationController>().kirimKe(
            uidTujuan: n.authorId,
            judul: 'Permintaan hapus ditolak',
            isi: '${n.judul}: ${ctrl.text.trim()}',
            tipe: 'info');
      } catch (_) {}
      showSnack(true, 'Permintaan ditolak. Info tetap tayang.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal. Kategori sensitif hanya dapat diputuskan Kepala Desa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kades = Get.find<AuthController>().role == 'kades';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('hapus_status', isEqualTo: 'diajukan')
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(icon: Icons.error_outline, title: 'Tidak dapat memuat', subtitle: 'Periksa koneksi internet.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs.map(NewsModel.fromFirestore).toList();
        if (list.isEmpty) {
          return EmptyState(
              icon: Icons.delete_outline,
              title: 'Tidak ada permintaan hapus',
              subtitle: 'Warga yang ingin menghapus info miliknya akan muncul di sini.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20, top: 6),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            final bolehPutus = kades || !AppUtils.isKategoriSensitif(n.kategori);
            return kartuGaris(
              warna: Colors.red.shade700,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${NewsModel.labelKategori(n.kategori)}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text('Alasan pembuat: ${n.hapusAlasan}',
                      style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.35)),
                ),
                const SizedBox(height: 10),
                if (!bolehPutus)
                  Text('Kategori sensitif: hanya Kepala Desa yang dapat memutuskan.',
                      style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900))
                else
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: Colors.red.shade700),
                        onPressed: () => _setujui(n),
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: const Text('Setujui hapus'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => _tolak(n),
                        icon: const Icon(Icons.close),
                        label: const Text('Tolak'),
                      ),
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
