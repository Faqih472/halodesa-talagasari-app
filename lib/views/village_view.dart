// ============================================================
// village_view.dart — Layanan Desa: Hub menu, SOS, Polling, Agenda
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/village_controller.dart';
import '../core/app_contact.dart';
import '../core/core.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'admin_tools_view.dart';
import 'letter_view.dart';

// ============================================================
// HUB — kumpulan pintu masuk layanan di Beranda (menurut peran)
// ============================================================
class _Menu {
  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;
  _Menu(this.icon, this.label, this.warna, this.onTap);
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
            () => Get.to(() => const LetterHomeView())),
        _Menu(Icons.how_to_vote_outlined, 'hub_poll'.tr, primary,
            () => Get.to(() => const PollListView())),
        _Menu(Icons.event_outlined, 'hub_agenda'.tr, primary,
            () => Get.to(() => const AgendaListView())),
        if (staf)
          _Menu(Icons.sos, 'hub_sos_log'.tr, Colors.red.shade700,
              () => Get.to(() => const SosView())),
        if (staf)
          _Menu(Icons.map_outlined, 'hub_complaint_map'.tr, primary,
              () => Get.to(() => const ComplaintMapView())),
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
                                  Container(
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
                                  ),
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
  bool _terkirim = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _kirim();
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final ok = await _ctrl.kirimSos();
    if (!mounted) return;
    setState(() => _terkirim = ok);
    _anim.reset();
    showSnack(ok, 'sos_sent'.tr, _ctrl.errorMsg.value);
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
        const SizedBox(height: 24),
        Center(
          child: Obx(() {
            final bool kirim = _ctrl.sending.value;
            return GestureDetector(
              onTapDown: (_) {
                if (!kirim) _anim.forward();
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
                      if (!kirim) const DenyutRing(warna: Color(0xFFD32F2F), ukuran: 190),
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
                            Text(kirim ? 'sos_sending'.tr : 'sos_hold'.tr,
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
        if (_terkirim)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('sos_sent'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 28),
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

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SosController>();
    return StreamBuilder<List<SosModel>>(
      stream: ctrl.stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
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
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              );
            }
            final s = list[i];
            final bool baru = s.status == 'baru';
            return kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sos,
                          color: baru ? Colors.red.shade700 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            s.peran == 'warga' || s.peran.isEmpty
                                ? s.nama
                                : '${s.nama} (${AppTheme.labelRole(s.peran)})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      StatusBadge(
                          text: baru ? 'sos_new'.tr : 'sos_done'.tr,
                          color: baru ? Colors.red.shade700 : Colors.green.shade700),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(AppUtils.formatTanggalWaktu(s.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => bukaUri(uriPeta(s.lat, s.lng)),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: Text('sos_open_map'.tr),
                      ),
                      if (s.telepon.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => bukaUri(uriTelp(s.telepon)),
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: Text('help_call'.tr),
                        ),
                      if (baru)
                        ElevatedButton(
                          onPressed: () => ctrl.tandaiDitangani(s),
                          child: Text('sos_mark_done'.tr,
                              style: const TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// POLLING
// ============================================================
class PollListView extends StatelessWidget {
  const PollListView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final ctrl = Get.find<PollController>();
    final Color primary = AppTheme.primaryColor(auth.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('poll_title'.tr), backgroundColor: primary),
      floatingActionButton: auth.isStaff
          ? FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: () => Get.to(() => const BuatPollingView()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('poll_create'.tr,
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<List<PollModel>>(
        stream: ctrl.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return EmptyState(
                icon: Icons.how_to_vote_outlined,
                title: 'poll_empty'.tr,
                subtitle: 'poll_empty_sub'.tr);
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return InkWell(
                onTap: () => Get.to(() => PollDetailView(poll: p)),
                child: kartu(
                  child: Row(
                    children: [
                      if (p.fotoUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ImageUtil.image(p.fotoUrl,
                                width: 56, height: 56),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.pertanyaan,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                                '${'poll_until'.tr} ${AppUtils.formatTanggal(p.tutup)} • ${p.opsi.length} ${'poll_options'.tr}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      StatusBadge(
                          text: p.ditutup ? 'poll_closed'.tr : 'poll_open'.tr,
                          color: p.ditutup ? Colors.grey : Colors.green.shade700),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BuatPollingView extends StatefulWidget {
  const BuatPollingView({super.key});

  @override
  State<BuatPollingView> createState() => _BuatPollingViewState();
}

class _BuatPollingViewState extends State<BuatPollingView> {
  final PollController _ctrl = Get.find<PollController>();
  final _formKey = GlobalKey<FormState>();
  final _tanyaCtrl = TextEditingController();
  final List<TextEditingController> _opsi = [
    TextEditingController(),
    TextEditingController()
  ];
  DateTime _tutup = DateTime.now().add(const Duration(days: 7));
  File? _foto;

  @override
  void dispose() {
    _tanyaCtrl.dispose();
    for (final c in _opsi) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _tutup,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (p != null) setState(() => _tutup = DateTime(p.year, p.month, p.day, 23, 59));
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _ctrl.buat(
        _tanyaCtrl.text, _opsi.map((c) => c.text).toList(), _tutup,
        foto: _foto);
    if (ok) Get.back();
    showSnack(ok, 'poll_created'.tr, _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('poll_create'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: kartu(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                TextFormField(
                  controller: _tanyaCtrl,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'poll_q_min'.tr
                      : null,
                  decoration: InputDecoration(labelText: 'poll_question'.tr),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _opsi.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _opsi[i],
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'poll_opt_req'.tr
                                : null,
                            decoration: InputDecoration(
                                labelText: '${'poll_option'.tr} ${i + 1}'),
                          ),
                        ),
                        if (_opsi.length > 2)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _opsi.removeAt(i).dispose();
                            }),
                          ),
                      ],
                    ),
                  ),
                if (_opsi.length < 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _opsi.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: Text('poll_add_option'.tr),
                    ),
                  ),
                const SizedBox(height: 8),
                FotoPicker(
                  maks: 1,
                  label: 'Gambar pendukung polling (opsional)',
                  onChanged: (baru, _) =>
                      _foto = baru.isNotEmpty ? baru.first : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pilihTanggal,
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'poll_deadline'.tr,
                        prefixIcon: const Icon(Icons.event_outlined)),
                    child: Text(AppUtils.formatTanggal(_tutup)),
                  ),
                ),
                const SizedBox(height: 18),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                        child: _ctrl.isSubmitting.value
                            ? loadingChild()
                            : Text('poll_publish'.tr),
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

class PollDetailView extends StatefulWidget {
  final PollModel poll;
  const PollDetailView({super.key, required this.poll});

  @override
  State<PollDetailView> createState() => _PollDetailViewState();
}

class _PollDetailViewState extends State<PollDetailView> {
  final PollController _ctrl = Get.find<PollController>();
  final AuthController _auth = Get.find<AuthController>();
  bool _loading = true;
  int? _mine;
  List<int> _hasil = [];

  PollModel get p => widget.poll;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    _mine = await _ctrl.pilihanSaya(p.id);
    if (_mine != null || p.ditutup || _auth.isStaff) {
      _hasil = await _ctrl.hasil(p);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pilih(int i) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('poll_confirm'.tr),
      content: Text(p.opsi[i]),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text('poll_vote'.tr,
                style: const TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    final sukses = await _ctrl.pilih(p, i);
    showSnack(sukses, 'poll_voted'.tr, _ctrl.errorMsg.value);
    if (sukses) _muat();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final bool lihatHasil = _mine != null || p.ditutup || _auth.isStaff;
    final int total = _hasil.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('poll_title'.tr),
        backgroundColor: primary,
        actions: [
          if (_auth.isStaff)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _ctrl.hapus(p);
                Get.back();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (p.fotoUrl.isNotEmpty) ...[
                  fotoBanner(p.fotoUrl, tinggi: 180),
                  const SizedBox(height: 12),
                ],
                Text(p.pertanyaan,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                    '${p.ditutup ? 'poll_closed'.tr : '${'poll_until'.tr} ${AppUtils.formatTanggal(p.tutup)}'} • ${p.dibuatOleh}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                for (int i = 0; i < p.opsi.length; i++)
                  if (!lihatHasil)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () => _pilih(i),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            alignment: Alignment.centerLeft),
                        child: Text(p.opsi[i]),
                      ),
                    )
                  else
                    _batang(i, total, primary),
                if (lihatHasil)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${'poll_total'.tr}: $total',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                if (!lihatHasil)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('poll_rule'.tr,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
              ],
            ),
    );
  }

  Widget _batang(int i, int total, Color primary) {
    final int n = i < _hasil.length ? _hasil[i] : 0;
    final double persen = total == 0 ? 0 : n / total;
    final bool saya = _mine == i;
    return kartu(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (saya)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle, size: 16, color: primary),
                ),
              Expanded(
                child: Text(p.opsi[i],
                    style: TextStyle(
                        fontWeight: saya ? FontWeight.bold : FontWeight.w500)),
              ),
              Text('$n • ${(persen * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: persen,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AGENDA
// ============================================================
class AgendaListView extends StatelessWidget {
  const AgendaListView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final ctrl = Get.find<AgendaController>();
    final Color primary = AppTheme.primaryColor(auth.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('agenda_title'.tr), backgroundColor: primary),
      floatingActionButton: auth.isStaff
          ? FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: () => Get.to(() => const BuatAgendaView()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('agenda_create'.tr,
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<List<AgendaModel>>(
        stream: ctrl.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final semua = snap.data ?? [];
          final akan = semua.where((a) => !a.lewat).toList();
          final lalu = semua.where((a) => a.lewat).toList().reversed.toList();
          if (semua.isEmpty) {
            return EmptyState(
                icon: Icons.event_outlined,
                title: 'agenda_empty'.tr,
                subtitle: 'agenda_empty_sub'.tr);
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            children: [
              if (akan.isNotEmpty) SectionTitle('agenda_upcoming'.tr),
              ...akan.map((a) => _AgendaKartu(agenda: a, primary: primary)),
              if (lalu.isNotEmpty) SectionTitle('agenda_past'.tr),
              ...lalu.map((a) => _AgendaKartu(agenda: a, primary: primary)),
            ],
          );
        },
      ),
    );
  }
}

class _AgendaKartu extends StatelessWidget {
  final AgendaModel agenda;
  final Color primary;
  const _AgendaKartu({required this.agenda, required this.primary});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgendaController>();
    final auth = Get.find<AuthController>();
    final a = agenda;

    return Opacity(
      opacity: a.lewat ? 0.6 : 1,
      child: kartu(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('${a.waktu.day}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                  Text(AppUtils.formatTanggal(a.waktu).split(' ')[1],
                      style: TextStyle(fontSize: 11, color: primary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.judul,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  if (a.fotoUrl.isNotEmpty) ...[
                    fotoBanner(a.fotoUrl, tinggi: 120),
                    const SizedBox(height: 6),
                  ],
                  Text(
                      '${a.waktu.hour.toString().padLeft(2, '0')}:${a.waktu.minute.toString().padLeft(2, '0')}${a.lokasi.isEmpty ? '' : ' • ${a.lokasi}'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  if (a.deskripsi.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.deskripsi,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StreamBuilder<int>(
                        stream: ctrl.jumlahHadir(a.id),
                        builder: (_, s) => Text(
                            '${s.data ?? 0} ${'agenda_going'.tr}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                      const Spacer(),
                      if (!a.lewat)
                        StreamBuilder<bool>(
                          stream: ctrl.sayaHadir(a.id),
                          builder: (_, s) {
                            final bool hadir = s.data ?? false;
                            return hadir
                                ? OutlinedButton.icon(
                                    onPressed: () => ctrl.toggleHadir(a, false),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: Text('agenda_will_come'.tr),
                                  )
                                : ElevatedButton(
                                    onPressed: () => ctrl.toggleHadir(a, true),
                                    child: Text('agenda_rsvp'.tr,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  );
                          },
                        ),
                      if (auth.isStaff)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => ctrl.hapus(a),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BuatAgendaView extends StatefulWidget {
  const BuatAgendaView({super.key});

  @override
  State<BuatAgendaView> createState() => _BuatAgendaViewState();
}

class _BuatAgendaViewState extends State<BuatAgendaView> {
  final AgendaController _ctrl = Get.find<AgendaController>();
  final _formKey = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _deskCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  DateTime _waktu = DateTime.now().add(const Duration(days: 2, hours: 1));
  File? _foto;

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskCtrl.dispose();
    _lokasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihWaktu() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _waktu,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_waktu));
    if (t == null) return;
    setState(() => _waktu = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _ctrl.buat(
      judul: _judulCtrl.text,
      deskripsi: _deskCtrl.text,
      lokasi: _lokasiCtrl.text,
      waktu: _waktu,
      foto: _foto,
    );
    if (ok) Get.back();
    showSnack(ok, 'agenda_created'.tr, _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('agenda_create'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: kartu(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                TextFormField(
                  controller: _judulCtrl,
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'cmp_title_min'.tr
                      : null,
                  decoration: InputDecoration(labelText: 'agenda_name'.tr),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deskCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: 'agenda_desc'.tr, alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lokasiCtrl,
                  decoration: InputDecoration(
                      labelText: 'agenda_place'.tr,
                      prefixIcon: const Icon(Icons.place_outlined)),
                ),
                const SizedBox(height: 12),
                FotoPicker(
                  maks: 1,
                  label: 'Poster / gambar acara (opsional)',
                  onChanged: (baru, _) =>
                      _foto = baru.isNotEmpty ? baru.first : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pilihWaktu,
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: 'agenda_time'.tr,
                        prefixIcon: const Icon(Icons.schedule_outlined)),
                    child: Text(AppUtils.formatTanggalWaktu(_waktu)),
                  ),
                ),
                const SizedBox(height: 18),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                        child: _ctrl.isSubmitting.value
                            ? loadingChild()
                            : Text('save'.tr),
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
