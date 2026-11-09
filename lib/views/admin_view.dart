// ============================================================
// admin_view.dart — TabManageView + TabPendingView
// ============================================================

import 'hapus_info.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/village_controller.dart' show FotoProfilController;
import '../controllers/complaint_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';
import 'admin_tools_view.dart' show LaporanJasaTab, FotoStaffTab, LowonganStaffTab, HapusStaffTab;
import 'complaint_view.dart';
import 'info_form_view.dart';
import 'jasa_view.dart' show AdminJasaTab;
import 'lapak_view.dart' show LapakStaffTab;
import 'moderasi_view.dart' show ModerasiTab;
import 'info_saya_view.dart' show RevisiInfoTab;
import 'verification_view.dart';

// ============================================================
// tab_manage_view.dart - TAHAP 2 FINAL
// Kelola Pengajuan: Admin review warga, Kades review pending
// ============================================================

class _MenuKelola {
  final String judul;
  final String ket;
  final IconData ikon;
  final Color warna;
  final int jumlah;
  final Widget isi;
  _MenuKelola(this.judul, this.ket, this.ikon, this.warna, this.jumlah, this.isi);
}

class TabManageView extends StatefulWidget {
  const TabManageView({super.key});

  @override
  State<TabManageView> createState() => _TabManageViewState();
}

class _TabManageViewState extends State<TabManageView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<DataController>()) Get.put(DataController());
      Get.find<DataController>().fetchPendingList();
      Get.find<LowonganController>().fetchAntrian();
    });
    _mulaiDengar();
  }

  // jumlah antrean yang datang dari Firestore (live)
  int _nRevisi = 0, _nLapKonten = 0, _nLapJasa = 0, _nHapusInfo = 0, _nHapusLapak = 0;
  final List<StreamSubscription> _langganan = [];

  @override
  void dispose() {
    for (final s in _langganan) {
      s.cancel();
    }
    super.dispose();
  }

  void _dengar(Query<Map<String, dynamic>> q, void Function(int) set) {
    _langganan.add(q.limit(99).snapshots().listen((s) {
      if (mounted) setState(() => set(s.size));
    }, onError: (_) {}));
  }

  void _mulaiDengar() {
    final db = FirebaseFirestore.instance;
    _dengar(db.collection('announcements').where('revisi_status', whereIn: ['diajukan', 'menunggu_kades']),
        (n) => _nRevisi = n);
    _dengar(db.collection('announcements').where('hapus_status', isEqualTo: 'diajukan'), (n) => _nHapusInfo = n);
    if (Get.find<AuthController>().role == 'admin') {
      _dengar(db.collection('laporan_konten').where('status', isEqualTo: 'baru'), (n) => _nLapKonten = n);
      _dengar(db.collection('lapak_umkm').where('hapus_status', isEqualTo: 'diajukan'), (n) => _nHapusLapak = n);
      _dengar(db.collection('laporan_jasa').where('status', isEqualTo: 'baru'), (n) => _nLapJasa = n);
    }
  }

  void _buka(String judul, Color warna, Widget isi) {
    Get.to(() => Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: Text(judul), backgroundColor: warna),
          body: isi,
        ));
  }

  Widget _kartuMenu(_MenuKelola m, Color warna) {
    return InkWell(
      onTap: () => _buka(m.judul, warna, m.isi),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.jumlah > 0 ? m.warna : Colors.grey.shade200, width: m.jumlah > 0 ? 1.6 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: m.warna.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(m.ikon, color: m.warna, size: 22),
            ),
            const Spacer(),
            if (m.jumlah > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(12)),
                child: Text(m.jumlah > 99 ? '99+' : '${m.jumlah}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade400),
          ]),
          const SizedBox(height: 8),
          Text(m.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Expanded(
            child: Text(m.ket,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3)),
          ),
        ]),
      ),
    );
  }

  Widget _bagian(String judul, String ket, List<_MenuKelola> items, Color warna) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(ket, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [for (final m in items) _kartuMenu(m, warna)],
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final DataController dataCtrl = Get.find<DataController>();
    final ServiceController serviceCtrl = Get.find<ServiceController>();

    return Obx(() {
      final String role = authCtrl.role;
      final Color primaryColor = AppTheme.primaryColor(role);
      final bool isAdmin = role == 'admin';
      final ComplaintController cmpCtrl = Get.find<ComplaintController>();
      final lowCtrl = Get.find<LowonganController>();
      final infoList = _buildInfoList(dataCtrl, primaryColor, role);

      final int nInfo = dataCtrl.pendingList.length;
      final int nJasa = serviceCtrl.pendingVerifikasi.length;
      final int nAduan = cmpCtrl.antrian.length;
      final int nKtp = cmpCtrl.ktpMenunggu.length;
      final int nLow = lowCtrl.antrian.length;
      final int nFoto = Get.find<FotoProfilController>().antrian.length;
      final int nHapus = serviceCtrl.antrianHapus.length + lowCtrl.antrianHapus.length;

      final List<_MenuKelola> tinjau = isAdmin
          ? [
              _MenuKelola('Info baru', 'Info dari warga yang menunggu disetujui tayang.', Icons.campaign_outlined,
                  Colors.green.shade700, nInfo, infoList),
              _MenuKelola('Perubahan info', 'Warga mengubah info yang sudah tayang. Bandingkan lalu setujui.',
                  Icons.edit_note_outlined, Colors.teal.shade700, _nRevisi, const RevisiInfoTab()),
              _MenuKelola('Hapus info', 'Warga minta info miliknya dihapus. Baca alasannya, lalu setujui atau tolak.',
                  Icons.delete_sweep_outlined, Colors.red.shade700, _nHapusInfo, const HapusInfoTab()),
              _MenuKelola('Pengaduan', 'Pengaduan warga. Saring, proses, atau teruskan ke Kades.',
                  Icons.report_problem_outlined, Colors.orange.shade800, nAduan, const PengaduanStaffTab()),
              _MenuKelola('Verifikasi KTP', 'Cocokkan data dan foto KTP warga.', Icons.badge_outlined,
                  Colors.indigo, nKtp, const KtpStaffTab()),
              _MenuKelola('Verifikasi jasa', 'Penyedia jasa baru yang minta disetujui.', Icons.handyman_outlined,
                  Colors.brown, nJasa, const AdminJasaTab()),
              _MenuKelola('Lowongan', 'Lowongan Butuh Pekerja yang menunggu tayang.', Icons.work_outline,
                  Colors.blue.shade700, nLow, const LowonganStaffTab()),
              _MenuKelola('Foto profil', 'Foto profil baru yang perlu dicek.', Icons.account_circle_outlined,
                  Colors.purple, nFoto, const FotoStaffTab()),
              _MenuKelola('Permintaan hapus', 'Pemilik jasa atau lowongan minta datanya dihapus.',
                  Icons.delete_outline, Colors.red.shade700, nHapus, const HapusStaffTab()),
            ]
          : [
              _MenuKelola('Info menunggu Kades', 'Info yang perlu persetujuan Kepala Desa.', Icons.campaign_outlined,
                  Colors.green.shade700, nInfo, infoList),
              _MenuKelola('Perubahan info', 'Perubahan info kategori sensitif.', Icons.edit_note_outlined,
                  Colors.teal.shade700, _nRevisi, const RevisiInfoTab()),
              _MenuKelola('Hapus info', 'Permintaan hapus info kategori sensitif.',
                  Icons.delete_sweep_outlined, Colors.red.shade700, _nHapusInfo, const HapusInfoTab()),
              _MenuKelola('Pengaduan berat', 'Pengaduan keamanan atau kekerasan yang diteruskan Admin.',
                  Icons.report_problem_outlined, Colors.orange.shade800, nAduan, const PengaduanStaffTab()),
            ];
      final List<_MenuKelola> lapor = isAdmin
          ? [
              _MenuKelola('Laporan & blokir', 'Laporan konten dan akun warga. Bekukan akun bila melanggar.',
                  Icons.shield_outlined, Colors.red.shade700, _nLapKonten, const ModerasiTab()),
              _MenuKelola('Laporan jasa', 'Warga melaporkan penyedia jasa.', Icons.flag_outlined,
                  Colors.deepOrange, _nLapJasa, const LaporanJasaTab()),
              _MenuKelola('Lapak UMKM', 'Pantau lapak. Sembunyikan bila melanggar aturan.', Icons.storefront_outlined,
                  Colors.pink.shade700, _nHapusLapak, const LapakStaffTab()),
            ]
          : <_MenuKelola>[];

      final int total = tinjau.fold<int>(0, (a, m) => a + m.jumlah) + lapor.fold<int>(0, (a, m) => a + m.jumlah);

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(role == 'kades' ? 'Persetujuan Kades' : 'Kelola Desa'),
          backgroundColor: primaryColor,
        ),
        body: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await dataCtrl.fetchPendingList();
            await lowCtrl.fetchAntrian();
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: total > 0
                        ? [Colors.orange.shade700, Colors.deepOrange.shade400]
                        : [Colors.green.shade700, Colors.green.shade500]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(total > 0 ? Icons.notifications_active : Icons.verified, color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(total > 0 ? '$total hal perlu tindakan Anda' : 'Semua beres, tidak ada antrean',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                        total > 0
                            ? 'Kotak bertanda angka merah di bawah berisi pengajuan baru. Tarik ke bawah untuk memuat ulang.'
                            : 'Pengajuan baru dari warga akan muncul di sini dengan angka merah dan notifikasi.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
                  ]),
                ),
              ]),
            ),
            _bagian('Perlu ditinjau', 'Ketuk kotak untuk membuka. Angka merah = jumlah yang menunggu.', tinjau, primaryColor),
            if (lapor.isNotEmpty) _bagian('Laporan dan keamanan', 'Penegakan Aturan Komunitas.', lapor, primaryColor),
          ]),
        ),
      );
    });
  }

  Widget _buildInfoList(
      DataController dataCtrl, Color primaryColor, String role) {
    return Obx(() {
      final list = dataCtrl.pendingList;

      if (list.isEmpty) {
        return _buildKosong(primaryColor, role);
      }

      return RefreshIndicator(
        color: primaryColor,
        onRefresh: () => dataCtrl.fetchPendingList(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, index) => FadeSlideIn(
            key: ValueKey(list[index].id),
            delay: Duration(milliseconds: 50 * (index % 8)),
            child: _buildPendingCard(
              context,
              list[index],
              primaryColor,
              role,
              dataCtrl,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildKosong(Color primaryColor, String role) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 72, color: primaryColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Tidak ada pengajuan masuk',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              role == 'kades'
                  ? 'Belum ada informasi sensitif yang menunggu persetujuan Anda.'
                  : 'Semua pengajuan dari warga sudah diproses.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(
      BuildContext context,
      NewsModel news,
      Color primaryColor,
      String role,
      DataController dataCtrl,
      ) {
    final bool isSensitif = AppUtils.isKategoriSensitif(news.kategori);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isSensitif ? Colors.red : Colors.blue)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    NewsModel.labelKategori(news.kategori),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSensitif ? Colors.red.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isSensitif) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚠️ Butuh ACC Kades',
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade800),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  AppUtils.formatRelatif(news.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Judul
            Text(news.judul,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),

            if (news.semuaFoto.isNotEmpty) ...[
              fotoFull(news.semuaFoto.first, maksTinggi: 320),
              const SizedBox(height: 8),
            ],
            // Isi preview
            Text(news.isi,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),

            // Tombol lihat selengkapnya
            GestureDetector(
              onTap: () => _showDetail(context, news),
              child: Text('Lihat selengkapnya →',
                  style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                      fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 20),

            // Tombol Aksi
            if (role == 'admin' && news.status == 'pending_kades')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_outlined,
                        size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Menunggu keputusan Kepala Desa. Admin hanya dapat melihat.',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              )
            else
            Row(
              children: [
                // Tombol Tolak
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDialogTolak(context, news, dataCtrl),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Tolak',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Tombol Setujui / Kirim ke Kades
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showDialogSetujui(context, news, dataCtrl, role),
                    icon: Icon(
                      role == 'admin' && isSensitif
                          ? Icons.forward
                          : Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      role == 'admin' && isSensitif
                          ? 'Kirim ke Kades'
                          : 'Setujui & Publish',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Detail bottom sheet
  void _showDetail(BuildContext context, NewsModel news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: ctrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(NewsModel.labelKategori(news.kategori),
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text(news.judul,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(AppUtils.formatTanggalWaktu(news.createdAt),
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                if (news.berlakuSampai != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Berlaku sampai ${AppUtils.formatTanggal(news.berlakuSampai!)}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                const Divider(height: 24),
                if (news.semuaFoto.isNotEmpty) ...[
                  for (final f in news.semuaFoto) ...[fotoFull(f, maksTinggi: 600), const SizedBox(height: 8)],
                  const SizedBox(height: 14),
                ],
                Text(news.isi,
                    style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        height: 1.6)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dialog Setujui
  void _showDialogSetujui(BuildContext context, NewsModel news,
      DataController dataCtrl, String role) {
    final bool isSensitif = AppUtils.isKategoriSensitif(news.kategori);
    final bool kirimKeKades = role == 'admin' && isSensitif;

    DateTime? berlaku = news.berlakuSampai;
    Get.dialog(
      AlertDialog(
        title: Text(kirimKeKades ? 'Kirim ke Kepala Desa?' : 'Setujui & Publish?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kirimKeKades
                  ? 'Informasi "${news.judul}" akan dikirim ke Kepala Desa untuk disetujui.'
                  : 'Informasi "${news.judul}" akan langsung dipublikasikan ke semua warga.',
            ),
            if (!kirimKeKades) ...[
              const SizedBox(height: 16),
              ExpiryPicker(
                wajib: news.kategori == 'ketenagakerjaan',
                initial: berlaku,
                onChanged: (d) => berlaku = d,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (!kirimKeKades &&
                  news.kategori == 'ketenagakerjaan' &&
                  berlaku == null) {
                showSnack(false, '', 'expiry_required'.tr);
                return;
              }
              Get.back();
              bool ok;
              if (kirimKeKades) {
                ok = await dataCtrl.kirimKeKades(news.id);
              } else {
                ok = await dataCtrl.approveNews(news.id, berlakuSampai: berlaku);
              }
              Get.snackbar(
                ok ? 'Berhasil ✅' : 'Gagal',
                ok
                    ? (kirimKeKades
                    ? 'Dikirim ke Kepala Desa.'
                    : 'Informasi dipublikasikan!')
                    : dataCtrl.errorMsg.value,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor:
                ok ? Colors.green.shade700 : Colors.red.shade700,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
            child: Text(kirimKeKades ? 'Kirim' : 'Publish'),
          ),
        ],
      ),
    );
  }

  // Dialog Tolak (alasan baku + dicatat di log)
  Future<void> _showDialogTolak(
      BuildContext context, NewsModel news, DataController dataCtrl) async {
    final alasan = await pilihAlasanTolak('informasi',
        judul: 'Tolak informasi');
    if (alasan == null) return;
    final ok = await dataCtrl.rejectNews(news.id, alasan: alasan);
    showSnack(ok, 'Pengajuan ditolak dan alasan dicatat di log.',
        dataCtrl.errorMsg.value);
  }
}


// ============================================================
// TabPendingView — "Tertunda"
// Isinya HANYA hal yang belum tayang milik saya:
//   • Draf           (Admin & Kades)
//   • Menunggu Kades (Admin: ajuan kategori sensitif yang belum di-ACC)
// Membuat informasi baru ada di Beranda (tombol +), bukan di sini.
// ============================================================
class TabPendingView extends StatefulWidget {
  const TabPendingView({super.key});

  @override
  State<TabPendingView> createState() => _TabPendingViewState();
}

class _TabPendingViewState extends State<TabPendingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    if (!Get.isRegistered<DataController>()) Get.put(DataController());
    final d = Get.find<DataController>();
    await d.fetchDraftList();
    await d.fetchMenungguKades();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final DataController dataCtrl = Get.find<DataController>();

    return Obx(() {
      final String role = authCtrl.role;
      final Color primaryColor = AppTheme.primaryColor(role);
      final bool admin = role == 'admin';

      final Widget draf = _daftar(
        dataCtrl.draftList,
        primaryColor,
        role,
        dataCtrl,
        kosongJudul: 'Belum ada draf',
        kosongSub:
            'Saat membuat informasi di Beranda, aktifkan "Simpan sebagai draf" bila belum ingin menayangkannya.',
      );

      if (!admin) {
        return Scaffold(
          appBar: AppBar(
              title: const Text('Draf Saya'), backgroundColor: primaryColor),
          body: draf,
        );
      }

      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Tertunda'),
            backgroundColor: primaryColor,
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Draf (${dataCtrl.draftList.length})'),
                Tab(text: 'Menunggu Kades (${dataCtrl.menungguKades.length})'),
              ],
            ),
          ),
          body: TabBarView(children: [
            draf,
            _daftar(
              dataCtrl.menungguKades,
              primaryColor,
              role,
              dataCtrl,
              kosongJudul: 'Tidak ada yang menunggu Kades',
              kosongSub:
                  'Informasi kategori sensitif yang Anda kirim akan tampil di sini sampai Kepala Desa memutuskan.',
            ),
          ]),
        ),
      );
    });
  }

  Widget _daftar(List<NewsModel> list, Color primaryColor, String role,
      DataController dataCtrl,
      {required String kosongJudul, required String kosongSub}) {
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _muat,
      child: list.isEmpty
          ? ListView(children: [
              const SizedBox(height: 60),
              EmptyState(
                  icon: Icons.pending_actions_outlined,
                  title: kosongJudul,
                  subtitle: kosongSub,
                  color: primaryColor),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  _kartu(context, list[i], primaryColor, role, dataCtrl),
            ),
    );
  }

  Widget _kartu(BuildContext context, NewsModel news, Color primaryColor,
      String role, DataController dataCtrl) {
    final bool menungguKades = news.status == 'pending_kades';
    // Admin + kategori sensitif tidak boleh publish sendiri → kirim ke Kades.
    final bool kirimKades =
        role == 'admin' && AppUtils.isKategoriSensitif(news.kategori);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge(
                    text: NewsModel.labelStatus(news.status),
                    color: AppTheme.statusColor(news.status)),
                Text(AppUtils.formatRelatif(news.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(NewsModel.labelKategori(news.kategori),
                style: TextStyle(
                    fontSize: 11.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(news.judul,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(news.isi,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (news.berlakuSampai != null) ...[
              const SizedBox(height: 6),
              Text('Berlaku sampai ${AppUtils.formatTanggal(news.berlakuSampai!)}',
                  style: TextStyle(
                      fontSize: 11.5, color: AppTheme.textSecondary)),
            ] else ...[
              const SizedBox(height: 6),
              Text('Tanpa masa berlaku — akan dihapus otomatis. Ubah untuk mengisi.',
                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade700)),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _hapus(news, dataCtrl),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Hapus',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showFormInformasi(edit: news),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Ubah'),
                  ),
                ),
                if (!menungguKades) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _publish(news, dataCtrl, kirimKades),
                      icon: Icon(kirimKades ? Icons.forward : Icons.publish,
                          size: 16, color: Colors.white),
                      label: Text(kirimKades ? 'Kirim ke Kades' : 'Publish',
                          style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish(
      NewsModel news, DataController dataCtrl, bool kirimKades) async {
    if (news.berlakuSampai == null || news.kadaluarsa) {
      showSnack(false, '',
          'Masa berlaku kosong/sudah lewat. Tekan "Ubah" dan pilih tanggal berlaku dulu.');
      return;
    }
    final ok = kirimKades
        ? await dataCtrl.kirimKeKades(news.id)
        : await dataCtrl.approveNews(news.id);
    showSnack(ok, kirimKades ? 'Dikirim ke Kepala Desa.' : 'Informasi dipublikasikan.',
        dataCtrl.errorMsg.value);
  }

  Future<void> _hapus(NewsModel news, DataController dataCtrl) async {
    final ya = await Get.dialog<bool>(AlertDialog(
      title: const Text('Hapus?'),
      content: Text('"${news.judul}" akan dihapus permanen.'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Get.back(result: true),
          child: const Text('Hapus', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (ya != true) return;
    final ok = await dataCtrl.hapusDraft(news.id);
    showSnack(ok, 'Berhasil dihapus.', dataCtrl.errorMsg.value);
  }
}
