// ============================================================
// home_view.dart — MainLayoutView + TabHomeView + NotificationView
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import 'admin_view.dart';
import 'chat_view.dart';
import 'jasa_view.dart';
import 'profile_view.dart';

// ============================================================
// main_layout_view.dart — REWRITE
// Kerangka utama: Dynamic Navbar (kini dengan animasi custom)
// + Dynamic Theme berdasarkan Role + auto-update lokasi GPS
// (Elisitasi #29: lokasi diperbarui otomatis tiap app dibuka).
// ============================================================

// Import semua tab views

class MainLayoutView extends StatefulWidget {
  const MainLayoutView({super.key});

  @override
  State<MainLayoutView> createState() => _MainLayoutViewState();
}

class _MainLayoutViewState extends State<MainLayoutView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authCtrl = Get.find<AuthController>();
      authCtrl.updateLokasiOtomatis();
      try {
        Get.find<ChatController>().listenMyRooms();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final MainController mainCtrl = Get.find<MainController>();

    return Obx(() {
      final String role = authCtrl.role;
      final bool isStaff = authCtrl.isStaff;

      final List<Widget> pages = isStaff ? _staffPages() : _wargaPages();

      return Theme(
        data: AppTheme.buildTheme(role),
        child: Scaffold(
          body: Obx(
            () => IndexedStack(
              index: mainCtrl.currentIndex.value,
              children: pages,
            ),
          ),
          bottomNavigationBar: _AnimatedBottomNav(
            mainCtrl: mainCtrl,
            role: role,
            isStaff: isStaff,
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // Halaman untuk Warga (5 tab)
  // ─────────────────────────────────────────────────────────
  List<Widget> _wargaPages() => const [
        TabHomeView(),      // 0: Beranda
        TabJasaView(),      // 1: Jasa
        ChatListView(),     // 2: Chat
        TabMyRequestView(), // 3: Pengajuan Saya
        TabSettingsView(),  // 4: Pengaturan
      ];

  // ─────────────────────────────────────────────────────────
  // Halaman untuk Admin & Kades (4 tab)
  // ─────────────────────────────────────────────────────────
  List<Widget> _staffPages() => const [
        TabHomeView(),     // 0: Beranda
        TabManageView(),   // 1: Kelola Pengajuan (+ Verifikasi Jasa utk Admin)
        TabPendingView(),  // 2: Draft & Tertunda
        TabSettingsView(), // 3: Pengaturan
      ];
}

// ─────────────────────────────────────────────────────────────
// Bottom Navigation Bar kustom dengan indikator "pill" bergeser
// dan ikon yang membesar-mengecil (bouncy) saat dipilih.
// ─────────────────────────────────────────────────────────────
class _AnimatedBottomNav extends StatelessWidget {
  final MainController mainCtrl;
  final String role;
  final bool isStaff;

  const _AnimatedBottomNav({
    required this.mainCtrl,
    required this.role,
    required this.isStaff,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = AppTheme.primaryColor(role);
    final items = mainCtrl.currentNavItems;

    return Obx(() {
      final int active = mainCtrl.currentIndex.value;
      final int totalUnread = _unreadChatBadge();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(items.length, (i) {
                final bool isActive = i == active;
                final bool showChatBadge =
                    !isStaff && i == MainController.idxChat && totalUnread > 0;

                return Expanded(
                  child: InkWell(
                    onTap: () => mainCtrl.changeTab(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.symmetric(
                                horizontal: isActive ? 18 : 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? primaryColor.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AnimatedScale(
                                scale: isActive ? 1.12 : 1.0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: IconTheme(
                                  data: IconThemeData(
                                    color: isActive
                                        ? primaryColor
                                        : AppTheme.textSecondary,
                                    size: 23,
                                  ),
                                  child: (isActive
                                      ? items[i].activeIcon
                                      : items[i].icon) as Widget,
                                ),
                              ),
                            ),
                            if (showChatBadge)
                              Positioned(
                                top: -2,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 14,
                                    minHeight: 14,
                                  ),
                                  child: Text(
                                    totalUnread > 9 ? '9+' : '$totalUnread',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            fontSize: isActive ? 11 : 10.5,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? primaryColor : AppTheme.textSecondary,
                          ),
                          child: Text(items[i].label ?? ''),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
    });
  }

  int _unreadChatBadge() {
    try {
      final chatCtrl = Get.find<ChatController>();
      return chatCtrl.totalUnread;
    } catch (_) {
      return 0;
    }
  }
}


// ============================================================
// tab_home_view.dart - TAHAP 2
// Beranda: List informasi desa + form pengajuan warga
// ============================================================

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
            _buildBellIcon(),
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
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const ShimmerCard(),
                      childCount: 4,
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
                        (context, index) => FadeSlideIn(
                          key: ValueKey(berita[index].id),
                          delay: Duration(milliseconds: 60 * (index % 8)),
                          child: _buildNewsCard(
                              berita[index], primaryColor, context),
                        ),
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

  Widget _buildBellIcon() {
    final notifCtrl = Get.find<NotificationController>();
    return Obx(() {
      final int unread = notifCtrl.unreadCount.value;
      return Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Get.to(() => const NotificationView()),
          ),
          if (unread > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
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


// ============================================================
// notification_view.dart
// Pusat notifikasi realtime: persetujuan informasi, verifikasi
// jasa, ulasan baru, dan pesan chat masuk.
// ============================================================

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final NotificationController notifCtrl = Get.find<NotificationController>();
    final Color primaryColor = AppTheme.primaryColor(authCtrl.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Notifikasi'),
        actions: [
          Obx(() => notifCtrl.unreadCount.value > 0
              ? TextButton(
                  onPressed: notifCtrl.tandaiSemuaDibaca,
                  child: const Text('Tandai semua',
                      style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        final list = notifCtrl.daftar;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'Belum ada notifikasi',
            subtitle:
                'Pemberitahuan tentang pengajuan, verifikasi, ulasan, dan pesan akan muncul di sini.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final n = list[i];
            return FadeSlideIn(
              key: ValueKey(n.id),
              delay: Duration(milliseconds: 40 * (i % 10)),
              dy: 12,
              child: _buildTile(n, notifCtrl, primaryColor, authCtrl),
            );
          },
        );
      }),
    );
  }

  Color _warnaTipe(String tipe, Color primary) {
    switch (tipe) {
      case 'jasa':
        return const Color(0xFFE65100);
      case 'chat':
        return const Color(0xFF1565C0);
      case 'sistem':
        return AppTheme.statusDraft;
      default:
        return primary;
    }
  }

  Widget _buildTile(AppNotification n, NotificationController notifCtrl,
      Color primaryColor, AuthController authCtrl) {
    final Color c = _warnaTipe(n.tipe, primaryColor);
    return Dismissible(
      key: ValueKey('dismiss_${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.green.shade600,
        child: const Icon(Icons.done_all, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await notifCtrl.tandaiDibaca(n.id);
        return false; // hanya tandai dibaca, item tetap ada
      },
      child: Container(
        color: n.dibaca ? Colors.transparent : primaryColor.withOpacity(0.06),
        child: ListTile(
          onTap: () {
            notifCtrl.tandaiDibaca(n.id);
            // Navigasi ringan sesuai tipe
            if (n.tipe == 'chat') {
              Get.back();
              try {
                Get.find<MainController>().goToChat();
              } catch (_) {}
            } else if (n.tipe == 'jasa' && !authCtrl.isStaff) {
              Get.back();
              try {
                Get.find<MainController>().goToJasa();
              } catch (_) {}
            }
          },
          leading: CircleAvatar(
            backgroundColor: c.withOpacity(0.12),
            child: Icon(n.icon, color: c, size: 22),
          ),
          title: Text(
            n.judul,
            style: TextStyle(
              fontSize: 14,
              fontWeight: n.dibaca ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              n.isi,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppUtils.formatRelatif(n.createdAt),
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (!n.dibaca)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
