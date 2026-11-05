// ============================================================
// info_sosial.dart — Interaksi informasi desa ala media sosial:
// galeri foto, suka, komentar, simpan, bagikan, dan pemilih kategori
// berkelompok. Semua gratis (Firestore saja, tanpa Storage/Functions).
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart' show NotificationController;
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';
import 'moderasi_view.dart';
import 'verification_view.dart' show wajibVerifikasi;

// ── Simpan (bookmark) — disimpan di perangkat ──
class InfoSimpan {
  static final GetStorage _box = GetStorage();
  static final RxList<String> daftar =
      List<String>.from(_box.read('info_tersimpan') ?? const []).obs;
  static bool ada(String id) => daftar.contains(id);
  static void toggle(String id) {
    if (!daftar.remove(id)) daftar.add(id);
    _box.write('info_tersimpan', daftar.toList());
  }
}

final Set<String> _sudahDilihat = {};

/// Hitung "dilihat" sekali per sesi aplikasi.
Future<void> catatDilihat(String id) async {
  if (!_sudahDilihat.add(id)) return;
  try {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .update({'dilihat': FieldValue.increment(1)});
  } catch (_) {}
}

// ── Galeri foto (geser kiri-kanan, titik penanda) ──
class GaleriFoto extends StatefulWidget {
  final List<String> foto;
  final double tinggi;
  const GaleriFoto({super.key, required this.foto, this.tinggi = 220});
  @override
  State<GaleriFoto> createState() => _GaleriFotoState();
}

class _GaleriFotoState extends State<GaleriFoto> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final f = widget.foto;
    if (f.isEmpty) return const SizedBox.shrink();
    if (f.length == 1) return fotoFull(f.first, radius: 14);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: widget.tinggi,
          child: Stack(children: [
            PageView.builder(
              itemCount: f.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, k) => GestureDetector(
                onTap: () => tampilkanFoto(f[k]),
                child: Container(
                  color: Colors.grey.shade100,
                  child: ImageUtil.image(f[k], fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_i + 1}/${f.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            f.length,
            (k) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k == _i
                          ? AppTheme.textPrimary
                          : Colors.grey.shade300),
                )),
      ),
    ]);
  }
}

// ── Baris aksi: Reaksi · Komentar · Simpan · Bagikan ──
// Reaksi ala Facebook/WhatsApp: ketuk = 👍, tahan = pilih emoji lain.
class InfoAksi extends StatelessWidget {
  final NewsModel news;
  const InfoAksi({super.key, required this.news});

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('announcements').doc(news.id);

  /// emoji == null → hapus reaksi. [lama] = reaksi sebelumnya (null bila belum ada).
  Future<void> _reaksi(String? lama, String? emoji) async {
    final uid = Get.find<AuthController>().currentUser.value?.uid;
    if (uid == null) return;
    try {
      final s = _ref.collection('suka').doc(uid);
      if (emoji == null) {
        final b = FirebaseFirestore.instance.batch();
        b.delete(s);
        b.update(_ref, {'jumlah_suka': FieldValue.increment(-1)});
        await b.commit();
      } else if (lama == null) {
        final b = FirebaseFirestore.instance.batch();
        b.set(s, {'at': Timestamp.now(), 'emoji': emoji});
        b.update(_ref, {'jumlah_suka': FieldValue.increment(1)});
        await b.commit();
      } else {
        await s.update({'emoji': emoji});
      }
    } catch (_) {
      showSnack(false, '', 'Gagal. Periksa koneksi internet.');
    }
  }

  void _bagikan() {
    final t = '${news.judul}\n\n${news.isi}\n\n— Info Desa Talagasari (Talagasari Hub)';
    Clipboard.setData(ClipboardData(text: t));
    showSnack(true, 'Teks disalin. Tempel di WhatsApp atau aplikasi lain.', '');
  }

  Widget _tombol(IconData ic, String teks, Color c, VoidCallback f, {VoidCallback? tahan}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: f,
        onLongPress: tahan,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, size: 19, color: c),
            const SizedBox(width: 4),
            Flexible(
              child: Text(teks,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: c, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(String me) {
    if (news.authorId.isEmpty) return const SizedBox.shrink();
    return _PenulisInfo(news: news, saya: me);
  }

  @override
  Widget build(BuildContext context) {
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final int suka = (d['jumlah_suka'] ?? 0) as int;
        final int kom = (d['jumlah_komentar'] ?? 0) as int;
        final int lihat = (d['dilihat'] ?? 0) as int;
        return Column(children: [
          _header(uid),
          if (suka > 0 || kom > 0 || lihat > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                if (suka > 0)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _ref.collection('suka').limit(100).snapshots(),
                    builder: (_, ss) {
                      final hitung = <String, int>{};
                      for (final x in ss.data?.docs ?? const []) {
                        final e = '${x.data()['emoji'] ?? '👍'}';
                        hitung[e] = (hitung[e] ?? 0) + 1;
                      }
                      final urut = hitung.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final ikon = urut.isEmpty ? '👍' : urut.take(3).map((e) => e.key).join();
                      return Text('$ikon $suka  ',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary));
                    },
                  ),
                if (kom > 0) Text('$kom komentar  ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const Spacer(),
                if (lihat > 0)
                  Text('$lihat dilihat',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
          const Divider(height: 10),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _ref.collection('suka').doc(uid).snapshots(),
            builder: (context, ss) {
              final sudah = ss.data?.exists ?? false;
              final String? emoji =
                  sudah ? '${ss.data!.data()?['emoji'] ?? '👍'}' : null;
              Future<void> pilih() async {
                final e = await pilihEmoji(sekarang: emoji);
                if (e != null) await _reaksi(emoji, e);
              }

              return Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _reaksi(emoji, sudah ? null : '👍'),
                    onLongPress: pilih,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        sudah
                            ? Text(emoji!, style: const TextStyle(fontSize: 18))
                            : const Icon(Icons.thumb_up_alt_outlined,
                                size: 19, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(sudah ? 'Reaksi' : 'Suka',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sudah ? Colors.blue.shade700 : AppTheme.textSecondary)),
                      ]),
                    ),
                  ),
                ),
                _tombol(Icons.chat_bubble_outline, 'Komentar',
                    AppTheme.textSecondary, () => bukaKomentar(news)),
                Obx(() {
                  final s = InfoSimpan.ada(news.id);
                  return _tombol(
                      s ? Icons.bookmark : Icons.bookmark_border,
                      s ? 'Tersimpan' : 'Simpan',
                      s ? Colors.orange.shade800 : AppTheme.textSecondary,
                      () {
                    InfoSimpan.toggle(news.id);
                    showSnack(true,
                        s ? 'Dihapus dari simpanan.' : 'Disimpan. Lihat lewat filter "Tersimpan".', '');
                  });
                }),
                _tombol(Icons.share_outlined, 'Bagikan',
                    AppTheme.textSecondary, _bagikan),
              ]);
            },
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 6, bottom: 2),
              child: Text('Tahan tombol Suka untuk memilih emoji lain',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Pembuat info: ketuk untuk melihat profil, ⋮ untuk laporkan ──
class _PenulisInfo extends StatefulWidget {
  final NewsModel news;
  final String saya;
  const _PenulisInfo({required this.news, required this.saya});

  @override
  State<_PenulisInfo> createState() => _PenulisInfoState();
}

class _PenulisInfoState extends State<_PenulisInfo> {
  static final Map<String, Map<String, dynamic>> _cache = {};
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _d = _cache[widget.news.authorId];
    if (_d == null) _muat();
  }

  Future<void> _muat() async {
    try {
      final x = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.news.authorId)
          .get();
      final m = x.data();
      if (m != null) {
        _cache[widget.news.authorId] = {
          'nama': m['nama'] ?? 'Warga',
          'role': m['role'] ?? 'warga',
          'foto': m['foto_url'] ?? '',
        };
        if (mounted) setState(() => _d = _cache[widget.news.authorId]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nama = '${_d?['nama'] ?? '...'}';
    final peran = '${_d?['role'] ?? 'warga'}';
    final foto = '${_d?['foto'] ?? ''}';
    final milik = widget.saya == widget.news.authorId;
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: () => bukaProfil(widget.news.authorId, nama: nama),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: foto.isNotEmpty ? ImageUtil.provider(foto) : null,
                child: foto.isEmpty
                    ? Text(AppUtils.inisial(nama), style: const TextStyle(fontSize: 10))
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(nama,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              if (peran != 'warga')
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(AppTheme.labelRole(peran),
                      style: TextStyle(fontSize: 10.5, color: Colors.green.shade800)),
                ),
            ]),
          ),
        ),
      ),
      if (!milik)
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
          onSelected: (v) {
            if (v == 'profil') {
              bukaProfil(widget.news.authorId, nama: nama);
            } else {
              laporkan(
                tipe: 'info',
                targetId: widget.news.id,
                targetUid: widget.news.authorId,
                targetNama: nama,
                cuplikan: widget.news.judul,
                targetPath: 'announcements/${widget.news.id}',
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profil', child: Text('Lihat profil')),
            PopupMenuItem(value: 'lapor', child: Text('Laporkan info ini')),
          ],
        ),
    ]);
  }
}

// ── Komentar ──
Future<void> bukaKomentar(NewsModel news) async {
  final auth = Get.find<AuthController>();
  final ref =
      FirebaseFirestore.instance.collection('announcements').doc(news.id);
  final ctrl = TextEditingController();
  bool kirim = false;

  await Get.bottomSheet(
    StatefulBuilder(builder: (ctx, setS) {
      Future<void> kirimKomentar() async {
        final teks = ctrl.text.trim();
        if (teks.isEmpty || kirim) return;
        if (auth.role == 'warga' && !await wajibVerifikasi()) return;
        final u = auth.currentUser.value;
        if (u == null) return;
        setS(() => kirim = true);
        try {
          final b = FirebaseFirestore.instance.batch();
          b.set(ref.collection('komentar').doc(), {
            'uid': u.uid,
            'nama': u.nama,
            'peran': u.role,
            'isi': teks,
            'created_at': Timestamp.now(),
          });
          b.update(ref, {'jumlah_komentar': FieldValue.increment(1)});
          await b.commit();
          ctrl.clear();
          if (news.authorId.isNotEmpty && news.authorId != u.uid) {
            try {
              await Get.find<NotificationController>().kirimKe(
                uidTujuan: news.authorId,
                judul: 'Komentar baru',
                isi: '${u.nama}: ${teks.length > 60 ? '${teks.substring(0, 60)}...' : teks}',
                tipe: 'info',
                targetId: news.id,
              );
            } catch (_) {}
          }
        } catch (_) {
          showSnack(false, '', 'Gagal mengirim komentar.');
        }
        setS(() => kirim = false);
      }

      return Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
            padding: EdgeInsets.all(12),
            child: Text('Komentar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref
                  .collection('komentar')
                  .orderBy('created_at', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('Belum ada komentar. Jadilah yang pertama.',
                          style: TextStyle(color: AppTheme.textSecondary)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final milik = d['uid'] == auth.currentUser.value?.uid;
                    final peran = (d['peran'] ?? 'warga') as String;
                    final t = (d['created_at'] as Timestamp?)?.toDate();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: () => bukaProfil('${d['uid'] ?? ''}',
                                      nama: '${d['nama'] ?? ''}'),
                                  child: Text('${d['nama'] ?? 'Warga'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13))),
                              ),
                              if (peran != 'warga')
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(AppTheme.labelRole(peran),
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.green.shade800)),
                                ),
                              const Spacer(),
                              if (t != null)
                                Text(AppUtils.formatRelatif(t),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                              if (milik || auth.isStaff)
                                InkWell(
                                  onTap: () async {
                                    final b =
                                        FirebaseFirestore.instance.batch();
                                    b.delete(docs[i].reference);
                                    b.update(ref, {
                                      'jumlah_komentar':
                                          FieldValue.increment(-1)
                                    });
                                    try {
                                      await b.commit();
                                    } catch (_) {}
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.delete_outline,
                                        size: 16, color: Colors.red),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Text('${d['isi'] ?? ''}',
                                style: const TextStyle(fontSize: 13.5)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Builder(builder: (_) {
                                final reaksi = bacaReaksi(d['reaksi']);
                                final uidSaya = auth.currentUser.value?.uid ?? '';
                                final mine = reaksi[uidSaya];
                                return InkWell(
                                  onTap: () =>
                                      setReaksiDoc(docs[i].reference, mine == null ? '👍' : null),
                                  onLongPress: () async {
                                    final e = await pilihEmoji(sekarang: mine);
                                    if (e != null) await setReaksiDoc(docs[i].reference, e);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                    child: Text(mine ?? 'Suka 👍',
                                        style: TextStyle(
                                            fontSize: mine != null ? 17 : 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700)),
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              lencanaReaksi(bacaReaksi(d['reaksi'])),
                              const Spacer(),
                              if (!milik)
                                InkWell(
                                  onTap: () => laporkan(
                                    tipe: 'komentar',
                                    targetId: docs[i].id,
                                    targetUid: '${d['uid'] ?? ''}',
                                    targetNama: '${d['nama'] ?? 'Warga'}',
                                    cuplikan: '${d['isi'] ?? ''}',
                                    targetPath: 'announcements/${news.id}/komentar/${docs[i].id}',
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Text('Laporkan',
                                        style: TextStyle(fontSize: 11, color: Colors.red)),
                                  ),
                                ),
                            ]),
                          ]),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Tulis komentar sopan...',
                      counterText: '',
                      border: OutlineInputBorder()),
                ),
              ),
              IconButton(
                onPressed: kirim ? null : kirimKomentar,
                icon: Icon(Icons.send, color: AppTheme.primaryColor(auth.role)),
              ),
            ]),
          ),
        ]),
      );
    }),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

// ── Pemilih kategori berkelompok ──
Future<String?> pilihKategoriInfo(String sekarang, bool staf) {
  return Get.bottomSheet<String>(
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
          child: Text('Pilih jenis informasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
              'Pilih yang paling cocok dengan isi info Anda. Contoh tertulis di bawah tiap pilihan.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            children: NewsModel.kelompokInfo.map((g) {
              final isi = g['isi'] as List;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                        child: Text('${g['label']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                      ...isi.map((k) {
                        final v = k['value'] as String;
                        final pilih = v == sekarang;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: pilih ? Colors.green.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: pilih
                                    ? Colors.green.shade600
                                    : Colors.grey.shade300),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () => Get.back(result: v),
                            title: Text(
                                AppUtils.labelKategoriForm(
                                    v, k['label'] as String, staf),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: Text('${k['contoh']}',
                                style: const TextStyle(fontSize: 11.5)),
                            trailing: pilih
                                ? Icon(Icons.check_circle,
                                    color: Colors.green.shade700)
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
}
