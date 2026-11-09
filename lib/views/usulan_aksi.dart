import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/ui_helpers.dart' show showSnack;

/// Ubah usulan milik sendiri (hanya selama masih "Menunggu").
Future<void> ubahUsulanWarga(DocumentSnapshot<Map<String, dynamic>> d, {required bool agenda}) async {
  final m = d.data() ?? {};
  final a = TextEditingController(text: '${m[agenda ? 'judul' : 'pertanyaan'] ?? ''}');
  final b = TextEditingController(text: '${m[agenda ? 'isi' : 'alasan'] ?? ''}');
  final c = TextEditingController(
      text: agenda ? '${m['lokasi'] ?? ''}' : ((m['opsi_saran'] as List?) ?? const []).join('\n'));
  final e = TextEditingController(text: agenda ? '${m['waktu_saran'] ?? ''}' : '');
  final ok = await Get.dialog<bool>(AlertDialog(
    title: const Text('Ubah usulan'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: a,
            maxLines: 2,
            decoration: InputDecoration(labelText: agenda ? 'Nama kegiatan' : 'Pertanyaan')),
        const SizedBox(height: 8),
        TextField(
            controller: b,
            maxLines: 3,
            decoration: InputDecoration(labelText: agenda ? 'Penjelasan' : 'Alasan perlu dibahas')),
        const SizedBox(height: 8),
        TextField(
            controller: c,
            maxLines: agenda ? 1 : 4,
            decoration: InputDecoration(
                labelText: agenda ? 'Lokasi usulan' : 'Pilihan jawaban (satu baris satu)')),
        if (agenda) ...[
          const SizedBox(height: 8),
          TextField(controller: e, decoration: const InputDecoration(labelText: 'Waktu usulan')),
        ],
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
          onPressed: () {
            if (a.text.trim().length < 5 || b.text.trim().length < 10) {
              showSnack(false, '', 'Judul minimal 5 huruf dan penjelasan minimal 10 huruf.');
              return;
            }
            Get.back(result: true);
          },
          child: const Text('Simpan')),
    ],
  ));
  if (ok != true) return;
  try {
    await d.reference.update(agenda
        ? {
            'judul': a.text.trim(),
            'isi': b.text.trim(),
            'lokasi': c.text.trim(),
            'waktu_saran': e.text.trim(),
          }
        : {
            'pertanyaan': a.text.trim(),
            'alasan': b.text.trim(),
            'opsi_saran':
                c.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).take(8).toList(),
          });
    showSnack(true, 'Usulan diperbarui.', '');
  } catch (_) {
    showSnack(false, '', 'Gagal menyimpan. Usulan mungkin sudah diproses petugas.');
  }
}

/// Tarik kembali (hapus) usulan milik sendiri selama masih "Menunggu".
Future<void> tarikUsulanWarga(DocumentSnapshot<Map<String, dynamic>> d) async {
  final ok = await Get.dialog<bool>(AlertDialog(
    title: const Text('Tarik kembali usulan?'),
    content: const Text('Usulan akan dihapus. Anda bisa mengusulkan lagi kapan saja.'),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Kembali')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 42), backgroundColor: Colors.red.shade700),
          onPressed: () => Get.back(result: true),
          child: const Text('Tarik')),
    ],
  ));
  if (ok != true) return;
  try {
    await d.reference.delete();
    showSnack(true, 'Usulan ditarik kembali.', '');
  } catch (_) {
    showSnack(false, '', 'Gagal. Usulan mungkin sudah diproses petugas.');
  }
}

/// Baris tombol Ubah / Tarik untuk kartu usulan warga.
Widget barisAksiUsulanWarga(DocumentSnapshot<Map<String, dynamic>> d, {required bool agenda}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => ubahUsulanWarga(d, agenda: agenda),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ubah'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40), foregroundColor: Colors.red.shade700),
          onPressed: () => tarikUsulanWarga(d),
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Tarik kembali'),
        ),
      ),
    ]),
  );
}
