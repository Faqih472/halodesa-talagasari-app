// ============================================================
// info_saya_view.dart
//  • InfoSayaView   : daftar SEMUA info yang pernah diunggah warga (cari + filter
//                     status) dan tombol "Ubah" → pengajuan perubahan.
//  • RevisiInfoTab  : tab Admin/Kades untuk menyetujui atau menolak perubahan.
// Info lama tetap tayang sampai perubahan disetujui. Firestore saja (gratis).
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/village_controller.dart' show AuditLog;
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';
import 'info_form_view.dart' show showFormInformasi;
import 'info_sosial.dart' show GaleriFoto;

String _labelStatus(NewsModel n) {
  switch (n.status) {
    case 'published':
      return 'Tayang';
    case 'menunggu_review_admin':
      return 'Menunggu Admin';
    case 'pending_kades':
      return 'Menunggu Kepala Desa';
    case 'ditolak':
      return 'Ditolak';
    case 'draft':
      return 'Draf';
    default:
      return n.status;
  }
}

Color _warnaStatus(NewsModel n) {
  switch (n.status) {
    case 'published':
      return Colors.green.shade700;
    case 'ditolak':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}

// ─────────────────────────────────────────────────────────────
// INFO SAYA
// ─────────────────────────────────────────────────────────────
class InfoSayaView extends StatefulWidget {
  const InfoSayaView({super.key});

  @override
  State<InfoSayaView> createState() => _InfoSayaViewState();
}

class _InfoSayaViewState extends State<InfoSayaView> {
  final _cari = TextEditingController();
  String _filter = 'semua'; // semua | tayang | menunggu | ditolak | revisi
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '-';
    _stream = FirebaseFirestore.instance
        .collection('announcements')
        .where('authorId', isEqualTo: uid)
        .limit(300)
        .snapshots();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Widget _chip(String id, String label) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: _filter == id,
          onSelected: (_) => setState(() => _filter = id),
        ),
      );

  bool _lolos(NewsModel n) {
    switch (_filter) {
      case 'tayang':
        return n.status == 'published';
      case 'menunggu':
        return n.status == 'menunggu_review_admin' || n.status == 'pending_kades' || n.status == 'draft';
      case 'ditolak':
        return n.status == 'ditolak';
      case 'revisi':
        return n.revisiStatus.isNotEmpty;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final primary = AppTheme.primaryColor(auth.role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Info Saya')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _cari,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari judul atau isi info saya...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _cari.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close), onPressed: () => setState(() => _cari.clear())),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('semua', 'Semua'),
              _chip('tayang', 'Sedang tayang'),
              _chip('menunggu', 'Menunggu persetujuan'),
              _chip('revisi', 'Perubahan diajukan'),
              _chip('ditolak', 'Ditolak'),
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
                    title: 'Info tidak dapat dimuat',
                    subtitle: 'Periksa koneksi internet Anda.');
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final q = _cari.text.trim().toLowerCase();
              final list = snap.data!.docs
                  .map(NewsModel.fromFirestore)
                  .where(_lolos)
                  .where((n) => q.isEmpty || n.judul.toLowerCase().contains(q) || n.isi.toLowerCase().contains(q))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (list.isEmpty) {
                return const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Tidak ada info',
                    subtitle: 'Info yang Anda ajukan lewat tombol "Ajukan Info" akan muncul di sini.');
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 30),
                itemCount: list.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                      child: Text(
                          '${list.length} info. Untuk mengubah info yang sudah tayang, tekan "Ajukan perubahan": info lama tetap tayang sampai Admin menyetujui.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    );
                  }
                  return _Kartu(n: list[i - 1]);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Kartu extends StatelessWidget {
  final NewsModel n;
  const _Kartu({required this.n});

  @override
  Widget build(BuildContext context) {
    final w = warnaKategoriInfo(n.kategori);
    final bisaUbah = n.status == 'published' && !n.adaRevisi;
    return kartu(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _warnaStatus(n), borderRadius: BorderRadius.circular(8)),
            child: Text(_labelStatus(n).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(NewsModel.labelKategori(n.kategori),
                  style: TextStyle(fontSize: 11.5, color: w, fontWeight: FontWeight.w600))),
          Text(AppUtils.formatTanggal(n.createdAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        const SizedBox(height: 6),
        Text(n.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 3),
        Text(n.isi, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4)),
        if (n.semuaFoto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('🖼 ${n.semuaFoto.length} foto${n.punyaLokasi ? '  ·  📍 ada lokasi' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        if (n.status == 'ditolak' && (n.alasanPenolakan ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('Alasan ditolak: ${n.alasanPenolakan}',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12.5)),
          ),
        if (n.adaRevisi)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(
                n.revisiStatus == 'menunggu_kades'
                    ? 'Perubahan menunggu persetujuan Kepala Desa. Info lama tetap tayang.'
                    : 'Perubahan menunggu persetujuan Admin. Info lama tetap tayang.',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 12.5)),
          ),
        if (n.revisiStatus == 'ditolak')
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('Perubahan ditolak: ${n.revisiCatatan}',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12.5)),
          ),
        const SizedBox(height: 6),
        if (n.status == 'published')
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: bisaUbah ? () => showFormInformasi(edit: n) : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(n.adaRevisi ? 'Menunggu persetujuan' : 'Ajukan perubahan'),
            ),
          ),
      ]),
    );
  }
}

Color warnaKategoriInfo(String k) {
  if (AppUtils.isKategoriSensitif(k)) return Colors.red.shade700;
  return Colors.green.shade800;
}

// ─────────────────────────────────────────────────────────────
// ADMIN / KADES: setujui atau tolak perubahan
// ─────────────────────────────────────────────────────────────
class RevisiInfoTab extends StatelessWidget {
  const RevisiInfoTab({super.key});

  Future<void> _setujui(NewsModel n) async {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null) return;
    final r = n.revisi;
    final foto = r['foto_list'] is List ? (r['foto_list'] as List).map((e) => '$e').toList() : <String>[];
    try {
      await FirebaseFirestore.instance.collection('announcements').doc(n.id).update({
        'judul': r['judul'] ?? n.judul,
        'isi': r['isi'] ?? n.isi,
        'kategori': r['kategori'] ?? n.kategori,
        'berlaku_sampai': r['berlaku_sampai'],
        'foto_list': foto,
        'foto_url': foto.isEmpty ? '' : foto.first,
        'lat': r['lat'] ?? 0,
        'lng': r['lng'] ?? 0,
        'lokasi_nama': r['lokasi_nama'] ?? '',
        'edited_at': Timestamp.now(),
        'edited_by': me.uid,
        'revisi': FieldValue.delete(),
        'revisi_status': FieldValue.delete(),
        'revisi_catatan': FieldValue.delete(),
      });
      await AuditLog.catat(
          aksi: 'Menyetujui perubahan info', targetTipe: 'informasi', targetId: n.id, detail: '${r['judul'] ?? n.judul}');
      try {
        await Get.find<NotificationController>().kirimKe(
            uidTujuan: n.authorId,
            judul: 'Perubahan info disetujui',
            isi: '${r['judul'] ?? n.judul}',
            tipe: 'info');
      } catch (_) {}
      showSnack(true, 'Perubahan disetujui dan sudah tayang.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menyetujui. Kategori sensitif hanya dapat disetujui Kepala Desa.');
    }
  }

  Future<void> _tolak(NewsModel n) async {
    final ctrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Tolak perubahan?'),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
            labelText: 'Alasan (wajib, dibaca pembuat)', hintText: 'Contoh: Isi mengandung iklan, mohon diperbaiki.'),
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
        'revisi': FieldValue.delete(),
        'revisi_status': 'ditolak',
        'revisi_catatan': ctrl.text.trim(),
      });
      await AuditLog.catat(
          aksi: 'Menolak perubahan info', targetTipe: 'informasi', targetId: n.id, detail: ctrl.text.trim());
      try {
        await Get.find<NotificationController>().kirimKe(
            uidTujuan: n.authorId,
            judul: 'Perubahan info ditolak',
            isi: '${n.judul}: ${ctrl.text.trim()}',
            tipe: 'info');
      } catch (_) {}
      showSnack(true, 'Perubahan ditolak. Info lama tetap tayang.', '');
    } catch (_) {
      showSnack(false, '', 'Gagal menolak. Kategori sensitif hanya dapat diputuskan Kepala Desa.');
    }
  }

  Widget _banding(String label, String sebelum, String sesudah) {
    if (sebelum == sesudah) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
          child: Text('Sebelum: $sebelum', style: const TextStyle(fontSize: 12.5)),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
          child: Text('Sesudah: $sesudah', style: const TextStyle(fontSize: 12.5)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final kades = auth.role == 'kades';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('revisi_status', whereIn: ['diajukan', 'menunggu_kades'])
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
              icon: Icons.error_outline, title: 'Tidak dapat memuat', subtitle: 'Periksa koneksi internet.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.docs.map(NewsModel.fromFirestore).toList()
          ..sort((a, b) => ((b.revisi['diajukan_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
              .compareTo((a.revisi['diajukan_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
        if (list.isEmpty) {
          return const EmptyState(
              icon: Icons.edit_note_outlined,
              title: 'Tidak ada perubahan menunggu',
              subtitle: 'Pengajuan perubahan info dari warga akan muncul di sini.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            final r = n.revisi;
            final katBaru = '${r['kategori'] ?? n.kategori}';
            final sensitif = AppUtils.isKategoriSensitif(katBaru) || AppUtils.isKategoriSensitif(n.kategori);
            final bolehPutus = kades || !sensitif;
            final fotoBaru = r['foto_list'] is List ? (r['foto_list'] as List).map((e) => '$e').toList() : <String>[];
            final lokBaru = '${r['lokasi_nama'] ?? ''}';
            return kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text(n.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  if (sensitif)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(6)),
                      child: const Text('SENSITIF', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                ]),
                if ('${r['alasan_ubah'] ?? ''}'.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('Alasan pembuat: ${r['alasan_ubah']}', style: const TextStyle(fontSize: 12.5)),
                  ),
                _banding('Judul', n.judul, '${r['judul'] ?? n.judul}'),
                _banding('Isi', n.isi, '${r['isi'] ?? n.isi}'),
                _banding('Kategori', NewsModel.labelKategori(n.kategori), NewsModel.labelKategori(katBaru)),
                _banding('Jumlah foto', '${n.semuaFoto.length}', '${fotoBaru.length}'),
                _banding('Lokasi', n.lokasiNama.isEmpty ? '-' : n.lokasiNama, lokBaru.isEmpty ? '-' : lokBaru),
                if (fotoBaru.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: GaleriFoto(foto: fotoBaru)),
                const SizedBox(height: 8),
                if (!bolehPutus)
                  Text('Kategori sensitif: perubahan hanya dapat diputuskan Kepala Desa.',
                      style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900))
                else
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 44), backgroundColor: Colors.green.shade700),
                        onPressed: () => _setujui(n),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Setujui'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44), foregroundColor: Colors.red.shade700),
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
