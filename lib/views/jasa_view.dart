// ============================================================
// jasa_view.dart — TabJasaView + JasaDetailView
// ============================================================

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import 'chat_view.dart';

// ============================================================
// tab_jasa_view.dart
// Modul Direktori Jasa Lokal Berbasis Lokasi (Bab 4.4.6)
// - Peta OpenStreetMap (gratis, tanpa API key) dengan pin per kategori (di atas)
// - Filter 6 kategori + daftar terurut jarak terdekat (di bawah)
// - Banner: daftar jadi penyedia jasa / kelola profil jasa saya
// ============================================================

class TabJasaView extends StatefulWidget {
  const TabJasaView({super.key});

  @override
  State<TabJasaView> createState() => _TabJasaViewState();
}

class _TabJasaViewState extends State<TabJasaView> {
  final AuthController _authCtrl = Get.find<AuthController>();
  final ServiceController _serviceCtrl = Get.find<ServiceController>();
  final MapController _mapCtrl = MapController();

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  /// Warna pin per kategori (memakai hue yang sama dengan AppUtils).
  Color _warnaPin(String kategori) =>
      HSVColor.fromAHSV(1, AppUtils.hueKategoriJasa(kategori), 0.85, 0.9)
          .toColor();

  /// Info singkat saat pin diketuk (pengganti InfoWindow Google Maps).
  void _tampilkanInfo(ServiceModel s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            backgroundColor: _warnaPin(s.kategori),
            child: const Icon(Icons.place, color: Colors.white),
          ),
          title: Text(s.namaPenyedia,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${AppUtils.labelKategoriJasa(s.kategori)} • ${AppUtils.formatJarakKm(s.jarakKm)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(sheetCtx);
            Get.to(() => JasaDetailView(service: s));
          },
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(List<ServiceModel> list) {
    return list
        .map((s) => Marker(
              point: LatLng(s.lokasiLat, s.lokasiLng),
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => _tampilkanInfo(s),
                child: Icon(Icons.location_on,
                    size: 40, color: _warnaPin(s.kategori)),
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _authCtrl.currentUser.value;
      final String role = user?.role ?? 'warga';
      final Color primaryColor = AppTheme.primaryColor(role);
      final LatLng posisiSaya = LatLng(
        user?.lokasiLat ?? -6.239265,
        user?.lokasiLng ?? 106.530200,
      );

      // Akses Rx di dalam Obx agar UI reaktif
      final bool loading = _serviceCtrl.isLoading.value;
      final String filter = _serviceCtrl.filterKategori.value;
      final list = _serviceCtrl.daftarDenganJarak;
      final saya = _serviceCtrl.punyaSaya.value;

      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: const Text('Cari Jasa Lokal'),
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.white),
              tooltip: 'Perbarui lokasi saya',
              onPressed: () async {
                await _authCtrl.updateLokasiOtomatis();
                final u = _authCtrl.currentUser.value;
                if (u != null) {
                  _mapCtrl.move(LatLng(u.lokasiLat, u.lokasiLng),
                      _mapCtrl.camera.zoom);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _serviceCtrl.fetchAktif();
                _serviceCtrl.fetchPunyaSaya();
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await _serviceCtrl.fetchAktif();
            await _serviceCtrl.fetchPunyaSaya();
          },
          child: CustomScrollView(
            slivers: [
              // ── Peta ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
                  child: FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: posisiSaya,
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
                      MarkerLayer(markers: _buildMarkers(list)),
                      // Titik lokasi saya (pengganti myLocationEnabled)
                      MarkerLayer(markers: [
                        Marker(
                          point: posisiSaya,
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
                ),
              ),

              // ── Banner profil jasa saya / ajakan mendaftar ──
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  child: _buildBannerSaya(saya, primaryColor),
                ),
              ),

              // ── Filter kategori ──
              SliverToBoxAdapter(child: _buildFilterChips(filter, primaryColor)),

              // ── Daftar ──
              if (loading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const ShimmerCard(),
                    childCount: 3,
                  ),
                )
              else if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: EmptyState(
                      icon: Icons.handyman_outlined,
                      title: 'Belum ada penyedia jasa',
                      subtitle:
                          'Belum ada penyedia jasa aktif di kategori ini. Jadilah yang pertama mendaftar!',
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FadeSlideIn(
                      key: ValueKey(list[i].id),
                      delay: Duration(milliseconds: 60 * (i % 8)),
                      child: _buildJasaCard(list[i], primaryColor),
                    ),
                    childCount: list.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // Banner: daftar / kelola profil jasa milik saya
  // ─────────────────────────────────────────────────────────
  Widget _buildBannerSaya(ServiceModel? saya, Color primaryColor) {
    if (saya == null) {
      return BouncyTap(
        onTap: _showFormJasa,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.gradient(_authCtrl.role),
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
                    Text('Punya keahlian?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Daftar jadi penyedia jasa & jangkau warga sekitar',
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
    final bool aktif = saya.status == 'aktif';
    final bool bisaToggle = saya.status == 'aktif' || saya.status == 'nonaktif';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
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
              Icon(AppTheme.kategoriJasaIcon(saya.kategori),
                  color: AppTheme.kategoriJasaColor(saya.kategori)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profil Jasa Saya',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(AppUtils.labelKategoriJasa(saya.kategori),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(text: AppTheme.labelStatusJasa(saya.status), color: sColor),
            ],
          ),
          if (saya.status == 'ditolak' &&
              (saya.alasanPenolakan ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Alasan: ${saya.alasanPenolakan}',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ],
          if (saya.ratingCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                RatingStars(rating: saya.ratingAvg, size: 15),
                const SizedBox(width: 6),
                Text('${saya.ratingAvg.toStringAsFixed(1)} (${saya.ratingCount} ulasan)',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showFormJasa(existing: saya),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profil'),
                ),
              ),
              if (bisaToggle) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await _serviceCtrl.toggleAktifNonaktif(
                          saya.id, !aktif);
                      Get.snackbar(
                        ok ? 'Berhasil' : 'Gagal',
                        ok
                            ? (aktif
                                ? 'Profil dinonaktifkan sementara.'
                                : 'Profil kembali aktif.')
                            : _serviceCtrl.errorMsg.value,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: ok
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        colorText: Colors.white,
                        margin: const EdgeInsets.all(16),
                        borderRadius: 12,
                      );
                    },
                    icon: Icon(aktif ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        size: 16, color: Colors.white),
                    label: Text(aktif ? 'Nonaktifkan' : 'Aktifkan',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: aktif ? Colors.orange.shade700 : primaryColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Filter kategori (Semua + 6 kategori)
  // ─────────────────────────────────────────────────────────
  Widget _buildFilterChips(String aktif, Color primaryColor) {
    final filters = <Map<String, String>>[
      {'value': 'semua', 'label': 'Semua'},
      ...AppUtils.daftarKategoriJasa,
    ];
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((f) {
            final bool isActive = aktif == f['value'];
            final Color c = f['value'] == 'semua'
                ? primaryColor
                : AppTheme.kategoriJasaColor(f['value']!);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f['label']!),
                selected: isActive,
                onSelected: (_) => _serviceCtrl.setFilter(f['value']!),
                selectedColor: c.withOpacity(0.15),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isActive ? c : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(color: isActive ? c : Colors.grey.shade300),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Kartu penyedia jasa
  // ─────────────────────────────────────────────────────────
  Widget _buildJasaCard(ServiceModel s, Color primaryColor) {
    final Color kColor = AppTheme.kategoriJasaColor(s.kategori);
    final bool milikSaya = s.isMilikSaya(_authCtrl.currentUser.value?.uid ?? '');

    return BouncyTap(
      onTap: () => Get.to(() => JasaDetailView(service: s)),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: kColor.withOpacity(0.12),
                backgroundImage:
                    s.fotoUrl.isNotEmpty ? NetworkImage(s.fotoUrl) : null,
                child: s.fotoUrl.isEmpty
                    ? Icon(AppTheme.kategoriJasaIcon(s.kategori), color: kColor, size: 26)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.namaPenyedia,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        if (milikSaya) ...[
                          const SizedBox(width: 6),
                          const StatusBadge(text: 'Anda', color: AppTheme.warnaWarga),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(
                        text: AppUtils.labelKategoriJasa(s.kategori), color: kColor),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (s.ratingCount > 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFFFA726)),
                          const SizedBox(width: 2),
                          Text(s.ratingAvg.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(' (${s.ratingCount})',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 10),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Text('Belum ada ulasan',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.textSecondary)),
                          ),
                        const Icon(Icons.place_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(AppUtils.formatJarakKm(s.jarakKm),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // FORM: Daftar / Edit profil jasa (bottom sheet)
  // ─────────────────────────────────────────────────────────
  void _showFormJasa({ServiceModel? existing}) {
    final formKey = GlobalKey<FormState>();
    final deskCtrl = TextEditingController(text: existing?.deskripsi ?? '');
    String kategori = existing?.kategori ?? AppUtils.daftarKategoriJasa.first['value']!;
    final String kategoriAwal = kategori;
    final List<File> fotoBaru = [];
    final picker = ImagePicker();
    final primaryColor = AppTheme.primaryColor(_authCtrl.role);

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    existing == null ? 'Daftar Penyedia Jasa' : 'Edit Profil Jasa',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    existing == null
                        ? 'Pengajuan akan diverifikasi Admin desa sebelum tampil ke warga.'
                        : 'Mengganti kategori akan memicu verifikasi ulang oleh Admin.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: kategori,
                    decoration: const InputDecoration(labelText: 'Kategori Jasa'),
                    items: AppUtils.daftarKategoriJasa
                        .map((k) => DropdownMenuItem(
                              value: k['value'],
                              child: Text(k['label']!),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => kategori = v ?? kategori),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: deskCtrl,
                    maxLines: 4,
                    validator: (v) =>
                        (v == null || v.trim().length < 10)
                            ? 'Deskripsi minimal 10 karakter'
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Layanan',
                      hintText: 'Jelaskan keahlian, pengalaman, dan layanan Anda',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Foto Portofolio',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        BouncyTap(
                          onTap: () async {
                            final picked = await picker.pickMultiImage(imageQuality: 70);
                            if (picked.isNotEmpty) {
                              setSheet(() {
                                fotoBaru.addAll(picked.map((x) => File(x.path)));
                                if (fotoBaru.length > 6) {
                                  fotoBaru.removeRange(6, fotoBaru.length);
                                }
                              });
                            }
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: primaryColor.withOpacity(0.4)),
                            ),
                            child: Icon(Icons.add_photo_alternate_outlined,
                                color: primaryColor),
                          ),
                        ),
                        ...fotoBaru.asMap().entries.map((e) => Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: FileImage(e.value),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => setSheet(() => fotoBaru.removeAt(e.key)),
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Maksimal 6 foto. Lokasi diambil dari GPS akun Anda.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 18),
                  Obx(() => SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _serviceCtrl.isSubmitting.value
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  bool ok;
                                  if (existing == null) {
                                    ok = await _serviceCtrl.daftarJasa(
                                      kategori: kategori,
                                      deskripsi: deskCtrl.text,
                                      fotoPortofolio: fotoBaru,
                                    );
                                  } else {
                                    ok = await _serviceCtrl.editJasa(
                                      docId: existing.id,
                                      kategori: kategori,
                                      deskripsi: deskCtrl.text,
                                      fotoBaru: fotoBaru,
                                      kategoriBerubah: kategori != kategoriAwal,
                                    );
                                  }
                                  if (ok) Get.back();
                                  Get.snackbar(
                                    ok ? 'Berhasil ✅' : 'Gagal',
                                    ok
                                        ? (existing == null
                                            ? 'Pengajuan terkirim. Menunggu verifikasi Admin.'
                                            : 'Profil jasa diperbarui.')
                                        : _serviceCtrl.errorMsg.value,
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: ok
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    colorText: Colors.white,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 12,
                                  );
                                },
                          child: _serviceCtrl.isSubmitting.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(existing == null ? 'Kirim Pengajuan' : 'Simpan Perubahan'),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}


// ============================================================
// jasa_detail_view.dart
// Detail penyedia jasa (Bab 4.4.7): nama, kategori, deskripsi,
// galeri portofolio, jarak, ulasan realtime, tombol "Mulai Chat".
// ============================================================

class JasaDetailView extends StatefulWidget {
  final ServiceModel service;
  const JasaDetailView({super.key, required this.service});

  @override
  State<JasaDetailView> createState() => _JasaDetailViewState();
}

class _JasaDetailViewState extends State<JasaDetailView> {
  final AuthController _authCtrl = Get.find<AuthController>();
  final ServiceController _serviceCtrl = Get.find<ServiceController>();
  final ChatController _chatCtrl = Get.find<ChatController>();
  bool _membukaChat = false;

  ServiceModel get s => widget.service;

  bool get _milikSaya => s.isMilikSaya(_authCtrl.currentUser.value?.uid ?? '');

  Future<void> _mulaiChat() async {
    if (_membukaChat) return;
    setState(() => _membukaChat = true);
    try {
      final room = await _chatCtrl.bukaAtauBuatRoom(
        otherUid: s.uidPenyedia,
        otherNama: s.namaPenyedia,
        otherFoto: s.fotoUrl,
      );
      final me = _authCtrl.currentUser.value!;
      Get.to(() => ChatRoomView(
            roomId: room.id,
            otherUid: s.uidPenyedia,
            namaLawan: room.namaLawan(me.uid),
            fotoLawan: room.fotoLawan(me.uid),
          ));
    } catch (e) {
      Get.snackbar('Gagal', 'Tidak dapat membuka obrolan: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12);
    } finally {
      if (mounted) setState(() => _membukaChat = false);
    }
  }

  void _lihatFoto(String url) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator())),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogUlasan() {
    int rating = 5;
    final komCtrl = TextEditingController();
    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Tulis Ulasan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingStars(
                rating: rating.toDouble(),
                size: 34,
                onChanged: (v) => setD(() => rating = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: komCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ceritakan pengalaman Anda...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                final ok = await _serviceCtrl.tambahReview(s.id,
                    rating: rating, komentar: komCtrl.text);
                Get.snackbar(
                  ok ? 'Terima kasih ⭐' : 'Gagal',
                  ok ? 'Ulasan Anda terkirim.' : _serviceCtrl.errorMsg.value,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor:
                      ok ? Colors.green.shade700 : Colors.red.shade700,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                );
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color kColor = AppTheme.kategoriJasaColor(s.kategori);
    final Color primaryColor = AppTheme.primaryColor(_authCtrl.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: kColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kColor, kColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      Hero(
                        tag: 'jasa_${s.id}',
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: s.fotoUrl.isNotEmpty
                              ? NetworkImage(s.fotoUrl)
                              : null,
                          child: s.fotoUrl.isEmpty
                              ? Icon(AppTheme.kategoriJasaIcon(s.kategori),
                                  size: 40, color: kColor)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(s.namaPenyedia,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori + jarak + rating
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(
                            text: AppUtils.labelKategoriJasa(s.kategori),
                            color: kColor,
                            fontSize: 12),
                        if (s.jarakKm != null)
                          StatusBadge(
                              text: '📍 ${AppUtils.formatJarakKm(s.jarakKm)} dari Anda',
                              color: AppTheme.textSecondary,
                              fontSize: 12),
                        if (s.ratingCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RatingStars(rating: s.ratingAvg, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                  '${s.ratingAvg.toStringAsFixed(1)} (${s.ratingCount})',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Tentang Layanan',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(s.deskripsi,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppTheme.textPrimary)),

                    // Galeri portofolio
                    if (s.fotoPortofolio.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Portofolio',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: s.fotoPortofolio.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => BouncyTap(
                            onTap: () => _lihatFoto(s.fotoPortofolio[i]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: s.fotoPortofolio[i],
                                width: 130,
                                height: 110,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ShimmerBox(
                                    width: 130, height: 110),
                                errorWidget: (_, __, ___) => Container(
                                  width: 130,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Ulasan
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Ulasan',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        if (!_milikSaya)
                          TextButton.icon(
                            onPressed: _dialogUlasan,
                            icon: const Icon(Icons.rate_review_outlined, size: 16),
                            label: const Text('Tulis Ulasan'),
                          ),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: _serviceCtrl.reviewsStream(s.id),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: ShimmerBox(height: 48),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Belum ada ulasan.',
                                style: TextStyle(
                                    fontSize: 13, color: AppTheme.textSecondary)),
                          );
                        }
                        return Column(
                          children: docs.map((d) {
                            final r = ReviewModel.fromFirestore(d);
                            return FadeSlideIn(
                              key: ValueKey(r.id),
                              dy: 10,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                primaryColor.withOpacity(0.12),
                                            child: Text(
                                              AppUtils.inisial(r.namaPengguna),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: primaryColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(r.namaPengguna,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                          ),
                                          Text(AppUtils.formatRelatif(r.createdAt),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      RatingStars(
                                          rating: r.rating.toDouble(), size: 14),
                                      if (r.komentar.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(r.komentar,
                                            style: const TextStyle(
                                                fontSize: 13, height: 1.4)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Tombol chat melayang di bawah
      bottomNavigationBar: _milikSaya
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _membukaChat ? null : _mulaiChat,
                    icon: _membukaChat
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    label: const Text('Mulai Chat',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: kColor),
                  ),
                ),
              ),
            ),
    );
  }
}
