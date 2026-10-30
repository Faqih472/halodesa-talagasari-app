// ============================================================
// jasa_view.dart — Fitur JASA LOKAL (lengkap)
//   TabJasaView        : cari jasa (peta + daftar, cari, filter, urut)
//   JasaDetailView     : profil jasa, katalog, jadwal, ulasan
//   FormJasaView       : daftar / ubah profil jasa
//   BuatPesananView    : memesan jasa
//   PesananSayaView    : daftar pesanan warga
//   PesananDetailView  : alur pesanan (terima, nego, kerjakan, selesai, ulasan)
//   DasborJasaView     : dasbor penyedia (pesanan, ulasan, profil)
//   AdminJasaTab       : antrean verifikasi + semua jasa (Admin)
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';
import 'chat_view.dart';
import 'verification_view.dart' show wajibVerifikasi;

// ─────────────────────────────────────────────────────────────
// PEMBANTU UMUM (khusus file ini)
// ─────────────────────────────────────────────────────────────
const Map<String, String> _labelUrutan = {
  'rekomendasi': 'Rekomendasi',
  'terdekat': 'Terdekat',
  'rating': 'Rating tertinggi',
  'terlaris': 'Paling banyak dipesan',
  'termurah': 'Harga termurah',
  'terbaru': 'Terbaru',
};

String _nomorWa(String raw) {
  var n = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('0')) n = '62${n.substring(1)}';
  return n;
}

Future<void> _bukaWa(String nomor, String pesan) async {
  final n = _nomorWa(nomor);
  if (n.length < 9) {
    showSnack(false, '', 'Nomor WhatsApp belum diisi oleh pemilik.');
    return;
  }
  await bukaUri(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(pesan)}'));
}

/// Buka / buat ruang obrolan dengan pengguna lain lalu masuk ke obrolan.
Future<void> _bukaChat(
    {required String uid, required String nama, String foto = ''}) async {
  try {
    final chat = Get.find<ChatController>();
    final me = Get.find<AuthController>().currentUser.value!;
    final room = await chat.bukaAtauBuatRoom(
        otherUid: uid, otherNama: nama, otherFoto: foto);
    await Get.to(() => ChatRoomView(
          roomId: room.id,
          otherUid: uid,
          namaLawan: room.namaLawan(me.uid),
          fotoLawan: room.fotoLawan(me.uid),
        ));
  } catch (e) {
    showSnack(false, '', 'Tidak dapat membuka obrolan: $e');
  }
}

Widget _avatarJasa(ServiceModel s, {double radius = 28}) {
  final Color k = AppTheme.kategoriJasaColor(s.kategori);
  final String foto = s.fotoKartu;
  return CircleAvatar(
    radius: radius,
    backgroundColor: k.withOpacity(0.12),
    backgroundImage: foto.isNotEmpty ? ImageUtil.provider(foto) : null,
    child: foto.isEmpty
        ? Icon(AppTheme.kategoriJasaIcon(s.kategori), color: k, size: radius * 0.95)
        : null,
  );
}

Widget _pil(String teks, Color c, {IconData? ikon, double fontSize = 11}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ikon != null) ...[
          Icon(ikon, size: fontSize + 2, color: c),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(teks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: fontSize, fontWeight: FontWeight.w600, color: c)),
        ),
      ],
    ),
  );
}

Widget _judulSeksi(String teks, {Widget? aksi, IconData? ikon}) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        if (ikon != null) ...[
          Icon(ikon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(teks,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        if (aksi != null) aksi,
      ],
    ),
  );
}

Widget _barisInfo(IconData ikon, String teks, {Color? warna, double size = 13}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 16, color: warna ?? AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(teks,
              style: TextStyle(
                  fontSize: size, height: 1.35, color: warna ?? AppTheme.textPrimary)),
        ),
      ],
    ),
  );
}

String _jamLabel(String jam) => jam.isEmpty ? '' : ' • $jam';

// ============================================================
// TAB JASA — Cari jasa: peta + daftar, pencarian, filter, urutan
// ============================================================
class TabJasaView extends StatefulWidget {
  const TabJasaView({super.key});

  @override
  State<TabJasaView> createState() => _TabJasaViewState();
}

class _TabJasaViewState extends State<TabJasaView> {
  final AuthController _auth = Get.find<AuthController>();
  final ServiceController _svc = Get.find<ServiceController>();
  final OrderController _ord = Get.find<OrderController>();
  final MapController _map = MapController();
  final TextEditingController _cari = TextEditingController();
  bool _petaBesar = false;

  @override
  void initState() {
    super.initState();
    _cari.text = _svc.kataKunci.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _svc.muatJikaLama());
  }

  @override
  void dispose() {
    _map.dispose();
    _cari.dispose();
    super.dispose();
  }

  Color _warnaPin(String kategori) =>
      HSVColor.fromAHSV(1, AppUtils.hueKategoriJasa(kategori), 0.85, 0.9).toColor();

  void _infoPin(ServiceModel s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: _avatarJasa(s, radius: 24),
          title: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${AppUtils.labelKategoriJasa(s.kategori)} • ${AppUtils.formatJarakKm(s.jarakKm)}'
              '${s.ratingCount > 0 ? ' • ★ ${s.ratingAvg.toStringAsFixed(1)}' : ''}\n${s.labelTarif}'),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(sheetCtx);
            Get.to(() => JasaDetailView(service: s));
          },
        ),
      ),
    );
  }

  List<Marker> _penanda(List<ServiceModel> list) {
    return list
        .map((s) => Marker(
              point: LatLng(s.lokasiLat, s.lokasiLng),
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => _infoPin(s),
                child: Icon(Icons.location_on,
                    size: 40,
                    color: s.sedangBuka ? _warnaPin(s.kategori) : Colors.grey),
              ),
            ))
        .toList();
  }

  void _bukaFilter() {
    Get.bottomSheet(
      const _FilterJasaSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _auth.currentUser.value;
      final Color primary = AppTheme.primaryColor(user?.role ?? 'warga');
      final LatLng posisi = LatLng(
        user?.lokasiLat ?? -6.239265,
        user?.lokasiLng ?? 106.530200,
      );
      final bool loading = _svc.isLoading.value;
      final String kategori = _svc.filterKategori.value;
      final list = _svc.hasilCari;
      final saya = _svc.punyaSaya.value;
      final int nFilter = _svc.jumlahFilterAktif;
      final String urut = _svc.urutan.value;
      final int badge = _ord.badgeTotal;
      final bool adaFilter = nFilter > 0 ||
          kategori != 'semua' ||
          _svc.kataKunci.value.trim().isNotEmpty;

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text('Cari Jasa Lokal'),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Pesanan saya',
                  icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
                  onPressed: () => Get.to(() => const PesananSayaView()),
                ),
                if (badge > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const ChatAction(),
          ],
        ),
        body: RefreshIndicator(
          color: primary,
          onRefresh: () async {
            await _svc.fetchAktif();
            await _svc.fetchFavorit();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Peta ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _petaBesar ? 340 : 200,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: posisi,
                          initialZoom: 13.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.talagasari_hub',
                          ),
                          MarkerLayer(markers: _penanda(list)),
                          MarkerLayer(markers: [
                            Marker(
                              point: posisi,
                              width: 22,
                              height: 22,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('© OpenStreetMap contributors'),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Column(
                          children: [
                            _tombolPeta(Icons.my_location, 'Lokasi saya', () async {
                              await _auth.updateLokasiOtomatis();
                              final u = _auth.currentUser.value;
                              if (u != null) {
                                _map.move(LatLng(u.lokasiLat, u.lokasiLng),
                                    _map.camera.zoom);
                              }
                            }),
                            const SizedBox(height: 8),
                            _tombolPeta(
                                _petaBesar ? Icons.fullscreen_exit : Icons.fullscreen,
                                _petaBesar ? 'Perkecil peta' : 'Perbesar peta',
                                () => setState(() => _petaBesar = !_petaBesar)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Banner jasa saya / ajakan ──
              SliverToBoxAdapter(
                child: FadeSlideIn(child: _bannerSaya(saya, primary)),
              ),

              // ── Cari + filter ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cari,
                          textInputAction: TextInputAction.search,
                          onChanged: (v) => _svc.kataKunci.value = v,
                          decoration: InputDecoration(
                            hintText: 'Cari tukang, servis, les, katering…',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _cari.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _cari.clear();
                                      _svc.kataKunci.value = '';
                                      setState(() {});
                                    }),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Material(
                            color: nFilter > 0 ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _bukaFilter,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Icon(Icons.tune,
                                    color: nFilter > 0 ? Colors.white : primary),
                              ),
                            ),
                          ),
                          if (nFilter > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.red,
                                child: Text('$nFilter',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Kategori ──
              SliverToBoxAdapter(child: _chipKategori(kategori, primary)),

              // ── Jumlah + urutan ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            loading ? 'Memuat…' : '${list.length} penyedia jasa',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Urutkan',
                        initialValue: urut,
                        onSelected: (v) => _svc.urutan.value = v,
                        itemBuilder: (_) => _labelUrutan.entries
                            .map((e) =>
                                PopupMenuItem<String>(value: e.key, child: Text(e.value)))
                            .toList(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_vert, size: 18),
                              const SizedBox(width: 4),
                              Text(_labelUrutan[urut] ?? 'Urutkan',
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Daftar ──
              if (loading && list.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const ShimmerCard(),
                    childCount: 3,
                  ),
                )
              else if (list.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        EmptyState(
                          icon: Icons.handyman_outlined,
                          title: adaFilter
                              ? 'Tidak ada hasil'
                              : 'Belum ada penyedia jasa',
                          subtitle: adaFilter
                              ? 'Coba ubah kata kunci atau kurangi filter.'
                              : 'Belum ada penyedia jasa aktif. Jadilah yang pertama mendaftar!',
                        ),
                        if (adaFilter)
                          OutlinedButton.icon(
                            onPressed: () {
                              _cari.clear();
                              _svc.kataKunci.value = '';
                              _svc.filterKategori.value = 'semua';
                              _svc.resetFilter();
                              setState(() {});
                            },
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset pencarian'),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FadeSlideIn(
                      key: ValueKey(list[i].id),
                      delay: Duration(milliseconds: 50 * (i % 8)),
                      child: _JasaKartu(
                          service: list[i],
                          onTap: () => Get.to(() => JasaDetailView(service: list[i]))),
                    ),
                    childCount: list.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      );
    });
  }

  Widget _tombolPeta(IconData ikon, String tip, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Tooltip(message: tip, child: Icon(ikon, size: 20)),
        ),
      ),
    );
  }

  // ── Banner ajakan / ringkasan jasa saya ──
  Widget _bannerSaya(ServiceModel? saya, Color primary) {
    if (saya == null) {
      return BouncyTap(
        onTap: () => showFormJasa(),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.gradient(_auth.role),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.storefront_outlined, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Punya keahlian atau usaha?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Daftar jadi penyedia jasa, terima pesanan dari warga sekitar',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      );
    }

    final Color sColor = AppTheme.statusJasaColor(saya.status);
    final int baru = _ord.jumlahBaru;
    return BouncyTap(
      onTap: () => Get.to(() => const DasborJasaView()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sColor.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            _avatarJasa(saya, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saya.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _pil(AppTheme.labelStatusJasa(saya.status), sColor),
                    if (saya.status == 'aktif')
                      _pil(
                          ServiceModel.labelStatusSekarang(saya.statusSekarang()),
                          ServiceModel.warnaStatusSekarang(saya.statusSekarang())),
                    if (baru > 0)
                      _pil('$baru pesanan baru', Colors.red.shade700,
                          ikon: Icons.notifications_active_outlined),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _chipKategori(String aktif, Color primary) {
    final filters = <Map<String, String>>[
      {'value': 'semua', 'label': 'Semua'},
      ...AppUtils.daftarKategoriJasa,
    ];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: filters.map((f) {
          final bool on = aktif == f['value'];
          final Color c = f['value'] == 'semua'
              ? primary
              : AppTheme.kategoriJasaColor(f['value']!);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: on,
              onSelected: (_) => _svc.setFilter(f['value']!),
              selectedColor: c.withOpacity(0.15),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: on ? c : AppTheme.textSecondary,
                fontWeight: on ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(color: on ? c : Colors.grey.shade300),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Kartu penyedia jasa di daftar
// ─────────────────────────────────────────────────────────────
class _JasaKartu extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;
  const _JasaKartu({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final auth = Get.find<AuthController>();
    final svc = Get.find<ServiceController>();
    final Color k = AppTheme.kategoriJasaColor(s.kategori);
    final String st = s.statusSekarang();
    final bool milikSaya = s.isMilikSaya(auth.currentUser.value?.uid ?? '');

    return BouncyTap(
      onTap: onTap,
      child: Opacity(
        opacity: (st == 'buka' || st == 'di_luar_jam') ? 1 : 0.72,
        child: kartu(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 76,
                  height: 76,
                  color: k.withOpacity(0.12),
                  child: s.fotoKartu.isNotEmpty
                      ? ImageUtil.image(s.fotoKartu, width: 76, height: 76)
                      : Icon(AppTheme.kategoriJasaIcon(s.kategori), color: k, size: 34),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        if (s.ktpOk) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 15, color: Color(0xFF1E88E5)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${AppUtils.labelKategoriJasa(s.kategori)} • ${AppUtils.formatJarakKm(s.jarakKm)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (s.ratingCount > 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFFFA726)),
                          const SizedBox(width: 2),
                          Text(s.ratingAvg.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(' (${s.ratingCount})',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                        ] else
                          const Text('Belum ada ulasan',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                        if (s.pesananSelesai > 0)
                          Text('  •  ${s.pesananSelesai}x dipesan',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(s.labelTarif,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor(auth.role))),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _pil(ServiceModel.labelStatusSekarang(st),
                          ServiceModel.warnaStatusSekarang(st)),
                      if (s.unggulan)
                        _pil('Pilihan Desa', const Color(0xFFF9A825),
                            ikon: Icons.star_rounded),
                      if (milikSaya) _pil('Jasa Anda', AppTheme.warnaWarga),
                    ]),
                  ],
                ),
              ),
              if (!milikSaya)
                Obx(() {
                  final bool fav = svc.favorit.contains(s.id);
                  return InkWell(
                    onTap: () => svc.toggleFavorit(s),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          size: 22,
                          color: fav ? Colors.red.shade600 : AppTheme.textSecondary),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lembar filter lanjutan
// ─────────────────────────────────────────────────────────────
class _FilterJasaSheet extends StatelessWidget {
  const _FilterJasaSheet();

  Widget _pilihan(String label, bool on, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: on ? FontWeight.w700 : FontWeight.normal),
    );
  }

  Widget _judul(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ServiceController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SingleChildScrollView(
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filter Pencarian',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                          onPressed: svc.resetFilter, child: const Text('Reset')),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Buka sekarang'),
                    subtitle: const Text('Sesuai jam kerja & status penyedia'),
                    value: svc.hanyaBuka.value,
                    onChanged: (v) => svc.hanyaBuka.value = v,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Identitas terverifikasi'),
                    value: svc.hanyaTerverifikasi.value,
                    onChanged: (v) => svc.hanyaTerverifikasi.value = v,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Favorit saya saja'),
                    value: svc.hanyaFavorit.value,
                    onChanged: (v) => svc.hanyaFavorit.value = v,
                  ),
                  _judul('Rating minimal'),
                  Wrap(spacing: 8, children: [
                    for (final r in [0.0, 3.0, 4.0, 4.5])
                      _pilihan(r == 0 ? 'Semua' : '★ ${r.toString().replaceAll('.0', '')}+',
                          svc.ratingMin.value == r, () => svc.ratingMin.value = r),
                  ]),
                  _judul('Jarak maksimal'),
                  Wrap(spacing: 8, children: [
                    for (final j in [0.0, 1.0, 3.0, 5.0, 10.0])
                      _pilihan(j == 0 ? 'Semua' : '${j.toInt()} km',
                          svc.jarakMaksKm.value == j, () => svc.jarakMaksKm.value = j),
                  ]),
                  _judul('Tarif mulai dari (maksimal)'),
                  Wrap(spacing: 8, children: [
                    for (final h in [0, 50000, 100000, 250000, 500000, 1000000])
                      _pilihan(h == 0 ? 'Semua' : '≤ ${rupiah(h)}',
                          svc.hargaMaks.value == h, () => svc.hargaMaks.value = h),
                  ]),
                  _judul('Lokasi pengerjaan'),
                  Wrap(spacing: 8, children: [
                    _pilihan('Semua', svc.modeFilter.value == 'semua',
                        () => svc.modeFilter.value = 'semua'),
                    _pilihan('Datang ke rumah', svc.modeFilter.value == 'datang',
                        () => svc.modeFilter.value = 'datang'),
                    _pilihan('Di tempat penyedia', svc.modeFilter.value == 'tempat',
                        () => svc.modeFilter.value = 'tempat'),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Lihat Hasil'),
                    ),
                  ),
                ],
              )),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// MENU ADMIN untuk satu jasa (dipakai di detail & tab Admin)
// ─────────────────────────────────────────────────────────────
Future<void> _menuAdminJasa(ServiceModel s) async {
  final svc = Get.find<ServiceController>();
  final pilih = await Get.bottomSheet<String>(
    SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${AppTheme.labelStatusJasa(s.status)} • ${s.peringatan} peringatan'),
            ),
            const Divider(height: 1),
            if (s.status == 'aktif')
              ListTile(
                leading: Icon(s.unggulan ? Icons.star_border : Icons.star_rounded,
                    color: const Color(0xFFF9A825)),
                title: Text(s.unggulan ? 'Cabut Pilihan Desa' : 'Jadikan Pilihan Desa'),
                onTap: () => Get.back(result: 'unggulan'),
              ),
            if (s.status == 'nonaktif' || s.status == 'diblokir' || s.status == 'ditolak')
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text('Aktifkan kembali'),
                onTap: () => Get.back(result: 'aktif'),
              ),
            if (s.status == 'aktif')
              ListTile(
                leading: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                title: const Text('Nonaktifkan'),
                onTap: () => Get.back(result: 'nonaktif'),
              ),
            if (s.status != 'diblokir')
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Blokir'),
                onTap: () => Get.back(result: 'blokir'),
              ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Lihat halaman jasa'),
              onTap: () => Get.back(result: 'lihat'),
            ),
          ],
        ),
      ),
    ),
  );
  if (pilih == null) return;

  bool ok = false;
  switch (pilih) {
    case 'unggulan':
      ok = await svc.setUnggulan(s, !s.unggulan);
      break;
    case 'aktif':
      ok = await svc.setStatusAdmin(s, 'aktif');
      break;
    case 'nonaktif':
    case 'blokir':
      final alasan = await mintaTeks(
          pilih == 'blokir' ? 'Blokir jasa' : 'Nonaktifkan jasa',
          'Alasan (dikirim ke pemilik)',
          minHuruf: 5);
      if (alasan == null) return;
      ok = await svc.setStatusAdmin(
          s, pilih == 'blokir' ? 'diblokir' : 'nonaktif', alasan: alasan);
      break;
    case 'lihat':
      Get.to(() => JasaDetailView(service: s));
      return;
    default:
      return;
  }
  showSnack(ok, 'Perubahan disimpan.', svc.errorMsg.value);
}

// ============================================================
// DETAIL JASA
// ============================================================
class JasaDetailView extends StatefulWidget {
  final ServiceModel service;
  const JasaDetailView({super.key, required this.service});

  @override
  State<JasaDetailView> createState() => _JasaDetailViewState();
}

class _JasaDetailViewState extends State<JasaDetailView> {
  final AuthController _auth = Get.find<AuthController>();
  final ServiceController _svc = Get.find<ServiceController>();
  late final Stream<ServiceModel?> _stream;
  late final Stream<List<ReviewModel>> _ulasanStream;
  late Future<List<PortofolioFoto>> _porto;
  bool _semuaUlasan = false;
  bool _jadwalTerbuka = false;

  @override
  void initState() {
    super.initState();
    _stream = _svc.jasaStream(widget.service.id);
    _ulasanStream = _svc.reviewsStream(widget.service.id);
    _porto = _svc.muatPortofolio(widget.service.id);
    _svc.catatDilihat(widget.service);
  }

  Future<void> _dialogLapor(ServiceModel s) async {
    String jenis = 'lainnya';
    final ctrl = TextEditingController();
    final kirim = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Laporkan Jasa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: jenis,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Jenis masalah'),
                  items: ServiceReportModel.jenisLabel.entries
                      .map((e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setD(() => jenis = v ?? jenis),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Ceritakan masalahnya (min. 10 huruf)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().length < 10) return;
                Get.back(result: true);
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
    if (kirim != true) return;
    final ok = await _svc.laporkanJasa(s, jenis: jenis, alasan: ctrl.text);
    showSnack(ok, 'Laporan terkirim ke Admin. Terima kasih.', _svc.errorMsg.value);
  }

  Future<void> _balas(ServiceModel s, ReviewModel r) async {
    final teks = await mintaTeks('Balas ulasan', 'Tulis balasan Anda', minHuruf: 3);
    if (teks == null) return;
    final ok = await _svc.balasUlasan(s.id, r, teks);
    showSnack(ok, 'Balasan terkirim.', _svc.errorMsg.value);
  }

  Future<void> _sembunyikan(ServiceModel s, ReviewModel r) async {
    String alasan = '';
    if (r.tampil) {
      final t = await mintaTeks('Sembunyikan ulasan', 'Alasan (dicatat di Log Keputusan)',
          minHuruf: 5);
      if (t == null) return;
      alasan = t;
    }
    final ok = await _svc.setUlasanTampil(s.id, r, !r.tampil, alasan: alasan);
    showSnack(ok, r.tampil ? 'Ulasan disembunyikan.' : 'Ulasan ditampilkan.',
        _svc.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceModel?>(
      stream: _stream,
      initialData: widget.service,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.search_off,
                title: 'Jasa tidak ditemukan',
                subtitle: 'Profil jasa ini sudah tidak tersedia.'),
          );
        }
        return _isi(s);
      },
    );
  }

  Widget _isi(ServiceModel s) {
    final user = _auth.currentUser.value;
    s.jarakKm = AppUtils.hitungJarak(user?.lokasiLat ?? -6.239265,
        user?.lokasiLng ?? 106.530200, s.lokasiLat, s.lokasiLng);
    final bool milikSaya = s.isMilikSaya(user?.uid ?? '');
    final bool staff = _auth.isStaff;
    final bool admin = _auth.role == 'admin';
    final Color k = AppTheme.kategoriJasaColor(s.kategori);
    final bool bisaPesan = !milikSaya && !staff && s.status == 'aktif';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _appBar(s, k, milikSaya, staff),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.status != 'aktif') _bannerStatus(s, milikSaya),
                  if (admin) _kartuAdmin(s),
                  if (s.status == 'aktif') _kartuStatus(s),
                  const SizedBox(height: 10),
                  _barisStatistik(s),
                  _judulSeksi('Tarif & Layanan', ikon: Icons.payments_outlined),
                  _kartuTarif(s),
                  _judulSeksi('Tentang', ikon: Icons.info_outline),
                  kartu(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.deskripsi,
                            style: const TextStyle(fontSize: 14, height: 1.55)),
                        if (s.tag.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: s.tag.map((t) => _pil(t, k)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (s.paket.isNotEmpty) ...[
                    _judulSeksi('Katalog Layanan',
                        ikon: Icons.list_alt_outlined),
                    ...s.paket.map((p) => _kartuPaket(s, p, bisaPesan)),
                  ],
                  _judulSeksi('Jadwal & Hari Libur',
                      ikon: Icons.schedule,
                      aksi: TextButton(
                        onPressed: () =>
                            setState(() => _jadwalTerbuka = !_jadwalTerbuka),
                        child: Text(_jadwalTerbuka ? 'Tutup' : 'Lihat semua'),
                      )),
                  _kartuJadwal(s),
                  _judulSeksi('Lokasi', ikon: Icons.place_outlined),
                  _kartuLokasi(s, k),
                  _judulSeksi('Portofolio', ikon: Icons.photo_library_outlined),
                  _portofolio(s),
                  _judulSeksi('Ulasan', ikon: Icons.rate_review_outlined),
                  _ulasan(s, milikSaya, admin),
                  if (!milikSaya && !staff) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _dialogLapor(s),
                        icon: Icon(Icons.flag_outlined,
                            size: 18, color: Colors.red.shade700),
                        label: Text('Laporkan jasa ini',
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _barBawah(s, milikSaya, staff, bisaPesan, k),
    );
  }

  // ── AppBar dengan kepala profil ──
  Widget _appBar(ServiceModel s, Color k, bool milikSaya, bool staff) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 232,
      backgroundColor: k,
      foregroundColor: Colors.white,
      actions: [
        if (!milikSaya && !staff)
          Obx(() {
            final bool fav = _svc.favorit.contains(s.id);
            return IconButton(
              tooltip: fav ? 'Hapus dari favorit' : 'Simpan ke favorit',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
              onPressed: () => _svc.toggleFavorit(s),
            );
          }),
        if (!milikSaya && !staff)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'lapor') _dialogLapor(s);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lapor', child: Text('Laporkan jasa')),
            ],
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [k, k.withOpacity(0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 26),
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  child: _avatarJasa(s, radius: 41),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(s.nama,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                ),
                if (s.namaUsaha.trim().isNotEmpty &&
                    s.namaUsaha.trim() != s.namaPenyedia)
                  Text('oleh ${s.namaPenyedia}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _pilPutih(AppUtils.labelKategoriJasa(s.kategori),
                        Icons.category_outlined),
                    if (s.ktpOk)
                      _pilPutih('svc_verified_badge'.tr, Icons.verified),
                    if (s.unggulan)
                      _pilPutih('Pilihan Desa', Icons.star_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pilPutih(String t, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ],
        ),
      );

  // ── Banner status non-aktif (untuk pemilik / Admin) ──
  Widget _bannerStatus(ServiceModel s, bool milikSaya) {
    final Color c = AppTheme.statusJasaColor(s.status);
    String teks;
    switch (s.status) {
      case 'pending':
        teks = 'Menunggu verifikasi Admin. Belum tampil di pencarian warga.';
        break;
      case 'ditolak':
        teks = 'Pengajuan ditolak.';
        break;
      case 'diblokir':
        teks = 'Profil diblokir Admin.';
        break;
      default:
        teks = 'Profil sedang nonaktif dan tidak tampil di pencarian.';
    }
    if ((s.alasanPenolakan ?? '').isNotEmpty) {
      teks += '\nAlasan: ${s.alasanPenolakan}';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(teks, style: TextStyle(fontSize: 12.5, height: 1.4, color: c)),
    );
  }

  Widget _kartuAdmin(ServiceModel s) {
    return kartu(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.warnaAdmin),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Admin • ${AppTheme.labelStatusJasa(s.status)} • ${s.peringatan} peringatan • dilihat ${s.dilihat}x • dihubungi ${s.dihubungi}x',
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
          TextButton(
              onPressed: () => _menuAdminJasa(s), child: const Text('Kelola')),
        ],
      ),
    );
  }

  // ── Status buka/tutup + jam hari ini ──
  Widget _kartuStatus(ServiceModel s) {
    final String st = s.statusSekarang();
    final Color c = ServiceModel.warnaStatusSekarang(st);
    final JamHari? hariIni = s.jadwal[DateTime.now().weekday];
    final String jamHariIni = s.jadwal.isEmpty
        ? 'Jam kerja belum diatur'
        : 'Hari ini ${hariIni?.label ?? 'libur'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(st == 'buka' ? Icons.storefront_outlined : Icons.do_not_disturb_on_outlined,
                  color: c, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ServiceModel.labelStatusSekarang(st),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: c, fontSize: 14)),
              ),
              Text(jamHariIni,
                  style: TextStyle(fontSize: 12, color: c)),
            ],
          ),
          if (s.ketersediaanEfektif != 'buka') ...[
            if (s.ketersediaanCatatan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.ketersediaanCatatan,
                    style: TextStyle(fontSize: 12.5, color: c)),
              ),
            if (s.tutupSampai != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Buka lagi setelah ${AppUtils.formatTanggal(s.tutupSampai!)}',
                    style: TextStyle(fontSize: 12.5, color: c)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _barisStatistik(ServiceModel s) {
    Widget tile(IconData i, String nilai, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(i, size: 20, color: AppTheme.primaryColor(_auth.role)),
                const SizedBox(height: 4),
                Text(nilai,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile(Icons.star_rounded,
            s.ratingCount > 0 ? s.ratingAvg.toStringAsFixed(1) : '–',
            '${s.ratingCount} ulasan'),
        const SizedBox(width: 8),
        tile(Icons.task_alt, '${s.pesananSelesai}', 'pesanan selesai'),
        const SizedBox(width: 8),
        tile(Icons.workspace_premium_outlined,
            s.pengalamanTahun > 0 ? '${s.pengalamanTahun} th' : '–', 'pengalaman'),
        const SizedBox(width: 8),
        tile(Icons.near_me_outlined, AppUtils.formatJarakKm(s.jarakKm), 'dari Anda'),
      ],
    );
  }

  Widget _kartuTarif(ServiceModel s) {
    final double? jarak = s.jarakKm;
    final bool dalam = jarak != null && jarak <= s.areaKm;
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.labelTarif,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor(_auth.role))),
          const SizedBox(height: 8),
          _barisInfo(Icons.home_repair_service_outlined,
              ServiceModel.labelMode(s.modeLayanan)),
          if (s.modeLayanan != 'tempat')
            _barisInfo(
                dalam ? Icons.check_circle_outline : Icons.info_outline,
                dalam
                    ? 'Jangkauan hingga ${s.areaKm.toStringAsFixed(0)} km — lokasi Anda masuk jangkauan'
                    : 'Jangkauan hingga ${s.areaKm.toStringAsFixed(0)} km — lokasi Anda ±${AppUtils.formatJarakKm(jarak)} (di luar jangkauan, bisa tetap dipesan dan dinegosiasikan)',
                warna: dalam ? Colors.green.shade700 : Colors.orange.shade800),
          if (s.kapasitasAktif > 0)
            _barisInfo(Icons.groups_outlined,
                'Menerima maksimal ${s.kapasitasAktif} pesanan berjalan bersamaan'),
          if (s.alamatUsaha.isNotEmpty)
            _barisInfo(Icons.place_outlined, s.alamatUsaha),
          _barisInfo(Icons.handshake_outlined,
              'Pembayaran langsung ke penyedia (tunai / transfer) setelah disepakati — tidak lewat aplikasi.',
              size: 12),
        ],
      ),
    );
  }

  Widget _kartuPaket(ServiceModel s, PaketJasa p, bool bisaPesan) {
    return kartu(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (p.deskripsi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(p.deskripsi,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                  ),
                const SizedBox(height: 4),
                Text(p.labelHarga,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.primaryColor(_auth.role))),
              ],
            ),
          ),
          if (bisaPesan)
            OutlinedButton(
              onPressed: () =>
                  Get.to(() => BuatPesananView(service: s, paketAwal: p)),
              child: const Text('Pesan'),
            ),
        ],
      ),
    );
  }

  Widget _kartuJadwal(ServiceModel s) {
    final int hariIni = DateTime.now().weekday;
    final libur = s.tanggalLibur
        .where((d) => !d.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day)))
        .toList()
      ..sort();
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.jadwal.isEmpty)
            const Text('Penyedia belum mengatur jam kerja.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
          else
            ...List.generate(_jadwalTerbuka ? 7 : 1, (i) {
              final int h = _jadwalTerbuka ? i + 1 : hariIni;
              final JamHari? j = s.jadwal[h];
              final bool ini = h == hariIni;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(ServiceModel.namaHari(h),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: ini ? FontWeight.bold : FontWeight.normal)),
                    ),
                    Text(j?.label ?? 'Libur',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: ini ? FontWeight.bold : FontWeight.normal,
                            color: (j?.aktif ?? false)
                                ? AppTheme.textPrimary
                                : Colors.red.shade700)),
                    if (ini)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('(hari ini)',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                  ],
                ),
              );
            }),
          if (libur.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Libur / tidak tersedia:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: libur
                  .take(10)
                  .map((d) => _pil(AppUtils.formatTanggal(d), Colors.red.shade700))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuLokasi(ServiceModel s, Color k) {
    final titik = LatLng(s.lokasiLat, s.lokasiLng);
    return kartu(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: titik,
                  initialZoom: 15,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                  onTap: (_, __) => bukaUri(uriPeta(s.lokasiLat, s.lokasiLng)),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.talagasari_hub',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: titik,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 40, color: k),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.directions_outlined),
            title: Text(s.alamatUsaha.isEmpty ? 'Buka di aplikasi peta' : s.alamatUsaha,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('${AppUtils.formatJarakKm(s.jarakKm)} dari lokasi Anda',
                style: const TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => bukaUri(uriPeta(s.lokasiLat, s.lokasiLng)),
          ),
        ],
      ),
    );
  }

  Widget _portofolio(ServiceModel s) {
    return FutureBuilder<List<PortofolioFoto>>(
      future: _porto,
      builder: (context, snap) {
        final semua = <String>[
          ...s.fotoPortofolio,
          ...(snap.data ?? const <PortofolioFoto>[]).map((e) => e.foto),
        ];
        if (snap.connectionState == ConnectionState.waiting && semua.isEmpty) {
          return const ShimmerBox(height: 100);
        }
        if (semua.isEmpty) {
          return const Text('Belum ada foto portofolio.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary));
        }
        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: semua.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => BouncyTap(
              onTap: () => tampilkanFoto(semua[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ImageUtil.image(semua[i], width: 150, height: 120),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Ulasan: ringkasan + daftar ──
  Widget _ulasan(ServiceModel s, bool milikSaya, bool admin) {
    final String myUid = _auth.currentUser.value?.uid ?? '';
    final Color primary = AppTheme.primaryColor(_auth.role);
    final int total = s.ratingCount == 0 ? 1 : s.ratingCount;

    Widget barAspek(String label, String kunci) {
      final double v = s.aspekRata(kunci);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 92,
                child: Text(label, style: const TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v / 5,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFFFFA726),
                ),
              ),
            ),
            SizedBox(
                width: 34,
                child: Text(v == 0 ? '–' : v.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    final ringkasan = s.ratingCount == 0
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
                'Belum ada ulasan. Ulasan hanya dari warga yang sudah menyelesaikan pesanan.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          )
        : Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text(s.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.bold)),
                      RatingStars(rating: s.ratingAvg, size: 15),
                      const SizedBox(height: 2),
                      Text('${s.ratingCount} ulasan',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        for (int b = 5; b >= 1; b--)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text('$b',
                                    style: const TextStyle(fontSize: 11.5)),
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Color(0xFFFFA726)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (s.ratingDist[b] ?? 0) / total,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade200,
                                      color: primary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 26,
                                  child: Text('${s.ratingDist[b] ?? 0}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (s.aspekN > 0) ...[
                const Divider(height: 22),
                barAspek('Kualitas kerja', 'kualitas'),
                barAspek('Ketepatan waktu', 'ketepatan'),
                barAspek('Komunikasi', 'komunikasi'),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kartu(margin: EdgeInsets.zero, child: ringkasan),
        const SizedBox(height: 8),
        StreamBuilder<List<ReviewModel>>(
          stream: _ulasanStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const ShimmerBox(height: 60);
            }
            final semua = (snap.data ?? <ReviewModel>[])
                .where((r) => r.tampil || admin || r.idPengguna == myUid)
                .toList();
            if (semua.isEmpty) return const SizedBox.shrink();
            final tampil = _semuaUlasan ? semua : semua.take(4).toList();
            return Column(
              children: [
                ...tampil.map((r) => _kartuUlasan(s, r, milikSaya, admin, primary)),
                if (semua.length > 4)
                  TextButton(
                    onPressed: () => setState(() => _semuaUlasan = !_semuaUlasan),
                    child: Text(_semuaUlasan
                        ? 'Tampilkan lebih sedikit'
                        : 'Lihat semua ${semua.length} ulasan'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kartuUlasan(
      ServiceModel s, ReviewModel r, bool milikSaya, bool admin, Color primary) {
    return kartu(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: primary.withOpacity(0.12),
                child: Text(AppUtils.inisial(r.namaPengguna),
                    style: TextStyle(
                        fontSize: 11, color: primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.namaPengguna,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(AppUtils.formatRelatif(r.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              RatingStars(rating: r.rating.toDouble(), size: 14),
            ],
          ),
          if (r.namaLayanan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _pil('Layanan: ${r.namaLayanan}', AppTheme.textSecondary),
            ),
          if (!r.tampil)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _pil('Disembunyikan Admin', Colors.red.shade700,
                  ikon: Icons.visibility_off_outlined),
            ),
          if (r.komentar.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.komentar, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          if (r.balasan.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Balasan penyedia',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(r.balasan, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          if (milikSaya || admin)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  if (milikSaya)
                    TextButton(
                      onPressed: () => _balas(s, r),
                      child: Text(r.balasan.isEmpty ? 'Balas' : 'Ubah balasan'),
                    ),
                  if (admin)
                    TextButton(
                      onPressed: () => _sembunyikan(s, r),
                      child: Text(r.tampil ? 'Sembunyikan' : 'Tampilkan'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Bilah tombol bawah ──
  Widget? _barBawah(
      ServiceModel s, bool milikSaya, bool staff, bool bisaPesan, Color k) {
    if (staff) return null;
    Widget bungkus(Widget child) => SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: child,
          ),
        );

    if (milikSaya) {
      return bungkus(Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showFormJasa(existing: s),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profil'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => const DasborJasaView()),
              icon: const Icon(Icons.dashboard_outlined, size: 18, color: Colors.white),
              label: const Text('Dasbor', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: k),
            ),
          ),
        ],
      ));
    }

    final bool dapatPesan = bisaPesan &&
        !(s.ketersediaanEfektif != 'buka' && s.tutupSampai == null);
    final String label = s.status != 'aktif'
        ? 'Tidak tersedia'
        : dapatPesan
            ? 'Pesan Jasa'
            : (s.ketersediaanEfektif == 'penuh' ? 'Sedang Penuh' : 'Sedang Tutup');

    return bungkus(Row(
      children: [
        _tombolIkon(Icons.chat_bubble_outline, 'Chat', k, () async {
          _svc.catatDihubungi(s);
          await _bukaChat(uid: s.uidPenyedia, nama: s.namaPenyedia, foto: s.fotoUrl);
        }),
        const SizedBox(width: 8),
        _tombolIkon(Icons.phone_in_talk_outlined, 'WhatsApp', const Color(0xFF25D366),
            () {
          _svc.catatDihubungi(s);
          _bukaWa(s.whatsapp,
              'Halo ${s.nama}, saya ${_auth.currentUser.value?.nama ?? 'warga'} dari aplikasi Talagasari Hub. Saya tertarik dengan jasa Anda.');
        }),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: dapatPesan
                  ? () => Get.to(() => BuatPesananView(service: s))
                  : null,
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              label: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: k),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _tombolIkon(IconData i, String tip, Color c, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Icon(i, color: c)),
        ),
      ),
    );
  }
}


// ============================================================
// FORMULIR PROFIL JASA — daftar baru / ubah profil
// ============================================================
Future<void> showFormJasa({ServiceModel? existing}) async {
  // Membuka jasa wajib verifikasi identitas (terkunci bila belum)
  if (existing == null && !await wajibVerifikasi()) return;
  await Get.to(() => FormJasaView(existing: existing));
}

class FormJasaView extends StatefulWidget {
  final ServiceModel? existing;
  const FormJasaView({super.key, this.existing});

  @override
  State<FormJasaView> createState() => _FormJasaViewState();
}

class _FormJasaViewState extends State<FormJasaView> {
  final AuthController _auth = Get.find<AuthController>();
  final ServiceController _svc = Get.find<ServiceController>();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final MapController _map = MapController();

  late ProfilJasaInput _in;
  late final TextEditingController _cNama;
  late final TextEditingController _cDesk;
  late final TextEditingController _cPeng;
  late final TextEditingController _cWa;
  late final TextEditingController _cAlamat;
  late final TextEditingController _cMulai;
  late final TextEditingController _cMaks;
  final TextEditingController _cTag = TextEditingController();

  bool _satuanDiubah = false;
  bool _fotoSiap = false;
  List<PortofolioFoto> _fotoLama = [];
  List<String> _lamaTersisa = [];
  List<File> _fotoBaru = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final u = _auth.currentUser.value;
    final String kat0 = AppUtils.daftarKategoriJasa.first['value']!;
    _in = e != null
        ? e.keInput()
        : ProfilJasaInput(
            kategori: kat0,
            whatsapp: u?.nomorTelepon ?? '',
            alamatUsaha: u?.alamatPenuh ?? '',
            lat: u?.lokasiLat ?? -6.239265,
            lng: u?.lokasiLng ?? 106.530200,
            tarifSatuan: ServiceModel.satuanBawaan(kat0),
          );
    _cNama = TextEditingController(text: _in.namaUsaha);
    _cDesk = TextEditingController(text: _in.deskripsi);
    _cPeng = TextEditingController(
        text: _in.pengalamanTahun > 0 ? '${_in.pengalamanTahun}' : '');
    _cWa = TextEditingController(text: _in.whatsapp);
    _cAlamat = TextEditingController(text: _in.alamatUsaha);
    _cMulai = TextEditingController(
        text: _in.tarifMulai > 0 ? '${_in.tarifMulai}' : '');
    _cMaks = TextEditingController(
        text: _in.tarifMaks > 0 ? '${_in.tarifMaks}' : '');
    if (e != null) {
      _satuanDiubah = true;
      _muatFoto(e.id);
    } else {
      _fotoSiap = true;
    }
  }

  @override
  void dispose() {
    _cNama.dispose();
    _cDesk.dispose();
    _cPeng.dispose();
    _cWa.dispose();
    _cAlamat.dispose();
    _cMulai.dispose();
    _cMaks.dispose();
    _cTag.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _muatFoto(String id) async {
    final l = await _svc.muatPortofolio(id);
    if (!mounted) return;
    setState(() {
      _fotoLama = l;
      _lamaTersisa = l.map((p) => p.foto).toList();
      _fotoSiap = true;
    });
  }

  int _angka(String s) => int.tryParse(s.trim()) ?? 0;

  // ── Kartu seksi ──
  Widget _seksi(String judul, IconData ikon, List<Widget> isi, {String? catatan}) {
    return kartu(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 20, color: AppTheme.primaryColor(_auth.role)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(judul,
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (catatan != null) ...[
            const SizedBox(height: 4),
            Text(catatan,
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
          ],
          const SizedBox(height: 12),
          ...isi,
        ],
      ),
    );
  }

  // ── Tag keahlian ──
  void _tambahTag(String t) {
    final v = t.trim();
    if (v.isEmpty) return;
    if (v.length > 24) {
      showSnack(false, '', 'Satu keahlian maksimal 24 huruf.');
      return;
    }
    if (_in.tag.any((x) => x.toLowerCase() == v.toLowerCase())) return;
    if (_in.tag.length >= 8) {
      showSnack(false, '', 'Maksimal 8 keahlian.');
      return;
    }
    setState(() => _in.tag.add(v));
  }

  Widget _blokTag(Color primary) {
    final saran = ServiceModel.saranTag(_in.kategori)
        .where((t) => !_in.tag.any((x) => x.toLowerCase() == t.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keahlian / layanan utama (maks. 8)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        if (_in.tag.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _in.tag
                .map((t) => InputChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => setState(() => _in.tag.remove(t)),
                    ))
                .toList(),
          ),
        if (saran.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Saran (ketuk untuk menambah):',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: saran
                .map((t) => ActionChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _tambahTag(t),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cTag,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  _tambahTag(v);
                  _cTag.clear();
                },
                decoration: const InputDecoration(
                    labelText: 'Tambah keahlian lain', isDense: true),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: primary),
              onPressed: () {
                _tambahTag(_cTag.text);
                _cTag.clear();
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Katalog layanan ──
  Future<void> _dialogPaket({PaketJasa? paket, int? index}) async {
    final cNama = TextEditingController(text: paket?.nama ?? '');
    final cDesk = TextEditingController(text: paket?.deskripsi ?? '');
    final cHarga = TextEditingController(
        text: (paket != null && paket.harga > 0) ? '${paket.harga}' : '');
    String satuan = paket?.satuan ?? _in.tarifSatuan;
    if (!ServiceModel.daftarSatuan.contains(satuan)) {
      satuan = ServiceModel.daftarSatuan.last;
    }
    String? galat;

    final hasil = await Get.dialog<PaketJasa>(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(paket == null ? 'Tambah Layanan' : 'Ubah Layanan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cNama,
                  maxLength: 40,
                  decoration: const InputDecoration(
                      labelText: 'Nama layanan / paket',
                      hintText: 'Contoh: Servis kulkas, Cuci setrika 1 kg'),
                ),
                TextField(
                  controller: cDesk,
                  maxLines: 2,
                  maxLength: 120,
                  decoration:
                      const InputDecoration(labelText: 'Keterangan (opsional)'),
                ),
                TextField(
                  controller: cHarga,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Harga (Rp)',
                      helperText: 'Kosongkan bila harga nego'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: satuan,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  items: ServiceModel.daftarSatuan
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setD(() => satuan = v ?? satuan),
                ),
                if (galat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(galat!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (cNama.text.trim().length < 3) {
                  setD(() => galat = 'Nama layanan minimal 3 huruf.');
                  return;
                }
                Get.back(
                  result: PaketJasa(
                    id: paket?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    nama: cNama.text.trim(),
                    deskripsi: cDesk.text.trim(),
                    harga: _angka(cHarga.text),
                    satuan: satuan,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (hasil == null) return;
    setState(() {
      if (index != null) {
        _in.paket[index] = hasil;
      } else {
        _in.paket.add(hasil);
      }
    });
  }

  Widget _blokPaket(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_in.paket.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'Belum ada layanan. Tambahkan minimal satu agar warga bisa langsung memesan paket tertentu.',
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
          ),
        ..._in.paket.asMap().entries.map((e) {
          final p = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13.5)),
                      Text(p.labelHarga,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _dialogPaket(paket: p, index: e.key),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: Colors.red.shade700),
                  onPressed: () => setState(() => _in.paket.removeAt(e.key)),
                ),
              ],
            ),
          );
        }),
        if (_in.paket.length < 10)
          OutlinedButton.icon(
            onPressed: () => _dialogPaket(),
            icon: const Icon(Icons.add),
            label: Text('Tambah layanan (${_in.paket.length}/10)'),
          ),
      ],
    );
  }

  // ── Jadwal mingguan & libur ──
  Future<void> _pilihJam(int hari, bool mulai) async {
    final j = _in.jadwal[hari] ?? const JamHari();
    final menit = mulai ? j.mulai : j.selesai;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: (menit ~/ 60) % 24, minute: menit % 60));
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    setState(() {
      _in.jadwal[hari] = mulai ? j.copyWith(mulai: m) : j.copyWith(selesai: m);
    });
  }

  Widget _blokJadwal(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(7, (i) {
          final int h = i + 1;
          final JamHari j = _in.jadwal[h] ?? const JamHari(aktif: false);
          return Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(ServiceModel.namaHari(h),
                    style: const TextStyle(fontSize: 13)),
              ),
              Switch(
                value: j.aktif,
                onChanged: (v) => setState(() => _in.jadwal[h] = j.copyWith(aktif: v)),
              ),
              if (j.aktif) ...[
                TextButton(
                  onPressed: () => _pilihJam(h, true),
                  child: Text(JamHari.format(j.mulai)),
                ),
                const Text('–'),
                TextButton(
                  onPressed: () => _pilihJam(h, false),
                  child: Text(JamHari.format(j.selesai)),
                ),
              ] else
                Text('Libur',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
            ],
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final sen = _in.jadwal[1] ?? const JamHari();
              setState(() {
                for (int h = 1; h <= 7; h++) {
                  final j = _in.jadwal[h] ?? const JamHari();
                  if (j.aktif) {
                    _in.jadwal[h] = j.copyWith(mulai: sen.mulai, selesai: sen.selesai);
                  }
                }
              });
            },
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Samakan jam semua hari aktif dengan Senin'),
          ),
        ),
        const Divider(height: 22),
        const Text('Tanggal libur / tidak tersedia',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ..._in.tanggalLibur.map((d) => InputChip(
                  label: Text(AppUtils.formatTanggal(d),
                      style: const TextStyle(fontSize: 12)),
                  onDeleted: () => setState(() => _in.tanggalLibur.remove(d)),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Tambah tanggal', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final now = DateTime.now();
                final p = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 1)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (p == null) return;
                final d = DateTime(p.year, p.month, p.day);
                if (_in.tanggalLibur.any((x) =>
                    x.year == d.year && x.month == d.month && x.day == d.day)) {
                  return;
                }
                setState(() => _in.tanggalLibur.add(d));
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Lokasi ──
  Future<void> _lokasiSaya() async {
    await _auth.updateLokasiOtomatis();
    final u = _auth.currentUser.value;
    if (u == null) return;
    setState(() {
      _in.lat = u.lokasiLat;
      _in.lng = u.lokasiLng;
    });
    _map.move(LatLng(_in.lat, _in.lng), 16);
  }

  Widget _blokLokasi(Color primary) {
    final titik = LatLng(_in.lat, _in.lng);
    final Color k = AppTheme.kategoriJasaColor(_in.kategori);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 210,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: titik,
                initialZoom: 15.5,
                onTap: (_, p) => setState(() {
                  _in.lat = p.latitude;
                  _in.lng = p.longitude;
                }),
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.talagasari_hub',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: titik,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on, size: 44, color: k),
                  ),
                ]),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                  'Ketuk peta untuk memindahkan pin.\n${_in.lat.toStringAsFixed(5)}, ${_in.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
            ),
            TextButton.icon(
              onPressed: _lokasiSaya,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Lokasi saya'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _cAlamat,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Alamat lengkap (jalan, RT/RW, dusun, patokan)',
              hintText: 'Contoh: Kp. Talagasari RT 02/05, dekat masjid'),
          validator: (v) => (v == null || v.trim().length < 8)
              ? 'Isi alamat atau patokan minimal 8 huruf'
              : null,
        ),
      ],
    );
  }

  // ── Kirim ──
  bool get _perluVerifikasiUlang {
    final e = widget.existing;
    if (e == null || e.status != 'aktif') return false;
    final geser = AppUtils.hitungJarak(e.lokasiLat, e.lokasiLng, _in.lat, _in.lng);
    return e.kategori != _in.kategori || geser > 0.3;
  }

  Future<void> _kirim() async {
    if (!_form.currentState!.validate()) {
      showSnack(false, '', 'Lengkapi isian yang masih merah.');
      return;
    }
    _in.namaUsaha = _cNama.text;
    _in.deskripsi = _cDesk.text;
    _in.pengalamanTahun = _angka(_cPeng.text).clamp(0, 60).toInt();
    _in.whatsapp = _cWa.text;
    _in.alamatUsaha = _cAlamat.text;
    _in.tarifMulai = _angka(_cMulai.text);
    _in.tarifMaks = _angka(_cMaks.text);

    if (_in.tarifMaks > 0 && _in.tarifMaks < _in.tarifMulai) {
      showSnack(false, '', 'Tarif "sampai" tidak boleh lebih kecil dari tarif mulai.');
      return;
    }
    if (!_in.jadwal.values.any((j) => j.aktif)) {
      showSnack(false, '', 'Aktifkan minimal satu hari kerja.');
      return;
    }
    for (final e in _in.jadwal.entries) {
      if (e.value.aktif && e.value.selesai <= e.value.mulai) {
        showSnack(false, '',
            'Jam selesai hari ${ServiceModel.namaHari(e.key)} harus setelah jam mulai.');
        return;
      }
    }
    _in.tanggalLibur = _in.tanggalLibur
        .where((d) => !d.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day)))
        .toList();

    final hapus = _fotoLama
        .where((p) => !_lamaTersisa.contains(p.foto))
        .map((p) => p.id)
        .toList();
    final adaFoto = _fotoLama.length - hapus.length + _fotoBaru.length;
    if (widget.existing == null && adaFoto == 0) {
      final lanjut = await Get.dialog<bool>(AlertDialog(
        title: const Text('Belum ada foto'),
        content: const Text(
            'Profil dengan foto portofolio lebih dipercaya warga dan lebih cepat disetujui Admin. Lanjut tanpa foto?'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Tambah foto')),
          TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Lanjut')),
        ],
      ));
      if (lanjut != true) return;
    }

    final ok = await _svc.simpanProfil(
      existing: widget.existing,
      input: _in,
      fotoBaru: _fotoBaru,
      idPortofolioHapus: hapus,
    );
    if (ok) {
      Get.back();
      showSnack(
          true,
          widget.existing == null
              ? 'Pengajuan terkirim. Menunggu verifikasi Admin desa.'
              : 'Profil jasa diperbarui.',
          '');
    } else {
      showSnack(false, '', _svc.errorMsg.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final bool baru = widget.existing == null;
    final eks = widget.existing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(baru ? 'Daftar Penyedia Jasa' : 'Ubah Profil Jasa'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            if (baru)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                    'Isi sejelas mungkin. Pengajuan diperiksa Admin desa sebelum tampil ke warga. Pembayaran pesanan dilakukan langsung antara Anda dan warga.',
                    style: TextStyle(fontSize: 12.5, height: 1.45)),
              ),
            if (eks != null && eks.status == 'ditolak')
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.35)),
                ),
                child: Text(
                    'Pengajuan sebelumnya ditolak: ${eks.alasanPenolakan ?? '-'}\nPerbaiki data lalu kirim ulang.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.45, color: Colors.red.shade800)),
              ),
            if (_perluVerifikasiUlang)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.45)),
                ),
                child: Text(
                    'Mengganti kategori atau memindahkan lokasi lebih dari 300 m membuat profil diverifikasi ulang Admin dan disembunyikan sementara dari pencarian.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.45, color: Colors.orange.shade900)),
              ),

            // ── Identitas ──
            _seksi('Identitas Jasa', Icons.badge_outlined, [
              TextFormField(
                controller: _cNama,
                maxLength: 40,
                decoration: const InputDecoration(
                    labelText: 'Nama usaha / panggilan jasa (opsional)',
                    hintText: 'Kosongkan bila memakai nama sendiri'),
              ),
              DropdownButtonFormField<String>(
                value: _in.kategori,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategori jasa'),
                items: AppUtils.daftarKategoriJasa
                    .map((k) => DropdownMenuItem(
                          value: k['value'],
                          child: Text(k['label']!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  if (v == null) return;
                  _in.kategori = v;
                  if (!_satuanDiubah) _in.tarifSatuan = ServiceModel.satuanBawaan(v);
                }),
              ),
              const SizedBox(height: 14),
              _blokTag(primary),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cDesk,
                maxLines: 5,
                maxLength: 600,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi layanan',
                  hintText:
                      'Jelaskan keahlian, pengalaman, cara kerja, dan area yang dilayani',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 30)
                    ? 'Deskripsi minimal 30 huruf agar warga paham layanan Anda'
                    : null,
              ),
              TextFormField(
                controller: _cWa,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp', hintText: '08xxxxxxxxxx'),
                validator: (v) {
                  final n = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return (n.length < 9 || n.length > 15)
                      ? 'Nomor tidak valid'
                      : null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cPeng,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Pengalaman (tahun)'),
              ),
            ]),

            // ── Tarif & layanan ──
            _seksi('Tarif & Cara Layanan', Icons.payments_outlined, [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cMulai,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Tarif mulai (Rp)',
                          helperText: 'Kosong = nego'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cMaks,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Sampai (Rp)', helperText: 'Opsional'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: ServiceModel.daftarSatuan.contains(_in.tarifSatuan)
                    ? _in.tarifSatuan
                    : ServiceModel.daftarSatuan.last,
                decoration: const InputDecoration(labelText: 'Satuan tarif'),
                items: ServiceModel.daftarSatuan
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _satuanDiubah = true;
                  _in.tarifSatuan = v ?? _in.tarifSatuan;
                }),
              ),
              const SizedBox(height: 14),
              const Text('Lokasi pengerjaan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const ['datang', 'tempat', 'keduanya'])
                    ChoiceChip(
                      label: Text(
                          m == 'datang'
                              ? 'Datang ke rumah warga'
                              : m == 'tempat'
                                  ? 'Warga datang ke tempat saya'
                                  : 'Keduanya',
                          style: const TextStyle(fontSize: 12)),
                      selected: _in.modeLayanan == m,
                      onSelected: (_) => setState(() => _in.modeLayanan = m),
                    ),
                ],
              ),
              if (_in.modeLayanan != 'tempat') ...[
                const SizedBox(height: 10),
                Text('Jangkauan datang ke rumah: ${_in.areaKm.toStringAsFixed(0)} km',
                    style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _in.areaKm.clamp(1, 20).toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${_in.areaKm.toStringAsFixed(0)} km',
                  onChanged: (v) => setState(() => _in.areaKm = v),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Maksimal pesanan berjalan bersamaan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Text(
                  'Bila tercapai, status otomatis menjadi "Penuh" lalu terbuka lagi saat ada pekerjaan selesai.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in const [0, 1, 2, 3, 5, 10])
                    ChoiceChip(
                      label: Text(n == 0 ? 'Tanpa batas' : '$n',
                          style: const TextStyle(fontSize: 12)),
                      selected: _in.kapasitasAktif == n,
                      onSelected: (_) => setState(() => _in.kapasitasAktif = n),
                    ),
                ],
              ),
            ]),

            // ── Katalog ──
            _seksi('Katalog Layanan', Icons.list_alt_outlined, [_blokPaket(primary)],
                catatan:
                    'Daftar layanan dengan harga masing-masing. Warga bisa memesan langsung dari sini.'),

            // ── Jadwal ──
            _seksi('Jam Kerja & Libur', Icons.schedule, [_blokJadwal(primary)],
                catatan:
                    'Dipakai untuk status "Buka sekarang" dan membatasi tanggal pemesanan.'),

            // ── Lokasi ──
            _seksi('Lokasi Usaha', Icons.place_outlined, [_blokLokasi(primary)]),

            // ── Foto ──
            _seksi('Portofolio', Icons.photo_library_outlined, [
              if (!_fotoSiap)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                FotoPicker(
                  maks: 6,
                  label: 'Foto hasil kerja (maks. 6)',
                  bantuan:
                      'Foto otomatis dikecilkan. Foto pertama menjadi sampul di daftar.',
                  fotoLama: _fotoLama.map((p) => p.foto).toList(),
                  onChanged: (baru, lama) {
                    _fotoBaru = baru;
                    _lamaTersisa = lama;
                  },
                ),
            ]),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Obx(() => SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _svc.isSubmitting.value ? null : _kirim,
                      child: _svc.isSubmitting.value
                          ? loadingChild()
                          : Text(baru ? 'Kirim Pengajuan' : 'Simpan Perubahan',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// LAPOR JASA (dipakai di detail jasa & detail pesanan)
// ============================================================
Future<void> dialogLaporJasa(ServiceModel s, {String orderId = ''}) async {
  final svc = Get.find<ServiceController>();
  String jenis = 'lainnya';
  final ctrl = TextEditingController();
  final kirim = await Get.dialog<bool>(
    StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Laporkan Jasa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: jenis,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis masalah'),
                items: ServiceReportModel.jenisLabel.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setD(() => jenis = v ?? jenis),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Ceritakan masalahnya (min. 10 huruf)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().length < 10) return;
              Get.back(result: true);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    ),
  );
  if (kirim != true) return;
  final ok = await svc.laporkanJasa(s,
      jenis: jenis, alasan: ctrl.text, orderId: orderId);
  showSnack(ok, 'Laporan terkirim ke Admin. Terima kasih.', svc.errorMsg.value);
}

String _dua(int n) => n.toString().padLeft(2, '0');

// ============================================================
// BUAT PESANAN — warga memesan jasa
// ============================================================
class BuatPesananView extends StatefulWidget {
  final ServiceModel service;
  final PaketJasa? paketAwal;
  const BuatPesananView({super.key, required this.service, this.paketAwal});

  @override
  State<BuatPesananView> createState() => _BuatPesananViewState();
}

class _BuatPesananViewState extends State<BuatPesananView> {
  final AuthController _auth = Get.find<AuthController>();
  final OrderController _ord = Get.find<OrderController>();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _cLayanan;
  late final TextEditingController _cDesk;
  late final TextEditingController _cAlamat;

  PaketJasa? _paket;
  int _jumlah = 1;
  DateTime? _tanggal;
  TimeOfDay? _jam;
  late String _mode;
  List<File> _foto = [];

  ServiceModel get s => widget.service;

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser.value;
    _paket = widget.paketAwal;
    _cLayanan = TextEditingController();
    _cDesk = TextEditingController();
    final alamat = <String>[
      if ((u?.alamatLengkap ?? '').isNotEmpty) u!.alamatLengkap,
      if ((u?.alamatPatokan ?? '').isNotEmpty) 'Patokan: ${u!.alamatPatokan}',
    ].join(', ');
    _cAlamat = TextEditingController(text: alamat);
    _mode = s.modeLayanan == 'tempat' ? 'tempat' : 'datang';
  }

  @override
  void dispose() {
    _cLayanan.dispose();
    _cDesk.dispose();
    _cAlamat.dispose();
    super.dispose();
  }

  int get _estimasi => (_paket?.harga ?? 0) * _jumlah;

  DateTime _hariIni() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime? _tanggalPertama() {
    final h = _hariIni();
    for (int i = 0; i < 90; i++) {
      final d = h.add(Duration(days: i));
      if (s.alasanTidakBisaDipesan(d) == null) return d;
    }
    return null;
  }

  Future<void> _pilihTanggal() async {
    final pertama = _tanggalPertama();
    if (pertama == null) {
      showSnack(false, '',
          'Tidak ada tanggal tersedia dalam 90 hari ke depan. Coba lagi nanti.');
      return;
    }
    final awal = (_tanggal != null && s.alasanTidakBisaDipesan(_tanggal!) == null)
        ? _tanggal!
        : pertama;
    final p = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: _hariIni(),
      lastDate: _hariIni().add(const Duration(days: 90)),
      helpText: 'Pilih tanggal pengerjaan',
      selectableDayPredicate: (d) => s.alasanTidakBisaDipesan(d) == null,
    );
    if (p != null) setState(() => _tanggal = DateTime(p.year, p.month, p.day));
  }

  Future<void> _pilihJam() async {
    final t = await showTimePicker(
        context: context, initialTime: _jam ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => _jam = t);
  }

  String get _infoJamKerja {
    final t = _tanggal;
    if (t == null || s.jadwal.isEmpty) return '';
    final j = s.jadwal[t.weekday];
    if (j == null || !j.aktif) return '';
    return 'Jam kerja ${ServiceModel.namaHari(t.weekday)}: ${j.label}';
  }

  Future<void> _kirim() async {
    if (!_form.currentState!.validate()) return;
    final u = _auth.currentUser.value;
    if (u == null) return;
    if (_tanggal == null) {
      showSnack(false, '', 'Pilih tanggal pengerjaan dulu.');
      return;
    }
    final alasan = s.alasanTidakBisaDipesan(_tanggal!);
    if (alasan != null) {
      showSnack(false, '', alasan);
      return;
    }
    if (_jam != null && s.jadwal.isNotEmpty) {
      final j = s.jadwal[_tanggal!.weekday];
      final m = _jam!.hour * 60 + _jam!.minute;
      if (j != null && j.aktif && (m < j.mulai || m >= j.selesai)) {
        showSnack(false, '',
            'Jam di luar jam kerja penyedia (${j.label}). Pilih jam lain atau kosongkan jam.');
        return;
      }
    }

    final bool datang = _mode == 'datang';
    final String nama =
        _paket?.nama ?? (_cLayanan.text.trim().isEmpty ? 'Permintaan khusus' : _cLayanan.text.trim());
    final o = await _ord.buatPesanan(
      s: s,
      paket: _paket,
      namaLayanan: nama,
      jumlah: _jumlah,
      deskripsi: _cDesk.text,
      foto: _foto,
      tanggal: _tanggal!,
      jam: _jam == null ? '' : '${_dua(_jam!.hour)}:${_dua(_jam!.minute)}',
      mode: _mode,
      alamat: datang ? _cAlamat.text : (s.alamatUsaha.isEmpty ? 'Di tempat penyedia' : s.alamatUsaha),
      lat: datang ? u.lokasiLat : s.lokasiLat,
      lng: datang ? u.lokasiLng : s.lokasiLng,
    );
    if (o == null) {
      showSnack(false, '', _ord.errorMsg.value);
      return;
    }
    Get.off(() => PesananDetailView(orderId: o.id));
    showSnack(true, 'Pesanan terkirim. Penyedia akan menjawab, Anda dapat memantau di sini.', '');
  }

  Widget _kartuPilihan(
      {required bool terpilih,
      required String judul,
      required String sub,
      required VoidCallback onTap}) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: terpilih ? primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: terpilih ? primary : Colors.grey.shade300,
                width: terpilih ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(terpilih ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: terpilih ? primary : AppTheme.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final Color k = AppTheme.kategoriJasaColor(s.kategori);
    final bool khusus = _paket == null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: primary, title: const Text('Pesan Jasa')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            kartu(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  _avatarJasa(s, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.nama,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(AppUtils.labelKategoriJasa(s.kategori),
                            style: TextStyle(fontSize: 12, color: k)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _judulSeksi('1. Pilih layanan'),
            ...s.paket.map((p) => _kartuPilihan(
                  terpilih: _paket?.id == p.id,
                  judul: p.nama,
                  sub: p.labelHarga,
                  onTap: () => setState(() {
                    _paket = p;
                    _jumlah = 1;
                  }),
                )),
            _kartuPilihan(
              terpilih: khusus,
              judul: s.paket.isEmpty ? 'Layanan sesuai kebutuhan' : 'Permintaan lain',
              sub: 'Harga disepakati dengan penyedia (${s.labelTarif})',
              onTap: () => setState(() => _paket = null),
            ),
            if (khusus)
              TextFormField(
                controller: _cLayanan,
                maxLength: 50,
                decoration: const InputDecoration(
                    labelText: 'Apa yang Anda butuhkan?',
                    hintText: 'Contoh: Perbaiki atap bocor'),
                validator: (v) => (_paket == null && (v == null || v.trim().length < 4))
                    ? 'Tulis singkat kebutuhan Anda'
                    : null,
              ),
            if (!khusus && _paket!.harga > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Jumlah ${_paket!.satuan}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _jumlah > 1 ? () => setState(() => _jumlah--) : null,
                  ),
                  Text('$_jumlah',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _jumlah < 99 ? () => setState(() => _jumlah++) : null,
                  ),
                ],
              ),
            ],
            _judulSeksi('2. Jelaskan kebutuhan'),
            TextFormField(
              controller: _cDesk,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                  hintText:
                      'Ceritakan kondisi/pekerjaan yang diminta sejelas mungkin',
                  alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Jelaskan minimal 10 huruf'
                  : null,
            ),
            const SizedBox(height: 4),
            FotoPicker(
              maks: 2,
              label: 'Foto kondisi / contoh (opsional, maks. 2)',
              onChanged: (baru, _) => _foto = baru,
            ),
            _judulSeksi('3. Kapan?'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pilihTanggal,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_tanggal == null
                        ? 'Pilih tanggal'
                        : AppUtils.formatTanggal(_tanggal!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pilihJam,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_jam == null
                        ? 'Jam (opsional)'
                        : '${_dua(_jam!.hour)}:${_dua(_jam!.minute)}'),
                  ),
                ),
              ],
            ),
            if (_infoJamKerja.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_infoJamKerja,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                  'Tanggal yang libur atau di luar hari kerja penyedia tidak bisa dipilih.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
            ),
            _judulSeksi('4. Di mana?'),
            if (s.modeLayanan == 'keduanya')
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Penyedia datang ke rumah',
                        style: TextStyle(fontSize: 12)),
                    selected: _mode == 'datang',
                    onSelected: (_) => setState(() => _mode = 'datang'),
                  ),
                  ChoiceChip(
                    label: const Text('Saya datang ke tempat penyedia',
                        style: TextStyle(fontSize: 12)),
                    selected: _mode == 'tempat',
                    onSelected: (_) => setState(() => _mode = 'tempat'),
                  ),
                ],
              )
            else
              Text(ServiceModel.labelMode(s.modeLayanan),
                  style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            if (_mode == 'datang')
              TextFormField(
                controller: _cAlamat,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Alamat pengerjaan',
                    helperText: 'Diambil dari alamat akun Anda, boleh diubah'),
                validator: (v) => (_mode == 'datang' && (v == null || v.trim().length < 8))
                    ? 'Isi alamat lengkap minimal 8 huruf'
                    : null,
              )
            else
              _barisInfo(Icons.place_outlined,
                  s.alamatUsaha.isEmpty ? 'Lokasi penyedia (lihat peta di halaman jasa)' : s.alamatUsaha),
            const SizedBox(height: 14),
            kartu(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Perkiraan biaya',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                          _estimasi > 0 ? rupiah(_estimasi) : 'Disepakati dengan penyedia',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'Penyedia dapat menerima atau mengajukan penawaran (harga/tanggal). Anda memutuskan setuju atau tidak. Pembayaran langsung ke penyedia setelah pekerjaan selesai — tidak lewat aplikasi.',
                      style: TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3)),
            ],
          ),
          child: Obx(() => SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _ord.isSubmitting.value ? null : _kirim,
                  style: ElevatedButton.styleFrom(backgroundColor: k),
                  child: _ord.isSubmitting.value
                      ? loadingChild()
                      : const Text('Kirim Pesanan',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              )),
        ),
      ),
    );
  }
}

// ============================================================
// KARTU PESANAN (dipakai di Pesanan Saya & Dasbor penyedia)
// ============================================================
class _KartuPesanan extends StatelessWidget {
  final OrderModel o;
  final bool sebagaiPenyedia;
  const _KartuPesanan({required this.o, required this.sebagaiPenyedia});

  @override
  Widget build(BuildContext context) {
    final Color c = OrderModel.warnaStatus(o.status);
    final bool perlu =
        sebagaiPenyedia ? o.perluTindakanPenyedia : o.perluTindakanPemesan;
    final String label = sebagaiPenyedia
        ? OrderModel.labelStatusPenyedia(o.status)
        : OrderModel.labelStatus(o.status);
    final String pihak = sebagaiPenyedia ? o.namaPemesan : o.namaPenyedia;

    return BouncyTap(
      onTap: () => Get.to(() => PesananDetailView(orderId: o.id)),
      child: kartu(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: c.withOpacity(0.12),
              child: Icon(OrderModel.ikonStatus(o.status), color: c, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(o.namaLayanan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.bold)),
                      ),
                      if (perlu)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${sebagaiPenyedia ? 'Pemesan' : 'Penyedia'}: $pihak',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                      '${AppUtils.formatTanggal(o.tanggalAkhir)}${_jamLabel(o.jam)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _pil(label, c),
                    if (o.biayaAkhir > 0) _pil(rupiah(o.biayaAkhir), AppTheme.textSecondary),
                    if (!sebagaiPenyedia && o.status == 'selesai' && !o.sudahDiulas)
                      _pil('Beri ulasan', const Color(0xFFF9A825),
                          ikon: Icons.star_rounded),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Daftar pesanan dengan saringan Aktif / Selesai / Batal
class _DaftarPesanan extends StatefulWidget {
  final RxList<OrderModel> sumber;
  final bool sebagaiPenyedia;
  const _DaftarPesanan({required this.sumber, required this.sebagaiPenyedia});

  @override
  State<_DaftarPesanan> createState() => _DaftarPesananState();
}

class _DaftarPesananState extends State<_DaftarPesanan> {
  String _filter = 'aktif';

  static const _aktif = [
    'menunggu',
    'nego',
    'diterima',
    'dikerjakan',
    'menunggu_konfirmasi'
  ];

  bool _cocok(OrderModel o, String f) {
    if (f == 'aktif') return _aktif.contains(o.status);
    if (f == 'selesai') return o.status == 'selesai';
    return o.status == 'ditolak' || o.status == 'dibatalkan';
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Obx(() {
      final semua = widget.sumber.toList();
      final list = semua.where((o) => _cocok(o, _filter)).toList();
      Widget chip(String f, String label) {
        final int n = semua.where((o) => _cocok(o, f)).length;
        final bool on = _filter == f;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('$label ($n)'),
            selected: on,
            onSelected: (_) => setState(() => _filter = f),
            selectedColor: primary.withOpacity(0.15),
            labelStyle: TextStyle(
                fontSize: 12,
                color: on ? primary : AppTheme.textSecondary,
                fontWeight: on ? FontWeight.w700 : FontWeight.normal),
            showCheckmark: false,
          ),
        );
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              chip('aktif', 'Berjalan'),
              chip('selesai', 'Selesai'),
              chip('batal', 'Batal / Ditolak'),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 40),
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Belum ada pesanan',
                      subtitle: widget.sebagaiPenyedia
                          ? 'Pesanan dari warga akan muncul di sini.'
                          : 'Pesanan jasa yang Anda buat akan muncul di sini.',
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => FadeSlideIn(
                      key: ValueKey(list[i].id),
                      delay: Duration(milliseconds: 40 * (i % 8)),
                      child: _KartuPesanan(
                          o: list[i], sebagaiPenyedia: widget.sebagaiPenyedia),
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

// ============================================================
// PESANAN SAYA (warga sebagai pemesan)
// ============================================================
class PesananSayaView extends StatelessWidget {
  const PesananSayaView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final ord = Get.find<OrderController>();
    final Color primary = AppTheme.primaryColor(auth.role);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text('Pesanan Saya'),
        actions: const [ChatAction()],
      ),
      body: _DaftarPesanan(sumber: ord.keluar, sebagaiPenyedia: false),
    );
  }
}

// ============================================================
// DETAIL PESANAN — alur lengkap dua arah
// ============================================================
class PesananDetailView extends StatefulWidget {
  final String orderId;
  const PesananDetailView({super.key, required this.orderId});

  @override
  State<PesananDetailView> createState() => _PesananDetailViewState();
}

class _PesananDetailViewState extends State<PesananDetailView> {
  final AuthController _auth = Get.find<AuthController>();
  final OrderController _ord = Get.find<OrderController>();
  final ServiceController _svc = Get.find<ServiceController>();
  late final Stream<OrderModel?> _stream;
  Future<ServiceModel?>? _jasaF;

  @override
  void initState() {
    super.initState();
    _stream = _ord.pesananStream(widget.orderId);
  }

  Future<ServiceModel?> _jasa(OrderModel o) =>
      _jasaF ??= _svc.ambilJasa(o.serviceId);

  // ── Hasil aksi ──
  void _hasil(bool ok, String pesan) =>
      showSnack(ok, pesan, _ord.errorMsg.value);

  // ── Dialog: terima / tawar ──
  Future<void> _dialogTerima(OrderModel o) async {
    final cHarga = TextEditingController(
        text: o.estimasiBiaya > 0 ? '${o.estimasiBiaya}' : '');
    final cCatatan = TextEditingController();
    DateTime tgl = o.tanggal;
    final hasil = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Terima Pesanan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Ubah harga atau tanggal bila perlu. Jika berbeda dari permintaan, pemesan harus menyetujui dulu sebelum pesanan diterima.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 10),
                TextField(
                  controller: cHarga,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Harga total (Rp)',
                      helperText: 'Kosongkan bila belum bisa dipastikan'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final awal = tgl.isBefore(DateTime(now.year, now.month, now.day))
                        ? DateTime(now.year, now.month, now.day)
                        : tgl;
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: awal,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 180)),
                    );
                    if (p != null) setD(() => tgl = DateTime(p.year, p.month, p.day));
                  },
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text('Tanggal: ${AppUtils.formatTanggal(tgl)}'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: cCatatan,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan untuk pemesan (opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false), child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Get.back(result: true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (hasil != true) return;
    final int harga = int.tryParse(cHarga.text.trim()) ?? 0;
    final tglBeda = !(tgl.year == o.tanggal.year &&
        tgl.month == o.tanggal.month &&
        tgl.day == o.tanggal.day);
    final ok = await _ord.terima(o,
        hargaBaru: harga > 0 ? harga : null,
        tanggalBaru: tglBeda ? tgl : null,
        catatan: cCatatan.text);
    _hasil(ok, 'Tanggapan terkirim ke pemesan.');
  }

  // ── Dialog: tandai selesai ──
  Future<void> _dialogSelesai(OrderModel o) async {
    final cBiaya = TextEditingController(
        text: o.biayaAkhir > 0 ? '${o.biayaAkhir}' : '');
    final cCatatan = TextEditingController();
    bool lunas = false;
    final hasil = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Tandai Pekerjaan Selesai'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cBiaya,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Biaya akhir (Rp)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pembayaran sudah diterima'),
                  subtitle: const Text('Dibayar langsung (tunai / transfer)',
                      style: TextStyle(fontSize: 11.5)),
                  value: lunas,
                  onChanged: (v) => setD(() => lunas = v),
                ),
                TextField(
                  controller: cCatatan,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan hasil kerja (opsional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false), child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Tandai Selesai')),
          ],
        ),
      ),
    );
    if (hasil != true) return;
    final int biaya = int.tryParse(cBiaya.text.trim()) ?? 0;
    final ok = await _ord.tandaiSelesai(o,
        lunas: lunas,
        biayaAkhir: biaya > 0 ? biaya : null,
        catatan: cCatatan.text);
    _hasil(ok, 'Ditandai selesai. Menunggu konfirmasi pemesan.');
  }

  Future<void> _tolak(OrderModel o) async {
    final alasan = await mintaTeks('Tolak pesanan', 'Alasan (dikirim ke pemesan)',
        minHuruf: 5);
    if (alasan == null) return;
    _hasil(await _ord.tolak(o, alasan), 'Pesanan ditolak.');
  }

  Future<void> _batal(OrderModel o, bool olehPemesan) async {
    final alasan = await mintaTeks('Batalkan pesanan', 'Alasan pembatalan',
        minHuruf: 5);
    if (alasan == null) return;
    _hasil(await _ord.batalkan(o, alasan, olehPemesan: olehPemesan),
        'Pesanan dibatalkan.');
  }

  Future<void> _tolakPenawaran(OrderModel o) async {
    final alasan = await mintaTeks('Tolak penawaran', 'Alasan (opsional, min. 3 huruf)',
        minHuruf: 3);
    if (alasan == null) return;
    _hasil(await _ord.tolakPenawaran(o, alasan: alasan),
        'Penawaran ditolak, pesanan dibatalkan.');
  }

  Future<void> _belumBeres(OrderModel o) async {
    final catatan = await mintaTeks(
        'Belum sesuai', 'Apa yang belum beres? (dikirim ke penyedia)',
        minHuruf: 5);
    if (catatan == null) return;
    _hasil(await _ord.belumBeres(o, catatan),
        'Penyedia diminta menyelesaikan kembali.');
  }

  // ── Dialog: ulasan ──
  Widget _barisAspek(String label, int nilai, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          RatingStars(rating: nilai.toDouble(), size: 24, onChanged: onChanged),
        ],
      ),
    );
  }

  Future<void> _dialogUlasan(OrderModel o) async {
    int rating = 5;
    int kualitas = 5;
    int ketepatan = 5;
    int komunikasi = 5;
    final cKom = TextEditingController();
    final kirim = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Beri Ulasan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o.namaLayanan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                RatingStars(
                    rating: rating.toDouble(),
                    size: 38,
                    onChanged: (v) => setD(() => rating = v)),
                const Divider(height: 22),
                _barisAspek('Kualitas kerja', kualitas, (v) => setD(() => kualitas = v)),
                _barisAspek('Ketepatan waktu', ketepatan, (v) => setD(() => ketepatan = v)),
                _barisAspek('Komunikasi', komunikasi, (v) => setD(() => komunikasi = v)),
                const SizedBox(height: 8),
                TextField(
                  controller: cKom,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                      labelText: 'Ceritakan pengalaman Anda',
                      alignLabelWithHint: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Get.back(result: false), child: const Text('Nanti')),
            ElevatedButton(
                onPressed: () => Get.back(result: true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (kirim != true) return;
    final ok = await _svc.kirimUlasan(o,
        rating: rating,
        aspek: {
          'kualitas': kualitas,
          'ketepatan': ketepatan,
          'komunikasi': komunikasi,
        },
        komentar: cKom.text);
    showSnack(ok, 'Terima kasih! Ulasan Anda membantu warga lain.', _svc.errorMsg.value);
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrderModel?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Pesanan')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final o = snap.data;
        if (o == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Pesanan')),
            body: const EmptyState(
                icon: Icons.search_off,
                title: 'Pesanan tidak ditemukan',
                subtitle: 'Pesanan ini sudah tidak tersedia.'),
          );
        }
        return _isi(o);
      },
    );
  }

  String _peran(OrderModel o) {
    final uid = _auth.currentUser.value?.uid ?? '';
    if (uid == o.uidPenyedia) return 'penyedia';
    if (uid == o.uidPemesan) return 'pemesan';
    return 'lihat';
  }

  Widget _isi(OrderModel o) {
    final String peran = _peran(o);
    final Color c = OrderModel.warnaStatus(o.status);
    final Color primary = AppTheme.primaryColor(_auth.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text('Detail Pesanan'),
        actions: [
          if (peran != 'lihat') const ChatAction(),
          if (peran == 'pemesan' && o.status != 'menunggu')
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'lapor') {
                  final j = await _jasa(o);
                  if (j == null) {
                    showSnack(false, '', 'Profil jasa tidak ditemukan.');
                    return;
                  }
                  await dialogLaporJasa(j, orderId: o.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'lapor', child: Text('Laporkan penyedia')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          _kepalaStatus(o, peran, c),
          if (o.status != 'ditolak' && o.status != 'dibatalkan') _langkah(o, c),
          if (o.status == 'nego') _kartuPenawaran(o, peran),
          _judulSeksi('Pesanan', ikon: Icons.shopping_bag_outlined),
          _kartuLayanan(o),
          _judulSeksi('Jadwal & Lokasi', ikon: Icons.event_outlined),
          _kartuJadwal(o),
          _judulSeksi('Kebutuhan', ikon: Icons.description_outlined),
          _kartuKebutuhan(o),
          _judulSeksi(peran == 'penyedia' ? 'Pemesan' : 'Penyedia',
              ikon: Icons.person_outline),
          _kartuPihak(o, peran),
          if (o.catatanPenyedia.isNotEmpty && o.status != 'menunggu') ...[
            _judulSeksi('Catatan penyedia', ikon: Icons.sticky_note_2_outlined),
            kartu(
                margin: EdgeInsets.zero,
                child: Text(o.catatanPenyedia,
                    style: const TextStyle(fontSize: 13, height: 1.45))),
          ],
          if (o.alasanBatal.isNotEmpty) ...[
            _judulSeksi(
                o.status == 'ditolak' ? 'Alasan ditolak' : 'Alasan dibatalkan',
                ikon: Icons.info_outline),
            kartu(
                margin: EdgeInsets.zero,
                child: Text(
                    '${o.dibatalkanOleh.isEmpty ? '' : '(${o.dibatalkanOleh == 'pemesan' ? 'oleh pemesan' : 'oleh penyedia'}) '}${o.alasanBatal}',
                    style: TextStyle(
                        fontSize: 13, height: 1.45, color: Colors.red.shade800))),
          ],
          if (peran == 'pemesan' && o.status == 'selesai')
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: o.sudahDiulas
                  ? kartu(
                      margin: EdgeInsets.zero,
                      child: const Row(children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Anda sudah memberi ulasan. Terima kasih!')),
                      ]),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _dialogUlasan(o),
                      icon: const Icon(Icons.star_rounded, color: Colors.white),
                      label: const Text('Beri Ulasan',
                          style: TextStyle(color: Colors.white)),
                    ),
            ),
          _judulSeksi('Riwayat', ikon: Icons.history),
          _riwayat(o),
        ],
      ),
      bottomNavigationBar: _bilahAksi(o, peran),
    );
  }

  // ── Kepala status ──
  String _petunjuk(OrderModel o, String peran) {
    switch (o.status) {
      case 'menunggu':
        return peran == 'penyedia'
            ? 'Pesanan baru. Terima, ajukan penawaran, atau tolak.'
            : 'Menunggu penyedia menjawab. Anda bisa membatalkan selama belum dijawab.';
      case 'nego':
        return peran == 'penyedia'
            ? 'Penawaran Anda terkirim. Menunggu persetujuan pemesan.'
            : 'Penyedia mengajukan penawaran. Setujui atau tolak di bawah.';
      case 'diterima':
        return peran == 'penyedia'
            ? 'Pesanan diterima. Mulai kerjakan pada tanggal yang disepakati.'
            : 'Pesanan diterima penyedia. Tunggu hingga hari pengerjaan.';
      case 'dikerjakan':
        return peran == 'penyedia'
            ? 'Tandai selesai setelah pekerjaan tuntas.'
            : 'Pekerjaan sedang dikerjakan penyedia.';
      case 'menunggu_konfirmasi':
        return peran == 'pemesan'
            ? 'Penyedia menandai pekerjaan selesai. Periksa hasilnya lalu konfirmasi.'
            : 'Menunggu pemesan mengonfirmasi hasil pekerjaan.';
      case 'selesai':
        return 'Pesanan selesai.';
      case 'ditolak':
        return 'Penyedia tidak dapat menerima pesanan ini.';
      default:
        return 'Pesanan dibatalkan.';
    }
  }

  Widget _kepalaStatus(OrderModel o, String peran, Color c) {
    final String label = peran == 'penyedia'
        ? OrderModel.labelStatusPenyedia(o.status)
        : OrderModel.labelStatus(o.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(OrderModel.ikonStatus(o.status), color: c, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.bold, color: c)),
                const SizedBox(height: 3),
                Text(_petunjuk(o, peran),
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langkah(OrderModel o, Color c) {
    int idx;
    switch (o.status) {
      case 'menunggu':
      case 'nego':
        idx = 0;
        break;
      case 'diterima':
        idx = 1;
        break;
      case 'dikerjakan':
      case 'menunggu_konfirmasi':
        idx = 2;
        break;
      default:
        idx = 3;
    }
    const nama = ['Dikirim', 'Diterima', 'Dikerjakan', 'Selesai'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: List.generate(nama.length * 2 - 1, (i) {
          if (i.isOdd) {
            final bool lewat = (i ~/ 2) < idx;
            return Expanded(
                child: Container(
                    height: 3, color: lewat ? c : Colors.grey.shade300));
          }
          final int n = i ~/ 2;
          final bool sudah = n <= idx;
          return Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: sudah ? c : Colors.grey.shade300,
                child: Icon(sudah ? Icons.check : Icons.circle,
                    size: sudah ? 14 : 6, color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(nama[n],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: n == idx ? FontWeight.bold : FontWeight.normal,
                      color: sudah ? AppTheme.textPrimary : AppTheme.textSecondary)),
            ],
          );
        }),
      ),
    );
  }

  Widget _kartuPenawaran(OrderModel o, String peran) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(peran == 'pemesan' ? 'Penawaran dari penyedia' : 'Penawaran Anda',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
          const SizedBox(height: 6),
          _barisInfo(Icons.payments_outlined,
              o.hargaFinal == null ? 'Harga disepakati nanti' : rupiah(o.hargaFinal!)),
          _barisInfo(Icons.event_outlined,
              AppUtils.formatTanggal(o.tanggalFinal ?? o.tanggal)),
          if (o.catatanPenyedia.isNotEmpty)
            _barisInfo(Icons.sticky_note_2_outlined, o.catatanPenyedia),
        ],
      ),
    );
  }

  Widget _kartuLayanan(OrderModel o) {
    final bool selisih = o.hargaFinal != null && o.hargaFinal != o.estimasiBiaya;
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.namaLayanan,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (o.harga > 0)
            _barisInfo(Icons.sell_outlined,
                '${rupiah(o.harga)} ${o.satuan} × ${o.jumlah}'),
          if (o.estimasiBiaya > 0)
            _barisInfo(Icons.calculate_outlined,
                'Perkiraan: ${rupiah(o.estimasiBiaya)}'),
          if (o.hargaFinal != null)
            _barisInfo(
                Icons.handshake_outlined,
                '${selisih ? 'Harga kesepakatan' : 'Harga'}: ${rupiah(o.hargaFinal!)}',
                warna: selisih ? const Color(0xFF6A1B9A) : null),
          if (o.estimasiBiaya == 0 && o.hargaFinal == null)
            _barisInfo(Icons.handshake_outlined, 'Harga disepakati langsung dengan penyedia'),
          if (o.status == 'menunggu_konfirmasi' || o.status == 'selesai')
            _barisInfo(
                o.lunas ? Icons.check_circle_outline : Icons.hourglass_empty,
                o.lunas
                    ? 'Pembayaran: sudah diterima penyedia'
                    : 'Pembayaran: belum dicatat lunas (bayar langsung ke penyedia)',
                warna: o.lunas ? Colors.green.shade700 : Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _kartuJadwal(OrderModel o) {
    final bool tglBeda = o.tanggalFinal != null &&
        !(o.tanggalFinal!.year == o.tanggal.year &&
            o.tanggalFinal!.month == o.tanggal.month &&
            o.tanggalFinal!.day == o.tanggal.day);
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barisInfo(Icons.event_outlined,
              '${AppUtils.formatTanggal(o.tanggal)}${_jamLabel(o.jam)}${tglBeda ? '  (diminta)' : ''}'),
          if (tglBeda)
            _barisInfo(Icons.event_available_outlined,
                'Disepakati: ${AppUtils.formatTanggal(o.tanggalFinal!)}',
                warna: const Color(0xFF6A1B9A)),
          _barisInfo(
              o.mode == 'datang' ? Icons.home_outlined : Icons.storefront_outlined,
              o.mode == 'datang'
                  ? 'Penyedia datang ke alamat pemesan'
                  : 'Pemesan datang ke tempat penyedia'),
          if (o.alamat.isNotEmpty) _barisInfo(Icons.place_outlined, o.alamat),
          if (o.lat != 0 || o.lng != 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => bukaUri(uriPeta(o.lat, o.lng)),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Buka di peta'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kartuKebutuhan(OrderModel o) {
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.deskripsi.isEmpty ? '-' : o.deskripsi,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
          if (o.foto.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: o.foto.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => BouncyTap(
                  onTap: () => tampilkanFoto(o.foto[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ImageUtil.image(o.foto[i], width: 110, height: 90),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuPihak(OrderModel o, String peran) {
    final bool penyedia = peran == 'penyedia';
    final String nama = penyedia ? o.namaPemesan : o.namaPenyedia;
    final String uid = penyedia ? o.uidPemesan : o.uidPenyedia;
    final Color primary = AppTheme.primaryColor(_auth.role);

    Widget tombol(IconData i, String label, Color c, VoidCallback onTap) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(i, size: 17, color: c),
            label: Text(label, style: TextStyle(fontSize: 12, color: c)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        );

    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primary.withOpacity(0.12),
                child: Text(AppUtils.inisial(nama),
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
              ),
            ],
          ),
          if (peran != 'lihat') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                tombol(Icons.chat_bubble_outline, 'Chat', primary,
                    () => _bukaChat(uid: uid, nama: nama)),
                const SizedBox(width: 8),
                if (penyedia && o.telpPemesan.isNotEmpty) ...[
                  tombol(Icons.call_outlined, 'Telepon', Colors.blue.shade700,
                      () => bukaUri(uriTelp(o.telpPemesan))),
                  const SizedBox(width: 8),
                  tombol(Icons.phone_in_talk_outlined, 'WhatsApp',
                      const Color(0xFF25D366),
                      () => _bukaWa(o.telpPemesan,
                          'Halo ${o.namaPemesan}, soal pesanan "${o.namaLayanan}" di Talagasari Hub.')),
                ] else if (!penyedia)
                  tombol(Icons.phone_in_talk_outlined, 'WhatsApp',
                      const Color(0xFF25D366), () async {
                    final j = await _jasa(o);
                    if (j == null) {
                      showSnack(false, '', 'Profil jasa tidak ditemukan.');
                      return;
                    }
                    await _bukaWa(j.whatsapp,
                        'Halo ${j.nama}, soal pesanan "${o.namaLayanan}" di Talagasari Hub.');
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _riwayat(OrderModel o) {
    final log = o.log;
    if (log.isEmpty) {
      return const Text('Belum ada riwayat.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary));
    }
    return kartu(
      margin: EdgeInsets.zero,
      child: Column(
        children: log.asMap().entries.map((e) {
          final l = e.value;
          final Color c = OrderModel.warnaStatus(l.status);
          final bool akhir = e.key == log.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Icon(OrderModel.ikonStatus(l.status), size: 18, color: c),
                      if (!akhir)
                        Expanded(
                            child: Container(
                                width: 2, color: Colors.grey.shade300)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: akhir ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(OrderModel.labelStatus(l.status),
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: c)),
                        Text(
                            '${l.oleh.isEmpty ? '' : '${l.oleh} • '}${AppUtils.formatTanggalWaktu(l.waktu)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                        if (l.catatan.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(l.catatan,
                                style: const TextStyle(fontSize: 12.5, height: 1.35)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tombol aksi bawah ──
  Widget? _bilahAksi(OrderModel o, String peran) {
    if (peran == 'lihat') return null;
    Widget? isi;
    final Color k = AppTheme.kategoriJasaColor(o.kategori);

    Widget kosong(String teks) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(teks,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        );

    Widget utama(String label, IconData i, VoidCallback onTap, {Color? warna}) =>
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _ord.isSubmitting.value ? null : onTap,
              icon: Icon(i, color: Colors.white, size: 19),
              label: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: warna ?? k),
            ),
          ),
        );

    Widget sekunder(String label, VoidCallback onTap, {Color? warna}) => Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _ord.isSubmitting.value ? null : onTap,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: warna ?? Colors.red.shade700)),
              child: Text(label,
                  style: TextStyle(
                      color: warna ?? Colors.red.shade700, fontSize: 13)),
            ),
          ),
        );

    const gap = SizedBox(width: 10);

    if (peran == 'penyedia') {
      switch (o.status) {
        case 'menunggu':
          isi = Row(children: [
            sekunder('Tolak', () => _tolak(o)),
            gap,
            utama('Terima / Tawar', Icons.check, () => _dialogTerima(o)),
          ]);
          break;
        case 'nego':
          isi = Row(children: [
            sekunder('Batalkan penawaran', () => _batal(o, false)),
          ]);
          break;
        case 'diterima':
          isi = Row(children: [
            sekunder('Batalkan', () => _batal(o, false)),
            gap,
            utama('Mulai Kerjakan', Icons.build_outlined, () async {
              _hasil(await _ord.mulaiKerjakan(o), 'Pekerjaan dimulai.');
            }),
          ]);
          break;
        case 'dikerjakan':
          isi = Row(children: [
            sekunder('Batalkan', () => _batal(o, false)),
            gap,
            utama('Tandai Selesai', Icons.task_alt, () => _dialogSelesai(o)),
          ]);
          break;
        case 'menunggu_konfirmasi':
          isi = kosong('Menunggu pemesan mengonfirmasi hasil pekerjaan.');
          break;
        default:
          isi = null;
      }
    } else {
      switch (o.status) {
        case 'menunggu':
          isi = Row(children: [
            sekunder('Batalkan Pesanan', () => _batal(o, true)),
          ]);
          break;
        case 'nego':
          isi = Row(children: [
            sekunder('Tolak', () => _tolakPenawaran(o)),
            gap,
            utama('Setujui Penawaran', Icons.check, () async {
              _hasil(await _ord.setujuiPenawaran(o), 'Penawaran disetujui.');
            }, warna: Colors.green.shade700),
          ]);
          break;
        case 'diterima':
          isi = Row(children: [
            sekunder('Batalkan Pesanan', () => _batal(o, true)),
          ]);
          break;
        case 'dikerjakan':
          isi = kosong('Pekerjaan sedang dikerjakan penyedia.');
          break;
        case 'menunggu_konfirmasi':
          isi = Row(children: [
            sekunder('Belum Sesuai', () => _belumBeres(o), warna: Colors.orange.shade800),
            gap,
            utama('Konfirmasi Selesai', Icons.task_alt, () async {
              _hasil(await _ord.konfirmasiSelesai(o),
                  'Pesanan selesai. Silakan beri ulasan.');
            }, warna: Colors.green.shade700),
          ]);
          break;
        default:
          isi = null;
      }
    }
    if (isi == null) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -3)),
          ],
        ),
        child: Obx(() {
          // Obx membaca isSubmitting agar tombol ikut nonaktif saat memproses
          _ord.isSubmitting.value;
          return isi!;
        }),
      ),
    );
  }
}


// ============================================================
// PEMBANTU DASBOR & ADMIN
// ============================================================
const List<String> _hariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// "Sen–Sab 08:00 – 17:00 • Min Libur"
String _ringkasJadwal(Map<int, JamHari> j) {
  if (j.isEmpty) return 'Jam kerja belum diatur (dianggap buka setiap saat)';
  final bagian = <String>[];
  int awal = 1;
  while (awal <= 7) {
    final JamHari a = j[awal] ?? const JamHari(aktif: false);
    int akhir = awal;
    while (akhir < 7) {
      final JamHari b = j[akhir + 1] ?? const JamHari(aktif: false);
      if (b.label != a.label) break;
      akhir++;
    }
    final String hari = awal == akhir
        ? _hariPendek[awal - 1]
        : '${_hariPendek[awal - 1]}–${_hariPendek[akhir - 1]}';
    bagian.add('$hari ${a.label}');
    awal = akhir + 1;
  }
  return bagian.join(' • ');
}

String _teksStatusProfil(String status) {
  switch (status) {
    case 'pending':
      return 'Pengajuan Anda sedang ditinjau Admin desa. Anda akan menerima notifikasi setelah ada keputusan.';
    case 'aktif':
      return 'Profil Anda tampil di pencarian warga dan dapat menerima pesanan.';
    case 'nonaktif':
      return 'Profil Anda disembunyikan dari pencarian. Warga tidak bisa memesan.';
    case 'ditolak':
      return 'Pengajuan ditolak. Perbaiki data sesuai alasan di bawah lalu simpan untuk mengajukan ulang.';
    case 'diblokir':
      return 'Profil Anda diblokir Admin desa. Hubungi Admin bila ada keberatan.';
    default:
      return '';
  }
}

/// Daftar hal yang masih kurang agar profil terlihat meyakinkan
List<String> _kekuranganProfil(ServiceModel s) {
  final k = <String>[];
  if (s.fotoSampul.isEmpty) k.add('Tambahkan foto portofolio');
  if (s.deskripsi.trim().length < 50) k.add('Lengkapi deskripsi (minimal 50 huruf)');
  if (s.tarifMulai <= 0) k.add('Isi tarif mulai');
  if (s.paket.isEmpty) k.add('Buat katalog layanan / paket');
  if (s.jadwal.isEmpty) k.add('Atur jam operasional');
  if (s.whatsapp.trim().length < 9) k.add('Isi nomor WhatsApp');
  if (s.alamatUsaha.trim().isEmpty) k.add('Isi alamat usaha');
  if (s.tag.isEmpty) k.add('Pilih kata kunci keahlian');
  if (!s.ktpOk) k.add('Verifikasi identitas di menu Akun');
  return k;
}

Widget _statKotak(IconData ikon, String nilai, String label, Color c) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(ikon, color: c, size: 20),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(nilai,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    ),
  );
}

// ============================================================
// SALKAR KETERSEDIAAN — Buka / Penuh / Tutup
// ============================================================
Future<void> showDialogKetersediaan(ServiceModel saya) async {
  final ctrl = Get.find<ServiceController>();
  String status = saya.ketersediaan;
  final catatanCtrl = TextEditingController(text: saya.ketersediaanCatatan);
  DateTime? sampai = saya.tutupSampai;

  await Get.dialog(
    StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Status Ketersediaan Jasa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Profil tetap tampil, tetapi warga melihat label status dan tidak bisa memesan saat Penuh atau Tutup.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['buka', 'penuh', 'tutup'].map((k) {
                  final c = ServiceModel.warnaKetersediaan(k);
                  return ChoiceChip(
                    label: Text(ServiceModel.labelKetersediaan(k)),
                    selected: status == k,
                    selectedColor: c.withOpacity(0.18),
                    labelStyle: TextStyle(
                        color: status == k ? c : AppTheme.textSecondary,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setD(() => status = k),
                  );
                }).toList(),
              ),
              if (status != 'buka') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: catatanCtrl,
                  maxLines: 2,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Catatan untuk warga (opsional)',
                    hintText: 'Contoh: Libur Lebaran / antrean penuh minggu ini',
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: sampai ?? now.add(const Duration(days: 3)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 90)),
                    );
                    if (p != null) {
                      setD(() => sampai = DateTime(p.year, p.month, p.day, 23, 59));
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Otomatis buka lagi setelah tanggal (opsional)',
                      prefixIcon: const Icon(Icons.event_available_outlined),
                      suffixIcon: sampai == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setD(() => sampai = null)),
                    ),
                    child: Text(sampai == null
                        ? 'Tidak diatur (buka manual)'
                        : AppUtils.formatTanggal(sampai!)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              Get.back();
              final ok = await ctrl.setKetersediaan(saya.id,
                  status: status, catatan: catatanCtrl.text, tutupSampai: sampai);
              showSnack(
                  ok,
                  'Status jasa kini: ${ServiceModel.labelKetersediaan(status)}.',
                  ctrl.errorMsg.value);
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// TANGGAL LIBUR / TIDAK TERSEDIA
// ============================================================
Future<void> showDialogLibur(ServiceModel saya) async {
  final ctrl = Get.find<ServiceController>();
  final hariIni = DateTime.now();
  final awal = DateTime(hariIni.year, hariIni.month, hariIni.day);
  final List<DateTime> daftar = saya.tanggalLibur
      .where((t) => !DateTime(t.year, t.month, t.day).isBefore(awal))
      .toList()
    ..sort();

  await Get.dialog(
    StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Tanggal Libur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Warga tidak bisa memesan jasa Anda pada tanggal yang ditandai libur. Maksimal 30 tanggal.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              const SizedBox(height: 12),
              if (daftar.isEmpty)
                const Text('Belum ada tanggal libur.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: daftar
                      .map((t) => InputChip(
                            label: Text(AppUtils.formatTanggal(t),
                                style: const TextStyle(fontSize: 12)),
                            onDeleted: () => setD(() => daftar.remove(t)),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: daftar.length >= 30
                    ? null
                    : () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: awal.add(const Duration(days: 1)),
                          firstDate: awal,
                          lastDate: awal.add(const Duration(days: 365)),
                        );
                        if (p != null) {
                          final t = DateTime(p.year, p.month, p.day);
                          if (!daftar.any((e) =>
                              e.year == t.year && e.month == t.month && e.day == t.day)) {
                            setD(() {
                              daftar.add(t);
                              daftar.sort();
                            });
                          }
                        }
                      },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah tanggal'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              Get.back();
              final ok = await ctrl.setTanggalLibur(saya.id, daftar);
              showSnack(ok, 'Tanggal libur disimpan.', ctrl.errorMsg.value);
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// DASBOR PENYEDIA JASA
// ============================================================
class DasborJasaView extends StatelessWidget {
  const DasborJasaView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final svc = Get.find<ServiceController>();
    final ord = Get.find<OrderController>();
    final Color primary = AppTheme.primaryColor(auth.role);

    return Obx(() {
      final saya = svc.punyaSaya.value;
      if (saya == null) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Dasbor Jasa'), backgroundColor: primary),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 72, color: primary.withOpacity(0.35)),
                  const SizedBox(height: 16),
                  const Text('Belum terdaftar sebagai penyedia jasa',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Daftarkan keahlian atau usaha Anda agar warga sekitar bisa memesan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => showFormJasa(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Daftar Sebagai Penyedia Jasa',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final int baru = ord.jumlahBaru;
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: primary,
            title: const Text('Dasbor Jasa'),
            actions: const [ChatAction()],
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                const Tab(text: 'Ringkasan'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pesanan'),
                      if (baru > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('$baru',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primary)),
                        ),
                    ],
                  ),
                ),
                const Tab(text: 'Ulasan'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _DsbRingkasan(saya: saya),
              _DaftarPesanan(sumber: ord.masuk, sebagaiPenyedia: true),
              _DsbUlasan(saya: saya),
            ],
          ),
        ),
      );
    });
  }
}

// ── Tab 1: Ringkasan ─────────────────────────────────────────
class _DsbRingkasan extends StatelessWidget {
  final ServiceModel saya;
  const _DsbRingkasan({required this.saya});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ServiceController>();
    final ord = Get.find<OrderController>();
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    final Color sColor = AppTheme.statusJasaColor(saya.status);
    final bool bisaToggle =
        (saya.status == 'aktif' || saya.status == 'nonaktif') &&
            !saya.dikunci &&
            !saya.diblokir;
    final kurang = _kekuranganProfil(saya);
    final double lengkap = (9 - kurang.length) / 9;
    final String sekarang = saya.statusSekarang();
    final Color wSekarang = ServiceModel.warnaStatusSekarang(sekarang);
    final hariIni = DateTime.now();
    final liburAkan = saya.tanggalLibur
        .where((t) => !DateTime(t.year, t.month, t.day)
            .isBefore(DateTime(hariIni.year, hariIni.month, hariIni.day)))
        .toList()
      ..sort();

    return RefreshIndicator(
      color: primary,
      onRefresh: () => svc.fetchPunyaSaya(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // ── Kartu status profil ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatarJasa(saya, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(saya.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(AppUtils.labelKategoriJasa(saya.kategori),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    StatusBadge(
                        text: AppTheme.labelStatusJasa(saya.status), color: sColor),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_teksStatusProfil(saya.status),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
                if ((saya.status == 'ditolak' ||
                        saya.status == 'diblokir' ||
                        saya.dikunci) &&
                    (saya.alasanPenolakan ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Alasan: ${saya.alasanPenolakan}',
                      style: TextStyle(fontSize: 12.5, color: Colors.red.shade700)),
                ],
                if (saya.peringatan > 0) ...[
                  const SizedBox(height: 8),
                  _pil('${saya.peringatan} dari 3 peringatan Admin',
                      Colors.orange.shade800,
                      ikon: Icons.warning_amber_rounded),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saya.diblokir ? null : () => showFormJasa(existing: saya),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Edit Profil'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => JasaDetailView(service: saya)),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Tampilan Warga'),
                      ),
                    ),
                  ],
                ),
                if (bisaToggle)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: saya.status == 'aktif',
                    activeColor: primary,
                    title: const Text('Tampilkan jasa saya',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Matikan sementara bila sedang sakit atau libur panjang',
                        style: TextStyle(fontSize: 11.5)),
                    onChanged: (v) async {
                      final ok = await svc.toggleAktifNonaktif(saya, v);
                      showSnack(ok, v ? 'Jasa kembali aktif.' : 'Jasa disembunyikan sementara.',
                          svc.errorMsg.value);
                    },
                  ),
              ],
            ),
          ),

          // ── Perlu tindakan ──
          Obx(() {
            final n = ord.jumlahBaru;
            if (n == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: BouncyTap(
                onTap: () => DefaultTabController.of(context).animateTo(1),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('$n pesanan baru menunggu jawaban Anda',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade800)),
                      ),
                      Icon(Icons.chevron_right, color: Colors.red.shade700),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Ketersediaan ──
          if (saya.status == 'aktif') ...[
            _judulSeksi('Ketersediaan', ikon: Icons.event_available_outlined),
            kartu(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _pil(ServiceModel.labelStatusSekarang(sekarang), wSekarang),
                      const SizedBox(width: 8),
                      _pil('Saklar: ${ServiceModel.labelKetersediaan(saya.ketersediaanEfektif)}',
                          ServiceModel.warnaKetersediaan(saya.ketersediaanEfektif)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (saya.penuhOtomatis)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                          'Status "Penuh" diatur otomatis karena jumlah pesanan berjalan sudah mencapai kapasitas. Akan terbuka sendiri setelah ada pesanan selesai.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                    ),
                  if (saya.kapasitasAktif > 0)
                    Obx(() => _barisInfo(Icons.layers_outlined,
                        'Pesanan berjalan: ${ord.jumlahBerjalan} dari kapasitas ${saya.kapasitasAktif}')),
                  _barisInfo(Icons.schedule, _ringkasJadwal(saya.jadwal)),
                  if (liburAkan.isNotEmpty)
                    _barisInfo(Icons.event_busy_outlined,
                        'Libur: ${liburAkan.take(3).map((t) => AppUtils.formatTanggal(t)).join(', ')}${liburAkan.length > 3 ? ' +${liburAkan.length - 3} lagi' : ''}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => showDialogKetersediaan(saya),
                          icon: const Icon(Icons.toggle_on_outlined,
                              size: 18, color: Colors.white),
                          label: const Text('Atur Buka / Tutup',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showDialogLibur(saya),
                          icon: const Icon(Icons.event_busy_outlined, size: 18),
                          label: const Text('Tanggal Libur'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── Statistik ──
          _judulSeksi('Statistik Jasa Saya', ikon: Icons.insights_outlined),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _statKotak(Icons.visibility_outlined, '${saya.dilihat}', 'Dilihat',
                  const Color(0xFF1565C0)),
              _statKotak(Icons.touch_app_outlined, '${saya.dihubungi}', 'Dihubungi',
                  const Color(0xFF6A1B9A)),
              _statKotak(Icons.receipt_long_outlined, '${saya.pesananTotal}',
                  'Pesanan', const Color(0xFFE65100)),
              _statKotak(Icons.task_alt, '${saya.pesananSelesai}', 'Selesai',
                  const Color(0xFF2E7D32)),
              _statKotak(
                  Icons.star_rounded,
                  saya.ratingCount > 0 ? saya.ratingAvg.toStringAsFixed(1) : '-',
                  'Rating',
                  const Color(0xFFF9A825)),
              _statKotak(Icons.rate_review_outlined, '${saya.ratingCount}', 'Ulasan',
                  const Color(0xFF00838F)),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() => kartu(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Perkiraan pendapatan bulan ini',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(rupiah(ord.pendapatanBulanIni),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Text('${ord.selesaiBulanIni} pesanan\nselesai',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              )),

          // ── Kelengkapan profil ──
          _judulSeksi('Kelengkapan Profil', ikon: Icons.checklist_rtl),
          kartu(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: lengkap,
                          minHeight: 8,
                          color: lengkap >= 1 ? const Color(0xFF2E7D32) : primary,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(lengkap * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                if (kurang.isEmpty)
                  const Text('Profil Anda sudah lengkap. Mantap!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32)))
                else ...[
                  const Text('Profil lengkap lebih dipercaya warga. Yang masih kurang:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  ...kurang.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(e, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Ulasan ────────────────────────────────────────────
Future<void> _dialogBalasUlasan(String serviceId, ReviewModel r) async {
  final svc = Get.find<ServiceController>();
  final ctrl = TextEditingController(text: r.balasan);
  final teks = await Get.dialog<String>(
    AlertDialog(
      title: const Text('Balas Ulasan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${r.komentar.isEmpty ? 'Tanpa komentar' : r.komentar}"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            maxLength: 300,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Balasan Anda'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().length < 3) return;
            Get.back(result: ctrl.text.trim());
          },
          child: const Text('Kirim', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (teks == null) return;
  final ok = await svc.balasUlasan(serviceId, r, teks);
  showSnack(ok, 'Balasan terkirim.', svc.errorMsg.value);
}

class _DsbUlasan extends StatelessWidget {
  final ServiceModel saya;
  const _DsbUlasan({required this.saya});

  Widget _batang(int bintang, int jumlah, int total) {
    final double v = total == 0 ? 0 : jumlah / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
              width: 14,
              child: Text('$bintang',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFA726)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 7,
                color: const Color(0xFFFFA726),
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ),
          SizedBox(
              width: 28,
              child: Text('$jumlah',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ServiceController>();
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return StreamBuilder<List<ReviewModel>>(
      stream: svc.reviewsStream(saya.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final semua = (snap.data ?? []).where((r) => r.tampil).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            kartu(
              margin: EdgeInsets.zero,
              child: saya.ratingCount == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'Belum ada ulasan. Ulasan muncul setelah pesanan selesai dan dikonfirmasi warga.',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Text(saya.ratingAvg.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 34, fontWeight: FontWeight.bold)),
                                RatingStars(rating: saya.ratingAvg, size: 15),
                                const SizedBox(height: 2),
                                Text('${saya.ratingCount} ulasan',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  for (int b = 5; b >= 1; b--)
                                    _batang(b, saya.ratingDist[b] ?? 0, saya.ratingCount),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 22),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _pil('Kualitas ${saya.aspekRata('kualitas').toStringAsFixed(1)}',
                                primary, ikon: Icons.workspace_premium_outlined),
                            _pil('Ketepatan ${saya.aspekRata('ketepatan').toStringAsFixed(1)}',
                                primary, ikon: Icons.timer_outlined),
                            _pil('Komunikasi ${saya.aspekRata('komunikasi').toStringAsFixed(1)}',
                                primary, ikon: Icons.forum_outlined),
                          ],
                        ),
                      ],
                    ),
            ),
            _judulSeksi('Ulasan Warga'),
            if (semua.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Belum ada ulasan.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              ...semua.map((r) => kartu(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.namaPengguna,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13.5)),
                            ),
                            Text(AppUtils.formatRelatif(r.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(rating: r.rating.toDouble(), size: 14),
                            if (r.namaLayanan.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r.namaLayanan,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppTheme.textSecondary)),
                              ),
                            ],
                          ],
                        ),
                        if (r.komentar.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(r.komentar,
                              style: const TextStyle(fontSize: 13, height: 1.4)),
                        ],
                        if (r.balasan.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Balasan Anda: ${r.balasan}',
                                style: const TextStyle(fontSize: 12.5, height: 1.4)),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _dialogBalasUlasan(saya.id, r),
                            child: Text(r.balasan.isEmpty ? 'Balas' : 'Ubah balasan'),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }
}

// ============================================================
// TAB ADMIN — antrean verifikasi + semua jasa
// ============================================================
class AdminJasaTab extends StatefulWidget {
  const AdminJasaTab({super.key});

  @override
  State<AdminJasaTab> createState() => _AdminJasaTabState();
}

class _AdminJasaTabState extends State<AdminJasaTab> {
  final ServiceController _svc = Get.find<ServiceController>();
  String _filter = 'pending';
  String _cari = '';
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    await _svc.fetchSemuaAdmin();
    await _svc.fetchPendingVerifikasi();
    if (mounted) setState(() => _memuat = false);
  }

  bool _cocok(ServiceModel s) {
    if (_filter != 'semua' && s.status != _filter) return false;
    final q = _cari.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${s.nama} ${s.namaPenyedia} ${AppUtils.labelKategoriJasa(s.kategori)}'
        .toLowerCase()
        .contains(q);
  }

  Future<void> _setujui(ServiceModel s) async {
    final ok = await _svc.verifikasi(s.id, s.uidPenyedia, setuju: true);
    showSnack(ok, 'Profil ${s.nama} kini aktif.', _svc.errorMsg.value,
        okTitle: 'Disetujui');
    await _svc.fetchSemuaAdmin();
  }

  Future<void> _tolak(ServiceModel s) async {
    final alasan = await pilihAlasanTolak('jasa', judul: 'Tolak ${s.nama}');
    if (alasan == null) return;
    final ok = await _svc.verifikasi(s.id, s.uidPenyedia, setuju: false, alasan: alasan);
    showSnack(ok, 'Pengajuan ditolak dan alasan dicatat di log.', _svc.errorMsg.value);
    await _svc.fetchSemuaAdmin();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    return Obx(() {
      final semua = _svc.semuaAdmin.toList();
      int hitung(String st) => semua.where((s) => s.status == st).length;
      final list = semua.where(_cocok).toList();

      Widget chip(String f, String label, int n) {
        final bool on = _filter == f;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('$label ($n)'),
            selected: on,
            onSelected: (_) => setState(() => _filter = f),
            selectedColor: primary.withOpacity(0.15),
            labelStyle: TextStyle(
                fontSize: 12,
                color: on ? primary : AppTheme.textSecondary,
                fontWeight: on ? FontWeight.w700 : FontWeight.normal),
            showCheckmark: false,
          ),
        );
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: InputDecoration(
                hintText: 'Cari nama usaha / pemilik / kategori',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                chip('pending', 'Antrean', hitung('pending')),
                chip('aktif', 'Aktif', hitung('aktif')),
                chip('nonaktif', 'Nonaktif', hitung('nonaktif')),
                chip('ditolak', 'Ditolak', hitung('ditolak')),
                chip('diblokir', 'Diblokir', hitung('diblokir')),
                chip('semua', 'Semua', semua.length),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: _muat,
              child: (_memuat && semua.isEmpty)
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ])
                  : list.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 40),
                          EmptyState(
                            icon: Icons.verified_user_outlined,
                            title: _filter == 'pending'
                                ? 'Tidak ada pengajuan penyedia jasa'
                                : 'Tidak ada data',
                            subtitle: _filter == 'pending'
                                ? 'Semua pendaftaran penyedia jasa sudah diverifikasi.'
                                : 'Belum ada penyedia jasa pada saringan ini.',
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) => FadeSlideIn(
                            key: ValueKey(list[i].id),
                            delay: Duration(milliseconds: 40 * (i % 8)),
                            child: _kartuAdmin(list[i], primary),
                          ),
                        ),
            ),
          ),
        ],
      );
    });
  }

  Widget _kartuAdmin(ServiceModel s, Color primary) {
    final Color kColor = AppTheme.kategoriJasaColor(s.kategori);
    final Color sColor = AppTheme.statusJasaColor(s.status);
    final bool antre = s.status == 'pending';
    return kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Get.to(() => JasaDetailView(service: s)),
            child: Row(
              children: [
                _avatarJasa(s, radius: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Pemilik: ${s.namaPenyedia}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _pil(AppUtils.labelKategoriJasa(s.kategori), kColor),
                        _pil(AppTheme.labelStatusJasa(s.status), sColor),
                        if (s.unggulan)
                          _pil('Pilihan Desa', const Color(0xFFF9A825),
                              ikon: Icons.star_rounded),
                        if (s.peringatan > 0)
                          _pil('${s.peringatan} peringatan', Colors.orange.shade800),
                      ]),
                    ],
                  ),
                ),
                if (!antre)
                  IconButton(
                    tooltip: 'Kelola',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      await _menuAdminJasa(s);
                      await _svc.fetchSemuaAdmin();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _barisInfo(
              s.ktpOk ? Icons.verified : Icons.warning_amber_rounded,
              s.ktpOk
                  ? 'Identitas pemilik terverifikasi'
                  : 'Identitas pemilik BELUM terverifikasi',
              warna: s.ktpOk ? const Color(0xFF2E7D32) : Colors.orange.shade800),
          _barisInfo(Icons.payments_outlined, s.labelTarif),
          _barisInfo(Icons.near_me_outlined,
              '${ServiceModel.labelModePendek(s.modeLayanan)} • radius ${s.areaKm.toStringAsFixed(s.areaKm % 1 == 0 ? 0 : 1)} km'),
          if (s.alamatUsaha.isNotEmpty) _barisInfo(Icons.place_outlined, s.alamatUsaha),
          _barisInfo(Icons.schedule, _ringkasJadwal(s.jadwal)),
          _barisInfo(Icons.menu_book_outlined,
              '${s.paket.length} paket layanan • pengalaman ${s.pengalamanTahun} tahun'),
          if (s.deskripsi.isNotEmpty)
            Text(s.deskripsi,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
          if ((s.alasanPenolakan ?? '').isNotEmpty && !antre)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Alasan: ${s.alasanPenolakan}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ),
          if (antre) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tolak(s),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Tolak', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _setujui(s),
                    icon: const Icon(Icons.verified, size: 16, color: Colors.white),
                    label: const Text('Setujui', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
