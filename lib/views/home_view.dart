// ============================================================
// home_view.dart — MainLayoutView + TabHomeView + NotificationView
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import 'admin_view.dart';
import 'chat_view.dart';
import 'complaint_view.dart' show TabPengaduanView;
import 'verification_view.dart';
import '../core/ui_helpers.dart';
import 'jasa_view.dart';
import 'account_view.dart';
import 'profile_view.dart';
import 'stats_view.dart';
import 'village_view.dart';
import 'letter_view.dart';
import 'admin_tools_view.dart';
import 'info_form_view.dart';
import '../controllers/village_controller.dart' show RetensiService;

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
      // Pembersihan data kedaluwarsa (hanya berjalan di perangkat Admin/Kades,
      // maksimal sekali per ~20 jam untuk seluruh desa).
      RetensiService.jalankan();
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
  // Halaman untuk Warga (5 tab). Chat ada di AppBar (ikon pesan).
  // ─────────────────────────────────────────────────────────
  List<Widget> _wargaPages() => const [
        TabHomeView(),      // 0: Beranda
        TabJasaView(),      // 1: Jasa
        TabPengaduanView(), // 2: Pengaduan
        NotificationView(), // 3: Notifikasi
        TabSettingsView(),  // 4: Akun (Pengaturan Akun)
      ];

  // ─────────────────────────────────────────────────────────
  // Halaman untuk Admin & Kades (5 tab)
  // ─────────────────────────────────────────────────────────
  List<Widget> _staffPages() => const [
        TabHomeView(),      // 0: Beranda
        TabManageView(),    // 1: Kelola Pengajuan (+ Verifikasi Jasa utk Admin)
        TabPendingView(),   // 2: Draft & Tertunda
        NotificationView(), // 3: Notifikasi
        TabSettingsView(),  // 4: Akun (Pengaturan Akun)
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
      final int notifUnread = _unreadNotifBadge();

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A7A4A).withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PitaBatik(tinggi: 6),
              SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(items.length, (i) {
                final bool isActive = i == active;
                int badge = 0;
                if (i == mainCtrl.idxNotif) {
                  badge = notifUnread;
                } else if (!isStaff && i == MainController.idxJasa) {
                  badge = _orderBadge();
                }
                final bool showChatBadge = badge > 0;

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
                                horizontal: isActive ? (items.length > 5 ? 12 : 18) : 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? primaryColor.withOpacity(0.13)
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
                                    badge > 9 ? '9+' : '$badge',
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
            ],
          ),
        ),
      );
    });
  }

  /// Pesanan jasa yang menunggu tindakan saya (sebagai penyedia / pemesan)
  int _orderBadge() {
    try {
      return Get.find<OrderController>().badgeTotal;
    } catch (_) {
      return 0;
    }
  }

  int _unreadNotifBadge() {
    try {
      return Get.find<NotificationController>().unreadCount.value;
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
          title: Row(
            children: [
              LogoTalagasari(ukuran: 34, warna: primaryColor),
              const SizedBox(width: 10),
              const Text('Talagasari'),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('HUB',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emas)),
              ),
            ],
          ),
          actions: [
            _buildBellIcon(),
            const ChatAction(),
          ],
        ),
        // Warga: ajukan info. Admin/Kades: buat info (pindahan dari tab Tertunda
        // — membuat informasi memang pekerjaan Beranda, bukan "Tertunda").
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryColor,
          onPressed: () async {
            if (role == 'warga' && !await wajibVerifikasi()) return;
            await showFormInformasi();
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(role == 'warga' ? 'Ajukan Info' : 'Buat Info',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: RefreshIndicator(
          color: primaryColor,
          onRefresh: () => dataCtrl.fetchPublishedNews(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildWelcomeBanner(
                      user?.panggilan ?? '', role, primaryColor)),
              const SliverToBoxAdapter(child: LayananDesaSection()),
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
            onPressed: () => Get.find<MainController>().goToNotif(),
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
    final String tanggal =
        DateFormat('EEEE, d MMMM y', 'id').format(DateTime.now());
    return MotifHeader(
      role: role,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 54),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            salamSunda(),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 0.4,
              color: AppTheme.emas.withOpacity(0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            nama.isEmpty ? 'Warga Talagasari' : nama,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontJudul,
              fontSize: 30,
              height: 1.15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(tanggal,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      role == 'warga'
                          ? 'Kabar terkini Desa Talagasari • tekan + untuk mengajukan info'
                          : 'Kabar terkini Desa Talagasari • tekan + untuk membuat info',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ],
            ),
          ),
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
      {'value': 'layanan_jasa', 'label': 'Layanan & Jasa'},
      {'value': 'usaha_umkm', 'label': 'UMKM'},
      {'value': 'pendidikan', 'label': 'Pendidikan'},
      {'value': 'keagamaan', 'label': 'Keagamaan'},
      {'value': 'olahraga_pemuda', 'label': 'Olahraga'},
      {'value': 'lingkungan', 'label': 'Lingkungan'},
      {'value': 'infrastruktur', 'label': 'Infrastruktur'},
      {'value': 'keamanan', 'label': 'Keamanan'},
      {'value': 'kehilangan', 'label': 'Kehilangan'},
      {'value': 'lainnya', 'label': 'Lainnya'},
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

  Widget _menuStaff(NewsModel news) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
      onSelected: (v) {
        if (v == 'ubah') {
          showFormInformasi(edit: news);
        } else if (v == 'perpanjang') {
          dialogPerpanjang(news);
        } else {
          konfirmasiHapusInformasi(news);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'perpanjang',
            child: Row(children: [
              Icon(Icons.update, size: 18),
              SizedBox(width: 10),
              Text('Perpanjang masa berlaku')
            ])),
        PopupMenuItem(
            value: 'ubah',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Ubah')
            ])),
        PopupMenuItem(
            value: 'hapus',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Hapus', style: TextStyle(color: Colors.red))
            ])),
      ],
    );
  }

  String _labelBerlaku(NewsModel n) {
    if (n.berlakuSampai == null) return '';
    final h = n.sisaHari;
    if (h <= 0) return 'Berakhir hari ini';
    if (h == 1) return 'Berakhir besok';
    if (h <= 7) return 'Berakhir $h hari lagi';
    return 'Berlaku s/d ${AppUtils.formatTanggal(n.berlakuSampai!)}';
  }

  Widget _buildNewsCard(
      NewsModel news, Color primaryColor, BuildContext context) {
    final kategoriColor = _kategoriColor(news.kategori);
    final kategoriIcon = _kategoriIcon(news.kategori);
    final bool staf = Get.find<AuthController>().isStaff;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      decoration: kartuTalagasari(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // garis warna kategori di tepi atas
            Container(height: 4, color: kategoriColor),
            InkWell(
              onTap: () => _showDetailBerita(context, news, primaryColor),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: kategoriColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(kategoriIcon,
                              size: 20, color: kategoriColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                NewsModel.labelKategori(news.kategori),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: kategoriColor,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                news.publishedAt != null
                                    ? AppUtils.formatRelatif(news.publishedAt!)
                                    : AppUtils.formatRelatif(news.createdAt),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (staf)
                          SizedBox(
                              width: 32, height: 28, child: _menuStaff(news)),
                      ],
                    ),
                    if (news.fotoUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      fotoFull(news.fotoUrl, radius: 14),
                    ],
                    const SizedBox(height: 12),
                    Text(news.judul,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontJudul,
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(news.isi,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: news.sisaHari <= 2
                                ? Colors.red.shade50
                                : AppTheme.kremTua.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule,
                                  size: 12,
                                  color: news.sisaHari <= 2
                                      ? Colors.red.shade700
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text(_labelBerlaku(news),
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: news.sisaHari <= 2
                                          ? Colors.red.shade700
                                          : AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Baca selengkapnya',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600)),
                            Icon(Icons.arrow_forward_rounded,
                                size: 15, color: primaryColor),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                      if (news.berlakuSampai != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.schedule,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(_labelBerlaku(news),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ]),
                      ],
                      const Divider(height: 24),
                      if (news.fotoUrl.isNotEmpty) ...[
                        fotoFull(news.fotoUrl, maksTinggi: 600),
                        const SizedBox(height: 14),
                      ],
                      Text(news.isi,
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              height: 1.6)),
                      if (Get.find<AuthController>().isStaff) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              dialogPerpanjang(news);
                            },
                            icon: const Icon(Icons.update, size: 18),
                            label: const Text('Perpanjang masa berlaku'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                konfirmasiHapusInformasi(news);
                              },
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              label: const Text('Hapus',
                                  style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                showFormInformasi(edit: news);
                              },
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: Colors.white),
                              label: const Text('Ubah',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ]),
                      ],
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
      case 'layanan_jasa':
        return Colors.indigo.shade500;
      case 'usaha_umkm':
        return Colors.amber.shade800;
      case 'pendidikan':
        return Colors.cyan.shade700;
      case 'keagamaan':
        return Colors.green.shade700;
      case 'olahraga_pemuda':
        return Colors.deepOrange.shade500;
      case 'lingkungan':
        return Colors.lightGreen.shade700;
      case 'infrastruktur':
        return Colors.brown.shade500;
      case 'keamanan':
        return Colors.blueGrey.shade600;
      case 'kehilangan':
        return Colors.pink.shade400;
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
      case 'layanan_jasa':
        return Icons.build_circle_outlined;
      case 'usaha_umkm':
        return Icons.storefront_outlined;
      case 'pendidikan':
        return Icons.school_outlined;
      case 'keagamaan':
        return Icons.mosque_outlined;
      case 'olahraga_pemuda':
        return Icons.sports_soccer_outlined;
      case 'lingkungan':
        return Icons.eco_outlined;
      case 'infrastruktur':
        return Icons.construction_outlined;
      case 'keamanan':
        return Icons.shield_outlined;
      case 'kehilangan':
        return Icons.search;
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
        title: Text('notif_title'.tr),
        actions: [
          IconButton(
            tooltip: 'Hapus yang sudah dibaca',
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            onPressed: () async {
              final n = await notifCtrl.hapusYangDibaca();
              showSnack(true, '$n notifikasi dibaca dihapus.', '');
            },
          ),
          Obx(() => notifCtrl.unreadCount.value > 0
              ? TextButton(
                  onPressed: notifCtrl.tandaiSemuaDibaca,
                  child: Text('notif_mark_all'.tr,
                      style: const TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        final list = notifCtrl.daftar;
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.notifications_none,
            title: 'notif_empty_title'.tr,
            subtitle: 'notif_empty_sub'.tr,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length + 1,
          itemBuilder: (context, i) {
            if (i == list.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Notifikasi dihapus otomatis: sudah dibaca > 14 hari, atau semua > 30 hari.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              );
            }
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
      case 'pesanan':
        return const Color(0xFFE65100);
      case 'chat':
        return const Color(0xFF1565C0);
      case 'pengaduan':
        return const Color(0xFFC62828);
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
              final c = Get.find<ChatController>();
              c.listenMyRooms();
              Get.to(() => const ChatListView());
            } else if (n.tipe == 'pengaduan') {
              try {
                final m = Get.find<MainController>();
                authCtrl.isStaff ? m.goToManage() : m.goToMyRequest();
              } catch (_) {}
            } else if (n.tipe == 'sos') {
              Get.to(() => const SosView());
            } else if (n.tipe == 'surat') {
              Get.to(() => const LetterHomeView());
            } else if (n.tipe == 'agenda') {
              Get.to(() => const AgendaListView());
            } else if (n.tipe == 'pesanan') {
              final id = n.targetId ?? '';
              if (id.isEmpty) {
                Get.to(() => const PesananSayaView());
              } else {
                Get.to(() => PesananDetailView(orderId: id));
              }
            } else if (n.tipe == 'jasa') {
              try {
                final m = Get.find<MainController>();
                authCtrl.isStaff ? m.goToManage() : m.goToJasa();
              } catch (_) {}
            } else if (n.tipe == 'info' && authCtrl.isStaff) {
              try {
                Get.find<MainController>().goToPending();
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
