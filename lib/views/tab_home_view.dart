// ============================================================
// tab_home_view.dart - TAHAP 2
// Beranda: List informasi desa + form pengajuan warga
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';
import '../models/app_models.dart';

class TabHomeView extends StatelessWidget {
  const TabHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    if (!Get.isRegistered<DataController>()) {
      Get.put(DataController());
    }
    final DataController dataCtrl = Get.find<DataController>();

    return Obx(() {
      final user = authCtrl.currentUser.value;
      final String role = user?.role ?? 'warga';
      final Color primaryColor = AppTheme.primaryColor(role);

      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: const Row(
            children: [
              Icon(Icons.location_city, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Talagasari Hub'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => dataCtrl.fetchPublishedNews(),
            ),
          ],
        ),
        floatingActionButton: role == 'warga'
            ? FloatingActionButton.extended(
          backgroundColor: primaryColor,
          onPressed: () =>
              _showFormPengajuan(context, dataCtrl, primaryColor),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Ajukan Info',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        )
            : null,
        body: RefreshIndicator(
          color: primaryColor,
          onRefresh: () => dataCtrl.fetchPublishedNews(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildWelcomeBanner(
                      user?.nama ?? '', role, primaryColor)),
              SliverToBoxAdapter(
                  child: _buildFilterChips(dataCtrl, primaryColor)),
              Obx(() {
                if (dataCtrl.isLoadingNews.value) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(
                          child:
                          CircularProgressIndicator(color: primaryColor)),
                    ),
                  );
                }
                final berita = dataCtrl.filteredNews;
                if (berita.isEmpty) {
                  return SliverToBoxAdapter(
                      child: _buildKosong(primaryColor));
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                        _buildNewsCard(berita[index], primaryColor, context),
                    childCount: berita.length,
                  ),
                );
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWelcomeBanner(
      String nama, String role, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, ${nama.split(' ').first}! 👋',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('Informasi terkini Desa Talagasari',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
          if (role == 'warga') ...[
            const SizedBox(height: 10),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('💡 Tap tombol + untuk mengajukan informasi',
                  style: TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips(DataController dataCtrl, Color primaryColor) {
    final filters = [
      {'value': 'semua', 'label': 'Semua'},
      {'value': 'pengumuman', 'label': 'Pengumuman'},
      {'value': 'kegiatan', 'label': 'Kegiatan'},
      {'value': 'kesehatan', 'label': 'Kesehatan'},
      {'value': 'ketenagakerjaan', 'label': 'Loker'},
      {'value': 'bantuan_sosial', 'label': 'Bansos'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Obx(() => Row(
          children: filters.map((f) {
            final isActive =
                dataCtrl.filterKategori.value == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f['label']!),
                selected: isActive,
                onSelected: (_) => dataCtrl.setFilter(f['value']!),
                selectedColor: primaryColor.withOpacity(0.15),
                checkmarkColor: primaryColor,
                labelStyle: TextStyle(
                  color: isActive
                      ? primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                    color: isActive
                        ? primaryColor
                        : Colors.grey.shade300),
                backgroundColor: Colors.white,
              ),
            );
          }).toList(),
        )),
      ),
    );
  }

  Widget _buildNewsCard(
      NewsModel news, Color primaryColor, BuildContext context) {
    final kategoriColor = _kategoriColor(news.kategori);
    final kategoriIcon = _kategoriIcon(news.kategori);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailBerita(context, news, primaryColor),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kategoriColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(kategoriIcon,
                            size: 12, color: kategoriColor),
                        const SizedBox(width: 4),
                        Text(
                          NewsModel.labelKategori(news.kategori),
                          style: TextStyle(
                              fontSize: 11,
                              color: kategoriColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    news.publishedAt != null
                        ? AppUtils.formatRelatif(news.publishedAt!)
                        : AppUtils.formatRelatif(news.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(news.judul,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(news.isi,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Lihat selengkapnya',
                      style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right,
                      size: 16, color: primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKosong(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: primaryColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Belum ada informasi',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Informasi desa akan muncul di sini setelah disetujui oleh aparatur desa.',
              style:
              TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showDetailBerita(
      BuildContext context, NewsModel news, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kategoriColor(news.kategori)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          NewsModel.labelKategori(news.kategori),
                          style: TextStyle(
                              fontSize: 12,
                              color: _kategoriColor(news.kategori),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(news.judul,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            news.publishedAt != null
                                ? AppUtils.formatTanggalWaktu(
                                news.publishedAt!)
                                : AppUtils.formatTanggalWaktu(
                                news.createdAt),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFormPengajuan(
      BuildContext context, DataController dataCtrl, Color primaryColor) {
    final formKey = GlobalKey<FormState>();
    final judulCtrl = TextEditingController();
    final isiCtrl = TextEditingController();
    String selectedKategori = 'pengumuman';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('Ajukan Informasi Desa',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor)),
                    const SizedBox(height: 4),
                    const Text(
                        'Informasi Anda akan diproses oleh aparatur desa.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedKategori,
                      decoration: InputDecoration(
                        labelText: 'Kategori Informasi',
                        prefixIcon:
                        const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: AppUtils.daftarKategoriInfo.map((k) {
                        return DropdownMenuItem(
                            value: k['value'],
                            child: Text(k['label']!));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedKategori = val);
                        }
                      },
                    ),
                    if (AppUtils.isKategoriSensitif(
                        selectedKategori)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kategori ini memerlukan persetujuan Kepala Desa.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: judulCtrl,
                      validator: (v) =>
                          AppUtils.validateRequired(v, label: 'Judul'),
                      decoration: InputDecoration(
                        labelText: 'Judul',
                        hintText: 'Contoh: Jadwal Kerja Bakti RT 03',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: isiCtrl,
                      maxLines: 4,
                      validator: (v) => AppUtils.validateRequired(v,
                          label: 'Isi informasi'),
                      decoration: InputDecoration(
                        labelText: 'Isi Informasi',
                        hintText:
                        'Tuliskan detail informasi di sini...',
                        prefixIcon:
                        const Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Obx(() => ElevatedButton.icon(
                      onPressed: dataCtrl.isSubmitting.value
                          ? null
                          : () async {
                        if (!formKey.currentState!
                            .validate()) return;
                        final ok =
                        await dataCtrl.submitInformasi(
                          judul: judulCtrl.text,
                          isi: isiCtrl.text,
                          kategori: selectedKategori,
                        );
                        if (ok) {
                          Navigator.pop(ctx);
                          Get.snackbar(
                            'Berhasil! 🎉',
                            AppUtils.isKategoriSensitif(
                                selectedKategori)
                                ? 'Pengajuan dikirim ke Kepala Desa.'
                                : 'Pengajuan dikirim ke Admin.',
                            snackPosition:
                            SnackPosition.BOTTOM,
                            backgroundColor:
                            Colors.green.shade700,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(16),
                            borderRadius: 12,
                          );
                        }
                      },
                      icon: dataCtrl.isSubmitting.value
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : const Icon(Icons.send,
                          color: Colors.white),
                      label: Text(
                        dataCtrl.isSubmitting.value
                            ? 'Mengirim...'
                            : 'Kirim Pengajuan',
                        style:
                        const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize:
                        const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _kategoriColor(String kategori) {
    switch (kategori) {
      case 'kesehatan':
        return Colors.red.shade600;
      case 'ketenagakerjaan':
        return Colors.blue.shade600;
      case 'bantuan_sosial':
        return Colors.purple.shade600;
      case 'kegiatan':
        return Colors.orange.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  IconData _kategoriIcon(String kategori) {
    switch (kategori) {
      case 'kesehatan':
        return Icons.health_and_safety_outlined;
      case 'ketenagakerjaan':
        return Icons.work_outline;
      case 'bantuan_sosial':
        return Icons.volunteer_activism_outlined;
      case 'kegiatan':
        return Icons.event_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }
}