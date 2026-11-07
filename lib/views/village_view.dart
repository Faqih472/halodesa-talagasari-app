// ============================================================
// village_view.dart — Layanan Desa: Hub menu dan SOS (Suara Warga di polling_view, Agenda di agenda_view)
// ============================================================

import '../controllers/complaint_controller.dart' show ComplaintController;
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/village_controller.dart';
import '../core/app_contact.dart';
import '../core/core.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'admin_tools_view.dart';
import 'agenda_view.dart' show AgendaListView;
import 'polling_view.dart' show PollListView;
import 'letter_view.dart';

// ============================================================
// HUB — kumpulan pintu masuk layanan di Beranda (menurut peran)
// ============================================================
class _Menu {
  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;
  final Query<Map<String, dynamic>>? q; // antrean live (staf)
  final int Function()? rx; // antrean dari controller (staf)
  _Menu(this.icon, this.label, this.warna, this.onTap, {this.q, this.rx});
}

/// Tanda antrean pada ikon menu (khusus staf): angka merah bila ada, centang hijau bila beres.
class _TileLencana extends StatelessWidget {
  final _Menu m;
  final Widget child;
  const _TileLencana({required this.m, required this.child});

  Widget _tanda(int n) => Positioned(
        right: -4,
        top: -4,
        child: n > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(n > 99 ? '99+' : '$n',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
              )
            : Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, size: 17, color: Colors.green.shade500)),
      );

  @override
  Widget build(BuildContext context) {
    if (m.q != null) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: m.q!.snapshots(),
        builder: (_, snap) => Stack(clipBehavior: Clip.none, children: [
          child,
          if (snap.hasData) _tanda(snap.data!.size),
        ]),
      );
    }
    if (m.rx != null) {
      return Obx(() => Stack(clipBehavior: Clip.none, children: [child, _tanda(m.rx!())]));
    }
    return child;
  }
}

class LayananDesaSection extends StatelessWidget {
  const LayananDesaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();

    return Obx(() {
      final u = auth.currentUser.value;
      if (u == null) return const SizedBox.shrink();
      final Color primary = AppTheme.primaryColor(u.role);
      final bool staf = u.role != 'warga';

      // Menu ringkas: 4 untuk warga, 5 untuk staf.
      // (Statistik, Audit Log, Laporan Jasa ada di menu Akun.)
      final List<_Menu> menu = [
        if (!staf)
          _Menu(Icons.sos, 'hub_sos'.tr, Colors.red.shade700,
              () => Get.to(() => const SosView())),
        _Menu(Icons.description_outlined, 'hub_letter'.tr, primary,
            () => Get.to(() => const LetterHomeView()),
            rx: staf ? () => Get.find<LetterController>().antrian.length : null),
        _Menu(Icons.how_to_vote_outlined, 'hub_poll'.tr, primary,
            () => Get.to(() => const PollListView()),
            q: staf ? FirebaseFirestore.instance.collection('usulan_polling').where('status', isEqualTo: 'baru').limit(99) : null),
        _Menu(Icons.event_outlined, 'hub_agenda'.tr, primary,
            () => Get.to(() => const AgendaListView()),
            q: staf ? FirebaseFirestore.instance.collection('usulan_agenda').where('status', isEqualTo: 'baru').limit(99) : null),
        if (staf)
          _Menu(Icons.sos, 'hub_sos_log'.tr, Colors.red.shade700,
              () => Get.to(() => const SosView()),
              q: FirebaseFirestore.instance.collection('sos').where('status', isEqualTo: 'baru').limit(99)),
        if (staf)
          _Menu(Icons.map_outlined, 'hub_complaint_map'.tr, primary,
              () => Get.to(() => const ComplaintMapView()),
              rx: () => Get.find<ComplaintController>().antrian.length),
      ];

      return Container(
        decoration: kartuTalagasari(radius: 24),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JudulBagian('hub_title'.tr,
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 4)),
            LayoutBuilder(builder: (context, box) {
              final int kolom = menu.length > 4 ? 5 : 4;
              final double lebar = box.maxWidth / kolom;
              return Wrap(
                runSpacing: 4,
                children: menu
                    .map((m) => SizedBox(
                          width: lebar,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: m.onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TileLencana(
                                    m: m,
                                    child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          m.warna.withOpacity(0.16),
                                          m.warna.withOpacity(0.07),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: m.warna.withOpacity(0.22)),
                                    ),
                                    child: Icon(m.icon,
                                        color: m.warna, size: 25),
                                  )),
                                  const SizedBox(height: 6),
                                  Text(m.label,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11, height: 1.2)),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            }),
          ],
        ),
      );
    });
  }
}

// ============================================================
// SOS — warga: tombol darurat (tahan 3 detik); staf: riwayat SOS
// ============================================================
class SosView extends StatelessWidget {
  const SosView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final bool staf = auth.isStaff;
    final Color merah = Colors.red.shade700;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(staf ? 'sos_log_title'.tr : 'sos_title'.tr),
        backgroundColor: merah,
      ),
      body: staf ? const _SosStafTabs() : const _SosWarga(),
    );
  }
}

class _SosWarga extends StatefulWidget {
  const _SosWarga();

  @override
  State<_SosWarga> createState() => _SosWargaState();
}

class _SosWargaState extends State<_SosWarga>
    with SingleTickerProviderStateMixin {
  final SosController _ctrl = Get.find<SosController>();
  late final AnimationController _anim;
  String _jenis = '';
  final _ket = TextEditingController();
  File? _foto;

  static const Map<String, IconData> _ikon = {
    'medis': Icons.medical_services_outlined,
    'kebakaran': Icons.local_fire_department_outlined,
    'kejahatan': Icons.gpp_maybe_outlined,
    'kecelakaan': Icons.car_crash_outlined,
    'bencana': Icons.flood_outlined,
    'lainnya': Icons.priority_high,
  };

  @override
  void initState() {
    super.initState();
    _ctrl.siapkanLokasi();
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _kirim();
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    _ket.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final ok = await _ctrl.kirimSos(
        jenis: _jenis.isEmpty ? 'umum' : _jenis, keterangan: _ket.text, foto: _foto);
    if (!mounted) return;
    _anim.reset();
    if (ok) {
      setState(() {
        _ket.clear();
        _foto = null;
        _jenis = '';
      });
    }
    showSnack(ok, 'sos_sent'.tr, _ctrl.errorMsg.value);
  }

  Future<void> _aman() async {
    final y = await Get.dialog<bool>(AlertDialog(
      title: const Text('Yakin Anda sudah aman?'),
      content: const Text(
          'Pelacakan lokasi akan dihentikan dan petugas diberi tahu. '
          'Petugas tetap memeriksa lalu menutup kasus.\n\n'
          'Jangan tekan jika Anda masih dalam bahaya.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Belum, masih butuh bantuan')),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Ya, saya aman', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (y == true) await _ctrl.sudahAman();
  }

  Widget _status(List<SosModel> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final s = list.first;
    if (!s.aktif && (s.rating > 0 || DateTime.now().difference(s.ditanganiAt ?? s.createdAt).inDays > 3)) {
      return const SizedBox.shrink();
    }
    final Color merah = Colors.red.shade700;
    if (!s.aktif) return _NilaiSos(sos: s, ctrl: _ctrl);
    String teks;
    switch (s.status) {
      case 'diproses':
        teks = '${s.petugas.isEmpty ? 'Petugas' : s.petugas} sedang menuju / menangani SOS Anda. Tetap tenang.';
        break;
      case 'aman':
        teks = 'Anda menyatakan sudah aman. Menunggu petugas menutup kasus.';
        break;
      default:
        teks = 'SOS terkirim. Menunggu petugas menanggapi.';
    }
    return kartu(
      margin: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.sos, color: merah),
          const SizedBox(width: 8),
          Expanded(
            child: Text('SOS ${SosModel.labelJenis[s.jenis] ?? ''} — aktif',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(teks, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 6),
        Text(
            s.punyaLokasi
                ? '📍 Lokasi GPS Anda dibagikan (diperbarui ${AppUtils.formatRelatif(s.posisiAt ?? s.updatedAt)}).'
                : '⚠️ Lokasi belum didapat. Nyalakan GPS dan izinkan lokasi agar petugas tahu posisi Anda.',
            style: TextStyle(
                fontSize: 12.5,
                color: s.punyaLokasi ? Colors.green.shade800 : Colors.orange.shade900,
                height: 1.4)),
        if (s.status != 'aman') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _aman,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Saya sudah aman'),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color merah = Colors.red.shade700;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('sos_info'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 14),
        const Text('Tahan tombol merah 2 detik. Langsung terkirim, tanpa isi apa pun.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 14),
        Center(
          child: Obx(() {
            final bool kirim = _ctrl.sending.value;
            return GestureDetector(
              onTapDown: (_) {
                if (kirim) return;
                _anim.forward();
              },
              onTapUp: (_) {
                if (_anim.status != AnimationStatus.completed) _anim.reverse();
              },
              onTapCancel: () {
                if (_anim.status != AnimationStatus.completed) _anim.reverse();
              },
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (!kirim)
                        const DenyutRing(warna: Color(0xFFD32F2F), ukuran: 190),
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: kirim ? null : _anim.value,
                          strokeWidth: 10,
                          color: merah,
                          backgroundColor: merah.withOpacity(0.15),
                        ),
                      ),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: merah,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: merah.withOpacity(0.4),
                                blurRadius: 18,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sos, color: Colors.white, size: 64),
                            const SizedBox(height: 4),
                            Text(
                                kirim
                                    ? 'Mencari lokasi & mengirim...'
                                    : 'sos_hold'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
            'Penyalahgunaan SOS (alarm palsu atau main-main) dicatat dan dapat dikenai sanksi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900)),
        StreamBuilder<List<SosModel>>(
          stream: _ctrl.streamSaya(),
          builder: (_, snap) => _status(snap.data ?? const []),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mau menambah keterangan? Boleh sebelum atau SESUDAH SOS terkirim. Tidak wajib.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
        const SizedBox(height: 8),
        const Text('Jenis kejadian (opsional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final e in SosModel.labelJenis.entries)
            ChoiceChip(
              avatar: Icon(_ikon[e.key], size: 16),
              label: Text(e.value, style: const TextStyle(fontSize: 12)),
              selected: _jenis == e.key,
              selectedColor: Colors.red.shade100,
              onSelected: (_) => setState(() => _jenis = e.key),
            ),
        ]),
        const SizedBox(height: 12),
        const Text('Keterangan singkat dan foto (opsional)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        TextField(
          controller: _ket,
          maxLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'Contoh: ibu saya pingsan di rumah, butuh ambulans',
            border: OutlineInputBorder(),
          ),
        ),
        FotoPicker(
          maks: 1,
          label: 'Foto kejadian (opsional)',
          onChanged: (baru, _) => _foto = baru.isNotEmpty ? baru.first : null,
        ),
        Obx(() => _ctrl.sosAktifId.value == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await _ctrl.lengkapi(
                        jenis: _jenis, keterangan: _ket.text, foto: _foto);
                    if (ok && mounted) {
                      setState(() {
                        _ket.clear();
                        _foto = null;
                      });
                    }
                    showSnack(ok, 'Keterangan ditambahkan ke SOS Anda.', _ctrl.errorMsg.value);
                  },
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text('Kirim keterangan ke petugas',
                      style: TextStyle(color: Colors.white)),
                ),
              )),
          ]),
        ),
        const SizedBox(height: 24),
        SectionTitle('sos_numbers'.tr),
        ...AppContact.nomorPenting.map((n) => kartu(
              margin: const EdgeInsets.fromLTRB(0, 6, 0, 0),
              child: Row(
                children: [
                  Icon(Icons.phone_in_talk_outlined, color: merah),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(n['nama']!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(n['nomor']!,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.call, color: Colors.green.shade700),
                    onPressed: () => bukaUri(uriTelp(n['nomor']!)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

/// Penilaian warga atas penanganan SOS (bintang + ulasan).
class _NilaiSos extends StatefulWidget {
  final SosModel sos;
  final SosController ctrl;
  const _NilaiSos({required this.sos, required this.ctrl});
  @override
  State<_NilaiSos> createState() => _NilaiSosState();
}

class _NilaiSosState extends State<_NilaiSos> {
  int _bintang = 0;
  final _ulasan = TextEditingController();
  bool _kirim = false;

  @override
  void dispose() {
    _ulasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sos;
    return kartu(
      margin: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SOS Anda sudah ditutup petugas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Hasil: ${s.hasil}', style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 10),
        const Text('Bagaimana penanganannya?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        Row(children: [
          for (int i = 1; i <= 5; i++)
            IconButton(
              onPressed: () => setState(() => _bintang = i),
              icon: Icon(i <= _bintang ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700),
            ),
        ]),
        TextField(
          controller: _ulasan,
          maxLines: 2,
          maxLength: 200,
          decoration: const InputDecoration(
              hintText: 'Komentar (opsional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        ElevatedButton(
          onPressed: _bintang == 0 || _kirim
              ? null
              : () async {
                  setState(() => _kirim = true);
                  final ok = await widget.ctrl.beriNilai(s, _bintang, _ulasan.text);
                  if (mounted) setState(() => _kirim = false);
                  showSnack(ok, 'Terima kasih atas penilaian Anda.', 'Gagal mengirim penilaian.');
                },
          child: const Text('Kirim penilaian', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

/// Admin & Kades juga bisa mengirim SOS (mereka juga bisa mengalami darurat,
/// mis. di rumah atau saat bertugas). Petugas lain menerima notifikasi.
/// Tab 1: Riwayat (default, tugas utama staf). Tab 2: Kirim SOS.
class _SosStafTabs extends StatelessWidget {
  const _SosStafTabs();

  @override
  Widget build(BuildContext context) {
    final Color merah = Colors.red.shade700;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              labelColor: merah,
              indicatorColor: merah,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Riwayat SOS'),
                Tab(text: 'Kirim SOS'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_SosStaf(), _SosWarga()]),
          ),
        ],
      ),
    );
  }
}

class _SosStaf extends StatelessWidget {
  const _SosStaf();

  Future<void> _selesai(SosController ctrl, SosModel s) async {
    String? pilih;
    final cat = TextEditingController();
    String? galat;
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Tutup kasus SOS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kasus ${s.nama} (${SosModel.labelJenis[s.jenis] ?? ''}). Hasil dan catatan wajib diisi dan tercatat di Log Keputusan.',
                  style: const TextStyle(fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 8),
              for (final o in SosModel.opsiHasil)
                InkWell(
                  onTap: () => setD(() {
                    pilih = o;
                    galat = null;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(pilih == o ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20, color: pilih == o ? Colors.red.shade700 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o, style: const TextStyle(fontSize: 13.5))),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: cat,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Catatan penanganan (wajib)',
                    hintText: 'Contoh: ambulans datang 10 menit, warga dibawa ke puskesmas'),
              ),
              if (galat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(galat!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (pilih == null) {
                setD(() => galat = 'Pilih hasil penanganan.');
              } else if (cat.text.trim().length < 10) {
                setD(() => galat = 'Catatan minimal 10 huruf.');
              } else {
                Get.back(result: true);
              }
            },
            child: const Text('Tutup kasus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ));
    if (ok != true || pilih == null) return;
    final berhasil = await ctrl.selesaikan(s, hasil: pilih!, catatan: cat.text);
    showSnack(berhasil, 'Kasus SOS ditutup.', 'Gagal menutup kasus. Coba lagi.');
  }

  Widget _bintang(int n) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 1; i <= 5; i++)
            Icon(i <= n ? Icons.star : Icons.star_border,
                size: 16, color: Colors.amber.shade700),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SosController>();
    final String saya = Get.find<AuthController>().currentUser.value?.uid ?? '';
    return StreamBuilder<List<SosModel>>(
      stream: ctrl.stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = (snap.data ?? []).where((x) => x.uid != saya).toList();
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.shield_outlined,
            title: 'sos_empty'.tr,
            subtitle: 'sos_empty_sub'.tr,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            if (i == list.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Riwayat SOS disimpan 90 hari, lalu dihapus otomatis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              );
            }
            final s = list[i];
            final bool aktif = s.aktif;
            final umurPosisi = DateTime.now().difference(s.posisiAt ?? s.updatedAt);
            final bool lama = aktif && s.punyaLokasi && umurPosisi.inMinutes >= 3;
            final Color warna = !aktif
                ? Colors.green.shade700
                : (s.status == 'diproses' ? Colors.orange.shade800 : Colors.red.shade700);
            final String labelStatus = !aktif
                ? 'Selesai'
                : (s.status == 'diproses'
                    ? 'Diproses'
                    : (s.status == 'aman' ? 'Warga: sudah aman' : 'BARU'));
            return kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.sos, color: aktif ? Colors.red.shade700 : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          s.peran == 'warga' || s.peran.isEmpty
                              ? s.nama
                              : '${s.nama} (${AppTheme.labelRole(s.peran)})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    StatusBadge(text: labelStatus, color: warna),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${SosModel.labelJenis[s.jenis] ?? 'Darurat'} • ${AppUtils.formatTanggalWaktu(s.createdAt)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (s.keterangan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('“${s.keterangan}”', style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  if (s.foto.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(height: 120, child: fotoFull(s.foto, maksTinggi: 120)),
                  ],
                  const SizedBox(height: 8),
                  if (aktif && s.punyaLokasi)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PetaDenganLokasi(
                        key: ValueKey('peta_${s.id}'),
                        pusat: LatLng(s.lat, s.lng),
                        zoom: 17,
                        tinggi: 190,
                        ikutiPusat: true,
                        penanda: [
                          Marker(
                            point: LatLng(s.lat, s.lng),
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.location_on, size: 44, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                      !s.punyaLokasi
                          ? '⏳ Menunggu titik GPS dari HP warga. Peta muncul otomatis begitu didapat. Sambil menunggu, hubungi lewat telepon.'
                          : 'Titik GPS diambil ${AppUtils.formatRelatif(s.posisiAt ?? s.updatedAt)}'
                              '${s.akurasi > 0 ? ' • akurasi ±${s.akurasi.round()} m' : ''}'
                              '${s.sumber == 'terakhir' ? '\n⚠️ Ini titik TERAKHIR yang diketahui HP, bukan GPS langsung; posisi bisa bergeser.' : ''}${lama ? '\n⚠️ Posisi belum diperbarui ${umurPosisi.inMinutes} menit. Mungkin warga di dalam gedung atau GPS terputus. Telepon segera.' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: (!s.punyaLokasi || lama) ? Colors.red.shade700 : AppTheme.textSecondary)),
                  if (!aktif) ...[
                    const Divider(height: 18),
                    Text('Hasil: ${s.hasil}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (s.catatan.isNotEmpty)
                      Text('Catatan: ${s.catatan}', style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    if (s.petugas.isNotEmpty)
                      Text('Petugas: ${s.petugas}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('Penilaian warga: ', style: TextStyle(fontSize: 12)),
                      s.rating == 0
                          ? const Text('belum menilai', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
                          : _bintang(s.rating),
                    ]),
                    if (s.ulasan.isNotEmpty)
                      Text('“${s.ulasan}”', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ] else ...[
                    if (s.status == 'diproses' && s.petugas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Ditangani: ${s.petugas}',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
                      ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      if (s.punyaLokasi)
                        OutlinedButton.icon(
                          onPressed: () => bukaUri(uriPeta(s.lat, s.lng)),
                          icon: const Icon(Icons.directions_outlined, size: 16),
                          label: const Text('Rute (aplikasi peta)'),
                        ),
                      if (s.telepon.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => bukaUri(uriTelp(s.telepon)),
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: Text('help_call'.tr),
                        ),
                      if (s.status == 'baru' || s.status == 'aman')
                        ElevatedButton(
                          onPressed: () async {
                            final ok = await ctrl.mulaiTangani(s);
                            showSnack(ok, 'Anda menangani kasus ini. Warga diberi tahu.', 'Gagal. Coba lagi.');
                          },
                          child: const Text('Saya tangani', style: TextStyle(color: Colors.white)),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                        onPressed: () => _selesai(ctrl, s),
                        child: const Text('Tutup kasus...', style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
