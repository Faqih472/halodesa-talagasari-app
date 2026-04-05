// ============================================================
// tab_pending_view.dart - TAHAP 2 FINAL
// Draft & Pending: Admin buat konten langsung, Kades publish
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../core/app_theme.dart';
import '../core/app_utils.dart';
import '../models/app_models.dart';

class TabPendingView extends StatefulWidget {
  const TabPendingView({super.key});

  @override
  State<TabPendingView> createState() => _TabPendingViewState();
}

class _TabPendingViewState extends State<TabPendingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<DataController>()) Get.put(DataController());
      Get.find<DataController>().fetchDraftList();
      Get.find<DataController>().fetchKadesQueue();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final DataController dataCtrl = Get.find<DataController>();

    return Obx(() {
      final String role = authCtrl.role;
      final Color primaryColor = AppTheme.primaryColor(role);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Draft & Tertunda'),
          backgroundColor: primaryColor,
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: role == 'admin' ? 'Draft Saya' : 'Pending Kades'),
              const Tab(text: 'Buat Konten'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // Tab 1: List draft/pending
            _buildDraftList(dataCtrl, primaryColor, role),
            // Tab 2: Form buat konten baru
            _buildFormBuatKonten(dataCtrl, primaryColor, role),
          ],
        ),
      );
    });
  }

  // ── Tab 1: List Draft / Pending Kades ─────────────────────
  Widget _buildDraftList(
      DataController dataCtrl, Color primaryColor, String role) {
    return Obx(() {
      List<NewsModel> list;
      if (role == 'kades') {
        list = dataCtrl.kadesQueue;
      } else {
        list = dataCtrl.draftList;
      }

      if (list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_actions_outlined,
                    size: 72, color: primaryColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  role == 'kades'
                      ? 'Tidak ada yang menunggu persetujuan'
                      : 'Belum ada draft',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  role == 'kades'
                      ? 'Informasi sensitif yang dikirim Admin akan muncul di sini.'
                      : 'Buat konten di tab "Buat Konten" untuk disimpan sebagai draft.',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          if (role == 'kades') {
            await dataCtrl.fetchKadesQueue();
          } else {
            await dataCtrl.fetchDraftList();
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, index) => _buildDraftCard(
              context, list[index], primaryColor, role, dataCtrl),
        ),
      );
    });
  }

  Widget _buildDraftCard(BuildContext context, NewsModel news,
      Color primaryColor, String role, DataController dataCtrl) {
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
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(news.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    NewsModel.labelStatus(news.status),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.statusColor(news.status),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text(AppUtils.formatRelatif(news.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            Text(news.judul,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(news.isi,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Divider(height: 20),
            Row(
              children: [
                // Hapus (hanya untuk draft admin)
                if (role == 'admin' && news.status == 'draft') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmHapus(news, dataCtrl),
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('Hapus',
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
                ],

                // Publish (untuk semua yang statusnya draft/pending_kades)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _confirmPublish(news, dataCtrl, primaryColor),
                    icon: const Icon(Icons.publish,
                        size: 16, color: Colors.white),
                    label: const Text('Publish Sekarang',
                        style: TextStyle(color: Colors.white)),
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

  // ── Tab 2: Form Buat Konten Baru ───────────────────────────
  Widget _buildFormBuatKonten(
      DataController dataCtrl, Color primaryColor, String role) {
    final formKey = GlobalKey<FormState>();
    final judulCtrl = TextEditingController();
    final isiCtrl = TextEditingController();
    String selectedKategori = 'pengumuman';
    bool simpanDraft = false;

    return StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Buat Informasi Baru',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              const SizedBox(height: 4),
              Text(
                role == 'kades'
                    ? 'Sebagai Kepala Desa, konten dapat langsung dipublikasikan.'
                    : 'Konten biasa dapat langsung dipublish. Kategori sensitif dikirim ke Kades.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // Dropdown Kategori
              DropdownButtonFormField<String>(
                value: selectedKategori,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: AppUtils.daftarKategoriInfo.map((k) {
                  return DropdownMenuItem(
                      value: k['value'], child: Text(k['label']!));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedKategori = val);
                },
              ),

              // Info kategori sensitif
              if (role == 'admin' &&
                  AppUtils.isKategoriSensitif(selectedKategori)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kategori ini akan dikirim ke Kepala Desa untuk disetujui.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Judul
              TextFormField(
                controller: judulCtrl,
                validator: (v) =>
                    AppUtils.validateRequired(v, label: 'Judul'),
                decoration: InputDecoration(
                  labelText: 'Judul',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Isi
              TextFormField(
                controller: isiCtrl,
                maxLines: 5,
                validator: (v) =>
                    AppUtils.validateRequired(v, label: 'Isi konten'),
                decoration: InputDecoration(
                  labelText: 'Isi Informasi',
                  hintText: 'Tuliskan detail informasi...',
                  prefixIcon: const Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle simpan draft (hanya admin, kategori tidak sensitif)
              if (role == 'admin' &&
                  !AppUtils.isKategoriSensitif(selectedKategori)) ...[
                SwitchListTile(
                  value: simpanDraft,
                  onChanged: (val) => setState(() => simpanDraft = val),
                  title: const Text('Simpan sebagai Draft dulu',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Aktifkan jika belum ingin langsung publish',
                      style: TextStyle(fontSize: 12)),
                  activeColor: primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 8),

              // Tombol Submit
              Obx(() => ElevatedButton.icon(
                onPressed: dataCtrl.isSubmitting.value
                    ? null
                    : () async {
                  if (!formKey.currentState!.validate()) return;
                  final ok = await dataCtrl.buatKontenStaff(
                    judul: judulCtrl.text,
                    isi: isiCtrl.text,
                    kategori: selectedKategori,
                    role: role,
                    simpanDraft: simpanDraft,
                  );
                  if (ok) {
                    judulCtrl.clear();
                    isiCtrl.clear();
                    setState(() {
                      selectedKategori = 'pengumuman';
                      simpanDraft = false;
                    });

                    String pesanSukses = 'Konten berhasil dipublikasikan!';
                    if (simpanDraft) {
                      pesanSukses = 'Disimpan sebagai draft.';
                    } else if (role == 'admin' &&
                        AppUtils.isKategoriSensitif(
                            selectedKategori)) {
                      pesanSukses = 'Dikirim ke Kepala Desa.';
                    }

                    Get.snackbar(
                      'Berhasil ✅',
                      pesanSukses,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green.shade700,
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  } else {
                    Get.snackbar(
                      'Gagal',
                      dataCtrl.errorMsg.value,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red.shade700,
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
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  dataCtrl.isSubmitting.value
                      ? 'Menyimpan...'
                      : simpanDraft
                      ? 'Simpan Draft'
                      : AppUtils.isKategoriSensitif(selectedKategori) && role == 'admin'
                      ? 'Kirim ke Kades'
                      : 'Publish Sekarang',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPublish(
      NewsModel news, DataController dataCtrl, Color primaryColor) {
    Get.dialog(
      AlertDialog(
        title: const Text('Publish Konten?'),
        content: Text(
            'Informasi "${news.judul}" akan dipublikasikan ke semua warga.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final ok = await dataCtrl.approveNews(news.id);
              Get.snackbar(
                ok ? 'Berhasil ✅' : 'Gagal',
                ok
                    ? 'Informasi berhasil dipublikasikan!'
                    : dataCtrl.errorMsg.value,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor:
                ok ? Colors.green.shade700 : Colors.red.shade700,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _confirmHapus(NewsModel news, DataController dataCtrl) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Draft?'),
        content: Text('Draft "${news.judul}" akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              final ok = await dataCtrl.hapusDraft(news.id);
              Get.snackbar(
                ok ? 'Dihapus' : 'Gagal',
                ok ? 'Draft berhasil dihapus.' : dataCtrl.errorMsg.value,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor:
                ok ? Colors.grey.shade700 : Colors.red.shade700,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
            child: const Text('Hapus',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}