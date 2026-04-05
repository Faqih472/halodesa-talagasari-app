// ============================================================
// tab_manage_view.dart - TAHAP 2 FINAL
// Kelola Pengajuan: Admin review warga, Kades review pending
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';
import '../models/app_models.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final DataController dataCtrl = Get.find<DataController>();

    return Obx(() {
      final String role = authCtrl.role;
      final Color primaryColor = AppTheme.primaryColor(role);
      final String judulTab = role == 'kades'
          ? 'Persetujuan Kades'
          : 'Kelola Pengajuan';

      return Scaffold(
        appBar: AppBar(
          title: Text(judulTab),
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => dataCtrl.fetchPendingList(),
            ),
          ],
        ),
        body: Obx(() {
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
              itemBuilder: (context, index) => _buildPendingCard(
                context,
                list[index],
                primaryColor,
                role,
                dataCtrl,
              ),
            ),
          );
        }),
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
            const Text('Tidak ada pengajuan masuk',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              role == 'kades'
                  ? 'Belum ada informasi sensitif yang menunggu persetujuan Anda.'
                  : 'Semua pengajuan dari warga sudah diproses.',
              style: const TextStyle(
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
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Judul
            Text(news.judul,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),

            // Isi preview
            Text(news.isi,
                style: const TextStyle(
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
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text(news.judul,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(AppUtils.formatTanggalWaktu(news.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const Divider(height: 24),
                Text(news.isi,
                    style: const TextStyle(
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

    Get.dialog(
      AlertDialog(
        title: Text(kirimKeKades ? 'Kirim ke Kepala Desa?' : 'Setujui & Publish?'),
        content: Text(
          kirimKeKades
              ? 'Informasi "${news.judul}" akan dikirim ke Kepala Desa untuk disetujui.'
              : 'Informasi "${news.judul}" akan langsung dipublikasikan ke semua warga.',
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              bool ok;
              if (kirimKeKades) {
                ok = await dataCtrl.kirimKeKades(news.id);
              } else {
                ok = await dataCtrl.approveNews(news.id);
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

  // Dialog Tolak
  void _showDialogTolak(
      BuildContext context, NewsModel news, DataController dataCtrl) {
    final alasanCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Tolak Pengajuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tolak informasi "${news.judul}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: alasanCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan penolakan (opsional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              final ok = await dataCtrl.rejectNews(news.id,
                  alasan: alasanCtrl.text);
              Get.snackbar(
                ok ? 'Ditolak' : 'Gagal',
                ok
                    ? 'Pengajuan berhasil ditolak.'
                    : dataCtrl.errorMsg.value,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor:
                ok ? Colors.orange.shade700 : Colors.red.shade700,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
            child: const Text('Tolak',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}