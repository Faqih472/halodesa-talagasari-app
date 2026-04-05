// ============================================================
// tab_myrequest_view.dart - TAHAP 2
// Status pengajuan informasi milik warga
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';
import '../models/app_models.dart';

class TabMyRequestView extends StatelessWidget {
  const TabMyRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    if (!Get.isRegistered<DataController>()) {
      Get.put(DataController());
    }
    final DataController dataCtrl = Get.find<DataController>();

    const Color primaryColor = AppTheme.warnaWarga;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Saya'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => dataCtrl.fetchMyRequests(),
          ),
        ],
      ),
      body: Obx(() {
        if (dataCtrl.isLoadingMyReq.value) {
          return const Center(
              child: CircularProgressIndicator(color: primaryColor));
        }

        final requests = dataCtrl.myRequests;

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 72, color: primaryColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('Belum ada pengajuan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text(
                      'Pengajuan informasi yang Anda kirim akan muncul di sini.\nTap tombol + di Beranda untuk mengajukan.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () => dataCtrl.fetchMyRequests(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _buildRequestCard(requests[index], primaryColor),
          ),
        );
      }),
    );
  }

  Widget _buildRequestCard(NewsModel news, Color primaryColor) {
    final statusColor = AppTheme.statusColor(news.status);
    final statusLabel = NewsModel.labelStatus(news.status);
    final statusIcon = _statusIcon(news.status);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: kategori + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  NewsModel.labelKategori(news.kategori),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Judul
            Text(news.judul,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),

            // Isi preview
            Text(news.isi,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            // Alasan penolakan (jika ditolak)
            if (news.status == 'ditolak' &&
                news.alasanPenolakan != null &&
                news.alasanPenolakan!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alasan: ${news.alasanPenolakan}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Diajukan ${AppUtils.formatRelatif(news.createdAt)}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'published':
        return Icons.check_circle_outline;
      case 'menunggu_review_admin':
        return Icons.hourglass_top_outlined;
      case 'pending_kades':
        return Icons.pending_outlined;
      case 'ditolak':
        return Icons.cancel_outlined;
      default:
        return Icons.edit_outlined;
    }
  }
}