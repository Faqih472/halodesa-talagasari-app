// ============================================================
// admin_tools_view.dart — Alat Admin/Kades
//   ComplaintMapView : peta sebaran pengaduan (filter)
//   AuditLogView     : catatan keputusan
//   LaporanJasaView  : laporan jasa bermasalah
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/complaint_controller.dart';
import '../controllers/data_controller.dart';
import '../controllers/village_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'complaint_view.dart' show PengaduanDetailView;
import 'jasa_view.dart' show JasaDetailView;

// ─────────────────────────────────────────────────────────────
// Peta sebaran pengaduan
// ─────────────────────────────────────────────────────────────
Color warnaKategori(String k) {
  switch (k) {
    case 'sampah':
      return Colors.brown;
    case 'jalan_rusak':
      return Colors.orange.shade800;
    case 'keamanan':
      return Colors.red.shade800;
    case 'kekerasan':
      return Colors.purple.shade800;
    case 'gangguan':
      return Colors.blue.shade700;
    case 'lingkungan':
      return Colors.green.shade700;
    case 'layanan_desa':
      return Colors.teal;
    default:
      return Colors.blueGrey;
  }
}

class ComplaintMapView extends StatefulWidget {
  const ComplaintMapView({super.key});

  @override
  State<ComplaintMapView> createState() => _ComplaintMapViewState();
}

/// "Sebaran Pengaduan": DEFAULT berupa daftar teks (ringkasan + filter).
/// Peta hanya dibuka bila petugas memilih tab "Peta" atau menekan ikon peta
/// pada salah satu laporan.
class _ComplaintMapViewState extends State<ComplaintMapView> {
  final ComplaintController _ctrl = Get.find<ComplaintController>();
  String _kategori = 'semua';
  int _hari = 0; // 0 = semua
  bool _modePeta = false;
  LatLng? _fokus;

  @override
  void initState() {
    super.initState();
    _ctrl.fetchSemua();
  }

  List<ComplaintModel> get _terfilter {
    final batas = DateTime.now().subtract(Duration(days: _hari));
    return _ctrl.semua.where((c) {
      if (_kategori != 'semua' && c.kategori != _kategori) return false;
      if (_hari > 0 && c.createdAt.isBefore(batas)) return false;
      return true;
    }).toList();
  }

  Widget _filter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _kategori,
              items: [
                DropdownMenuItem(value: 'semua', child: Text('map_all_cat'.tr)),
                ...ComplaintModel.daftarKategori.map((k) => DropdownMenuItem(
                    value: k['value']!, child: Text(k['label']!))),
              ],
              onChanged: (v) => setState(() => _kategori = v ?? 'semua'),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _hari,
            items: [
              DropdownMenuItem(value: 7, child: Text('map_7d'.tr)),
              DropdownMenuItem(value: 30, child: Text('map_30d'.tr)),
              DropdownMenuItem(value: 0, child: Text('map_all_time'.tr)),
            ],
            onChanged: (v) => setState(() => _hari = v ?? 0),
          ),
        ],
      ),
    );
  }

  // ── TAB DAFTAR (teks) ──
  Widget _daftar(List<ComplaintModel> list, Color primary) {
    final perKategori = <String, int>{};
    for (final c in list) {
      perKategori[c.kategori] = (perKategori[c.kategori] ?? 0) + 1;
    }
    final urut = perKategori.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final auth = Get.find<AuthController>();

    return RefreshIndicator(
      color: primary,
      onRefresh: _ctrl.fetchSemua,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          kartu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${list.length} pengaduan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (urut.isEmpty)
                  const Text('Tidak ada data untuk filter ini.',
                      style: TextStyle(color: AppTheme.textSecondary))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: urut
                        .map((e) => StatusBadge(
                            text:
                                '${ComplaintModel.labelKategori(e.key)}: ${e.value}',
                            color: warnaKategori(e.key)))
                        .toList(),
                  ),
              ],
            ),
          ),
          ...list.map((c) {
            final sembunyi = auth.role == 'kades' &&
                c.rahasia &&
                c.uidPelapor != auth.currentUser.value?.uid;
            return kartu(
              child: InkWell(
                onTap: () => Get.to(() => PengaduanDetailView(complaint: c)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ComplaintModel.ikonKategori(c.kategori),
                        color: warnaKategori(c.kategori)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.judul,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                              '${ComplaintModel.labelKategori(c.kategori)} • ${ComplaintModel.labelStatus(c.status)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          if (!sembunyi && c.alamat.isNotEmpty)
                            Text(c.alamat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          Text(AppUtils.formatRelatif(c.createdAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Lihat lokasi di peta',
                      icon: Icon(Icons.map_outlined, color: primary),
                      onPressed: () => setState(() {
                        _fokus = LatLng(c.lat, c.lng);
                        _modePeta = true;
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── TAB PETA (dibangun hanya saat dipilih) ──
  Widget _peta(List<ComplaintModel> list) {
    LatLng pusat = _fokus ?? const LatLng(-6.2405, 106.5106);
    if (_fokus == null && list.isNotEmpty) {
      pusat = LatLng(list.first.lat, list.first.lng);
    }
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
              initialCenter: pusat, initialZoom: _fokus != null ? 16 : 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.talagasari_hub',
            ),
            MarkerLayer(
              markers: list
                  .map((c) => Marker(
                        point: LatLng(c.lat, c.lng),
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () =>
                              Get.to(() => PengaduanDetailView(complaint: c)),
                          child: Icon(Icons.location_on,
                              size: 36, color: warnaKategori(c.kategori)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                Text('${list.length} ${'map_count'.tr}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                ...ComplaintModel.daftarKategori.map((k) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 10, color: warnaKategori(k['value']!)),
                        const SizedBox(width: 3),
                        Text(k['label']!,
                            style: const TextStyle(fontSize: 10)),
                      ],
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary =
        AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('hub_complaint_map'.tr),
        backgroundColor: primary,
        actions: [
          IconButton(
            tooltip: _modePeta ? 'Tampilkan daftar' : 'Lihat di peta',
            icon: Icon(_modePeta ? Icons.list_alt : Icons.map_outlined),
            onPressed: () => setState(() {
              _modePeta = !_modePeta;
              if (!_modePeta) _fokus = null;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _filter(),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value && _ctrl.semua.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = _terfilter;
              return _modePeta ? _peta(list) : _daftar(list, primary);
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Audit log
// ─────────────────────────────────────────────────────────────
class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  String _filter = 'semua';

  static const _opsi = <MapEntry<String, String>>[
    MapEntry('semua', 'Semua'),
    MapEntry('tolak', 'Penolakan'),
    MapEntry('informasi', 'Informasi'),
    MapEntry('jasa', 'Jasa'),
    MapEntry('pengaduan', 'Pengaduan'),
    MapEntry('ktp', 'KTP'),
    MapEntry('surat', 'Surat'),
    MapEntry('sos', 'SOS'),
  ];

  bool _lolos(AuditModel a) {
    if (_filter == 'semua') return true;
    if (_filter == 'tolak') return a.penolakan;
    return a.targetTipe == _filter;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary =
        AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('hub_audit'.tr), backgroundColor: primary),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _opsi
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
                        child: ChoiceChip(
                          label: Text(o.value,
                              style: const TextStyle(fontSize: 12)),
                          selected: _filter == o.key,
                          onSelected: (_) => setState(() => _filter = o.key),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AuditModel>>(
              stream: AuditLog.stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = (snap.data ?? []).where(_lolos).toList();
                if (list.isEmpty) {
                  return EmptyState(
                      icon: Icons.history,
                      title: 'audit_empty'.tr,
                      subtitle: 'audit_empty_sub'.tr);
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'Log disimpan 90 hari, lalu dihapus otomatis.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                      );
                    }
                    final a = list[i];
                    return kartu(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.ikon,
                              color: a.penolakan ? Colors.red.shade700 : primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.aksi,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (a.detail.isNotEmpty)
                                  Text(a.detail,
                                      style: const TextStyle(
                                          fontSize: 12.5, height: 1.4)),
                                if (a.alasan.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Alasan ditolak: ${a.alasan}',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: Colors.red.shade800)),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                    '${a.aktorNama} (${a.aktorPeran}) • ${AppUtils.formatTanggalWaktu(a.createdAt)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Laporan jasa bermasalah
// Tindakan Admin: abaikan • peringatan (3x = nonaktif otomatis) •
// nonaktifkan • blokir. Pelapor & penyedia mendapat notifikasi.
// ─────────────────────────────────────────────────────────────
/// Isi laporan jasa tanpa Scaffold (dipakai sebagai tab di Kelola → Laporan Jasa)
class LaporanJasaTab extends StatelessWidget {
  const LaporanJasaTab({super.key});

  Future<void> _proses(ServiceReportModel r, String tindakan) async {
    final data = Get.find<ServiceController>();
    String catatan = '';
    if (tindakan != 'abaikan') {
      final t = await mintaTeks(
          tindakan == 'peringatan'
              ? 'Peringatan untuk penyedia'
              : tindakan == 'blokir'
                  ? 'Blokir jasa'
                  : 'Nonaktifkan jasa',
          'Catatan untuk penyedia (min. 5 huruf)',
          minHuruf: 5);
      if (t == null) return;
      catatan = t;
    }
    final ok = await data.tindakLaporan(r, tindakan: tindakan, catatan: catatan);
    showSnack(ok, 'Laporan sudah ditindaklanjuti.', data.errorMsg.value);
  }

  Future<void> _lihat(ServiceReportModel r) async {
    final s = await Get.find<ServiceController>().ambilJasa(r.serviceId);
    if (s == null) {
      showSnack(false, '', 'Profil jasa tidak ditemukan.');
      return;
    }
    Get.to(() => JasaDetailView(service: s));
  }

  @override
  Widget build(BuildContext context) {
    final data = Get.find<ServiceController>();
    return StreamBuilder<List<ServiceReportModel>>(
      stream: data.laporanStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return EmptyState(
              icon: Icons.flag_outlined, title: 'report_empty'.tr, subtitle: '');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final r = list[i];
            return kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.namaPenyedia,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '${'report_by'.tr} ${r.namaPelapor} • ${AppUtils.formatRelatif(r.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(r.labelJenis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800)),
                  ),
                  const SizedBox(height: 8),
                  Text(r.alasan, style: const TextStyle(height: 1.4)),
                  if (r.orderId.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Terkait sebuah pesanan di aplikasi.',
                          style: TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary)),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _lihat(r),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Lihat Jasa'),
                      ),
                      OutlinedButton(
                        onPressed: () => _proses(r, 'abaikan'),
                        child: Text('report_dismiss'.tr),
                      ),
                      OutlinedButton(
                        onPressed: () => _proses(r, 'peringatan'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800)),
                        child: const Text('Beri Peringatan'),
                      ),
                      ElevatedButton(
                        onPressed: () => _proses(r, 'nonaktif'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800),
                        child: Text('report_disable'.tr,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () => _proses(r, 'blokir'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        child: const Text('Blokir',
                            style: TextStyle(color: Colors.white)),
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

class LaporanJasaView extends StatelessWidget {
  const LaporanJasaView({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary =
        AppTheme.primaryColor(Get.find<AuthController>().role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
          title: Text('hub_service_reports'.tr), backgroundColor: primary),
      body: const LaporanJasaTab(),
    );
  }
}
