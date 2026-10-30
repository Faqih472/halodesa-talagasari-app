// ============================================================
// data_controller.dart — DataController + ServiceController + OrderController
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import '../core/core.dart';
import '../core/models.dart';
import 'auth_controller.dart';
import 'complaint_controller.dart';
import 'village_controller.dart';
import '../core/models_extra.dart';
import 'chat_controller.dart';

// ============================================================
// data_controller.dart - TAHAP 2 FINAL
// Controller sentral: Informasi Desa + semua logic CRUD
// ============================================================

class DataController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── Reactive State ──────────────────────────────────────
  final RxList<NewsModel> publishedNews = <NewsModel>[].obs;
  final RxList<NewsModel> myRequests = <NewsModel>[].obs;
  final RxList<NewsModel> pendingList = <NewsModel>[].obs;
  final RxList<NewsModel> draftList = <NewsModel>[].obs;
  final RxList<NewsModel> kadesQueue = <NewsModel>[].obs;
  final RxList<NewsModel> menungguKades = <NewsModel>[].obs; // ajuan Admin yang menunggu Kades

  /// Diisi editInformasi(): true bila hasil ubah Admin menunggu ACC ulang Kades
  bool perluAccUlang = false;

  final RxBool isLoadingNews = false.obs;
  final RxBool isLoadingMyReq = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;
  final RxString filterKategori = 'semua'.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPublishedNews();
    fetchMyRequests();
  }

  // ─── FETCH: Published (semua user) ───────────────────────
  Future<void> fetchPublishedNews() async {
    try {
      isLoadingNews.value = true;
      errorMsg.value = '';
      final snapshot = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'published')
          .orderBy('published_at', descending: true)
          .get();
      publishedNews.value = snapshot.docs
          .map((d) => NewsModel.fromFirestore(d))
          .where((n) => !n.kadaluarsa && !n.permanen)
          .toList();
    } catch (e) {
      // Coba tanpa orderBy jika index belum ada
      try {
        final snapshot = await _firestore
            .collection('announcements')
            .where('status', isEqualTo: 'published')
            .get();
        publishedNews.value = snapshot.docs
            .map((d) => NewsModel.fromFirestore(d))
            .where((n) => !n.kadaluarsa && !n.permanen)
            .toList();
      } catch (e2) {
        errorMsg.value = 'Gagal memuat informasi: $e2';
      }
    } finally {
      isLoadingNews.value = false;
    }
  }

  // ─── FETCH: Pengajuan milik user ─────────────────────────
  Future<void> fetchMyRequests() async {
    try {
      isLoadingMyReq.value = true;
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final snapshot = await _firestore
          .collection('announcements')
          .where('authorId', isEqualTo: uid)
          .get();
      final list = snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      myRequests.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat pengajuan: $e';
    } finally {
      isLoadingMyReq.value = false;
    }
  }

  // ─── FETCH: Pending untuk Admin ──────────────────────────
  Future<void> fetchPendingList() async {
    try {
      final role = _authCtrl.role;
      final status = role == 'kades'
          ? 'pending_kades'
          : 'menunggu_review_admin';
      final snapshot = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: status)
          .get();
      final list = snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      pendingList.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat pengajuan: $e';
    }
  }

  // ─── FETCH: Draft milik staff ─────────────────────────────
  Future<void> fetchDraftList() async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final snapshot = await _firestore
          .collection('announcements')
          .where('authorId', isEqualTo: uid)
          .where('status', isEqualTo: 'draft')
          .get();
      final list = snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      draftList.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat draft: $e';
    }
  }

  // ─── FETCH: Antrian pending_kades (untuk Kades) ──────────
  Future<void> fetchKadesQueue() async {
    try {
      final snapshot = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'pending_kades')
          .get();
      final list = snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      kadesQueue.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat antrian: $e';
    }
  }

  // ─── FETCH: Ajuan Admin yang menunggu persetujuan Kades ──
  Future<void> fetchMenungguKades() async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final snapshot = await _firestore
          .collection('announcements')
          .where('authorId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending_kades')
          .get();
      final list = snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      menungguKades.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat ajuan menunggu Kades: $e';
    }
  }

  // ─── Foto informasi: base64 di Firestore (gratis) ────────
  Future<String?> _encodeFoto(File? f) async {
    if (f == null) return '';
    final enc = await ImageUtil.encode(f);
    if (enc == null) {
      errorMsg.value = 'Foto terlalu besar, pilih foto lain.';
      return null;
    }
    return enc;
  }

  // ─── SUBMIT: Warga ajukan informasi ──────────────────────
  Future<bool> submitInformasi({
    required String judul,
    required String isi,
    required String kategori,
    DateTime? berlakuSampai,
    File? foto,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return false;
      if (!Get.find<ComplaintController>().ktpOk) {
        errorMsg.value = 'need_verified'.tr;
        return false;
      }
      if (berlakuSampai == null) {
        errorMsg.value = 'expiry_required'.tr;
        return false;
      }
      final fotoUrl = await _encodeFoto(foto);
      if (fotoUrl == null) return false;

      // Rule-based: kategori sensitif → pending_kades, lainnya → menunggu_review_admin
      final statusAwal = AppUtils.tentukanStatusAwal(kategori);

      await _firestore.collection('announcements').add({
        'judul': judul.trim(),
        'isi': isi.trim(),
        'kategori': kategori,
        'status': statusAwal,
        'berlaku_sampai': Timestamp.fromDate(berlakuSampai),
        'authorId': uid,
        'foto_url': fotoUrl,
        'alasan_penolakan': null,
        'created_at': Timestamp.fromDate(DateTime.now()),
        'published_at': null,
      });

      await fetchMyRequests();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengajukan: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── BUAT KONTEN: Admin/Kades buat konten langsung ───────
  Future<bool> buatKontenStaff({
    required String judul,
    required String isi,
    required String kategori,
    required String role,
    bool simpanDraft = false,
    DateTime? berlakuSampai,
    File? foto,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return false;
      if (berlakuSampai == null) {
        errorMsg.value = 'expiry_required'.tr;
        return false;
      }
      final fotoUrl = await _encodeFoto(foto);
      if (fotoUrl == null) return false;

      String status;
      DateTime? publishedAt;

      if (simpanDraft) {
        status = 'draft';
      } else if (role == 'kades') {
        // Kades bisa langsung publish apapun
        status = 'published';
        publishedAt = DateTime.now();
      } else if (role == 'admin' && AppUtils.isKategoriSensitif(kategori)) {
        // Admin + kategori sensitif → kirim ke kades
        status = 'pending_kades';
      } else {
        // Admin + kategori biasa → langsung publish
        status = 'published';
        publishedAt = DateTime.now();
      }

      await _firestore.collection('announcements').add({
        'judul': judul.trim(),
        'isi': isi.trim(),
        'kategori': kategori,
        'status': status,
        'berlaku_sampai': Timestamp.fromDate(berlakuSampai),
        'authorId': uid,
        'foto_url': fotoUrl,
        'alasan_penolakan': null,
        'created_at': Timestamp.fromDate(DateTime.now()),
        'published_at':
        publishedAt != null ? Timestamp.fromDate(publishedAt) : null,
        'approved_by_uid': status == 'published' ? uid : null,
      });

      if (status == 'pending_kades') {
        await notifPeran(['kades'],
            judul: 'Informasi Menunggu Persetujuan',
            isi: 'Admin mengajukan: ${judul.trim()}',
            tipe: 'info');
      }
      await fetchDraftList();
      await fetchMenungguKades();
      await fetchPublishedNews();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal membuat konten: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── APPROVE: Publish konten ──────────────────────────────
  Future<bool> approveNews(String docId, {DateTime? berlakuSampai}) async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      final before = await _firestore.collection('announcements').doc(docId).get();
      final authorId = before.data()?['authorId'];
      final judul = before.data()?['judul'] ?? '';
      final kategori = (before.data()?['kategori'] ?? 'pengumuman') as String;
      // Kategori sensitif hanya boleh dipublikasikan oleh Kepala Desa
      if (_authCtrl.role == 'admin' && AppUtils.isKategoriSensitif(kategori)) {
        errorMsg.value =
            'Kategori sensitif harus disetujui Kepala Desa. Gunakan "Kirim ke Kades".';
        return false;
      }
      final lama = (before.data()?['berlaku_sampai'] as Timestamp?)?.toDate();
      if (berlakuSampai == null && lama == null) {
        errorMsg.value = 'expiry_required'.tr;
        return false;
      }

      await _firestore.collection('announcements').doc(docId).update({
        'status': 'published',
        'published_at': Timestamp.fromDate(DateTime.now()),
        'approved_by_uid': uid,
        if (berlakuSampai != null)
          'berlaku_sampai': Timestamp.fromDate(berlakuSampai),
      });
      await AuditLog.catat(
          aksi: 'Menyetujui informasi',
          targetTipe: 'informasi',
          targetId: docId,
          detail: judul.toString());
      await fetchPendingList();
      await fetchDraftList();
      await fetchKadesQueue();
      await fetchMenungguKades();
      await fetchPublishedNews();

      if (authorId != null && authorId.toString().isNotEmpty) {
        try {
          await Get.find<NotificationController>().kirimKe(
            uidTujuan: authorId,
            judul: 'Informasi Dipublikasikan ✅',
            isi: '"$judul" telah disetujui dan kini tampil di beranda warga.',
            tipe: 'info',
            targetId: docId,
          );
        } catch (_) {}
      }
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyetujui: $e';
      return false;
    }
  }

  // ─── KIRIM KE KADES: Admin eskalasi konten sensitif ──────
  Future<bool> kirimKeKades(String docId) async {
    try {
      final doc = await _firestore.collection('announcements').doc(docId).get();
      await _firestore.collection('announcements').doc(docId).update({
        'status': 'pending_kades',
      });
      await AuditLog.catat(
          aksi: 'Mengirim informasi ke Kades',
          targetTipe: 'informasi',
          targetId: docId,
          detail: (doc.data()?['judul'] ?? '').toString());
      await notifPeran(['kades'],
          judul: 'Informasi Menunggu Persetujuan',
          isi: (doc.data()?['judul'] ?? '').toString(),
          tipe: 'info',
          targetId: docId);
      await fetchPendingList();
      await fetchDraftList();
      await fetchMenungguKades();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim ke Kades: $e';
      return false;
    }
  }

  // ─── REJECT: Tolak konten ─────────────────────────────────
  Future<bool> rejectNews(String docId, {required String alasan}) async {
    try {
      final before = await _firestore.collection('announcements').doc(docId).get();
      final authorId = before.data()?['authorId'];
      final judul = before.data()?['judul'] ?? '';

      await _firestore.collection('announcements').doc(docId).update({
        'status': 'ditolak',
        'alasan_penolakan': alasan,
        'rejected_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: 'Menolak informasi',
          targetTipe: 'informasi',
          targetId: docId,
          detail: judul.toString(),
          alasan: alasan);
      await fetchPendingList();
      await fetchKadesQueue();
      await fetchMyRequests();

      if (authorId != null && authorId.toString().isNotEmpty) {
        try {
          await Get.find<NotificationController>().kirimKe(
            uidTujuan: authorId,
            judul: 'Pengajuan Ditolak',
            isi: '"$judul" ditolak. Alasan: $alasan',
            tipe: 'info',
            targetId: docId,
          );
        } catch (_) {}
      }
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menolak: $e';
      return false;
    }
  }

  // ─── HAPUS DRAFT ──────────────────────────────────────────
  Future<bool> hapusDraft(String docId) async {
    try {
      await _firestore.collection('announcements').doc(docId).delete();
      await fetchDraftList();
      await fetchMenungguKades();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menghapus: $e';
      return false;
    }
  }

  // ─── PERPANJANG masa berlaku (Admin & Kades) ──────────────
  // Sisa masa berlaku + tambahan bulan, total sisa maksimal 12 bulan.
  Future<bool> perpanjangInformasi(NewsModel n, {int? bulan, DateTime? sampai}) async {
    try {
      final u = _authCtrl.currentUser.value;
      if (u == null || !u.isStaff) {
        errorMsg.value = 'Hanya Admin dan Kepala Desa yang dapat memperpanjang.';
        return false;
      }
      final DateTime baru = sampai ?? hitungPerpanjang(n.berlakuSampai, bulan ?? 1);
      final lama = n.berlakuSampai;
      if (lama != null && !baru.isAfter(lama)) {
        errorMsg.value = 'Masa berlaku sudah maksimal 12 bulan dari hari ini.';
        return false;
      }
      await _firestore
          .collection('announcements')
          .doc(n.id)
          .update({'berlaku_sampai': Timestamp.fromDate(baru)});
      await AuditLog.catat(
          aksi: 'Memperpanjang masa berlaku informasi',
          targetTipe: 'informasi',
          targetId: n.id,
          detail: '${n.judul} • sampai ${AppUtils.formatTanggal(baru)}');
      await fetchPublishedNews();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memperpanjang: $e';
      return false;
    }
  }

  // ─── HAPUS INFORMASI (Admin & Kades, termasuk yang sudah tayang) ─
  Future<bool> hapusInformasi(NewsModel n) async {
    try {
      final u = _authCtrl.currentUser.value;
      if (u == null || !u.isStaff) {
        errorMsg.value = 'Hanya Admin dan Kepala Desa yang dapat menghapus informasi.';
        return false;
      }
      await _firestore.collection('announcements').doc(n.id).delete();
      await AuditLog.catat(
          aksi: 'Menghapus informasi',
          targetTipe: 'informasi',
          targetId: n.id,
          detail: n.judul);
      // Beri tahu pengaju bila bukan dirinya sendiri
      if (n.authorId.isNotEmpty && n.authorId != u.uid) {
        try {
          await Get.find<NotificationController>().kirimKe(
            uidTujuan: n.authorId,
            judul: 'Informasi Dihapus',
            isi: '"${n.judul}" telah dihapus oleh ${AppTheme.labelRole(u.role)}.',
            tipe: 'info',
          );
        } catch (_) {}
      }
      await fetchPublishedNews();
      await fetchDraftList();
      await fetchPendingList();
      await fetchKadesQueue();
      await fetchMenungguKades();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menghapus: $e';
      return false;
    }
  }

  // ─── UBAH INFORMASI (Admin & Kades) ──────────────────────
  // Admin yang mengubah isi informasi KATEGORI SENSITIF → perlu ACC ulang
  // Kepala Desa (status kembali ke pending_kades), agar Kades tetap menjadi
  // penjaga terakhir untuk kategori sensitif.
  Future<bool> editInformasi(
    NewsModel n, {
    required String judul,
    required String isi,
    required String kategori,
    required DateTime berlakuSampai,
    List<String> fotoLama = const [],
    File? fotoBaru,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final u = _authCtrl.currentUser.value;
      if (u == null || !u.isStaff) {
        errorMsg.value = 'Hanya Admin dan Kepala Desa yang dapat mengubah informasi.';
        return false;
      }
      String foto = fotoLama.isNotEmpty ? fotoLama.first : '';
      if (fotoBaru != null) {
        final enc = await _encodeFoto(fotoBaru);
        if (enc == null) return false;
        foto = enc;
      }

      final bool butuhAccUlang = u.role == 'admin' &&
          n.status == 'published' &&
          AppUtils.isKategoriSensitif(kategori);

      await _firestore.collection('announcements').doc(n.id).update({
        'judul': judul.trim(),
        'isi': isi.trim(),
        'kategori': kategori,
        'berlaku_sampai': Timestamp.fromDate(berlakuSampai),
        'foto_url': foto,
        if (butuhAccUlang) 'status': 'pending_kades',
        if (butuhAccUlang) 'published_at': null,
        'edited_at': Timestamp.fromDate(DateTime.now()),
        'edited_by': u.uid,
      });
      await AuditLog.catat(
          aksi: 'Mengubah informasi',
          targetTipe: 'informasi',
          targetId: n.id,
          detail: judul.trim() +
              (butuhAccUlang ? ' (menunggu ACC ulang Kades)' : ''));
      if (butuhAccUlang) {
        await notifPeran(['kades'],
            judul: 'Informasi Diubah — Perlu ACC Ulang',
            isi: judul.trim(),
            tipe: 'info',
            targetId: n.id);
      }
      await fetchPublishedNews();
      await fetchDraftList();
      await fetchPendingList();
      await fetchKadesQueue();
      await fetchMenungguKades();
      perluAccUlang = butuhAccUlang;
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyimpan perubahan: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── FILTER ───────────────────────────────────────────────
  List<NewsModel> get filteredNews {
    if (filterKategori.value == 'semua') return publishedNews;
    return publishedNews
        .where((n) => n.kategori == filterKategori.value)
        .toList();
  }

  void setFilter(String kategori) {
    filterKategori.value = kategori;
  }
}


// ============================================================
// service_controller.dart
// Modul Jasa Lokal Berbasis Lokasi (Elisitasi #15-22)
// - Profil penyedia lengkap: tarif, jadwal, area layanan, katalog paket
// - Verifikasi oleh Admin + kurasi (Pilihan Desa, peringatan, blokir)
// - Pencarian, filter, pengurutan (rekomendasi / jarak / rating / harga)
// - Favorit, statistik profil (dilihat, dihubungi)
// - Ulasan dari pesanan selesai (multi-aspek, balasan penyedia, moderasi)
// - Laporan jasa bermasalah
// ============================================================

class ServiceController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── Data ────────────────────────────────────────────────
  final RxList<ServiceModel> daftarAktif = <ServiceModel>[].obs;
  final RxList<ServiceModel> pendingVerifikasi = <ServiceModel>[].obs;
  final RxList<ServiceModel> semuaAdmin = <ServiceModel>[].obs;
  final Rx<ServiceModel?> punyaSaya = Rx<ServiceModel?>(null);
  final RxSet<String> favorit = <String>{}.obs;

  // ─── Pencarian & filter ──────────────────────────────────
  final RxString filterKategori = 'semua'.obs;
  final RxString kataKunci = ''.obs;
  final RxString urutan = 'rekomendasi'.obs;
  final RxBool hanyaBuka = false.obs;
  final RxBool hanyaTerverifikasi = false.obs;
  final RxBool hanyaFavorit = false.obs;
  final RxDouble ratingMin = 0.0.obs;
  final RxDouble jarakMaksKm = 0.0.obs; // 0 = bebas
  final RxInt hargaMaks = 0.obs; // 0 = bebas
  final RxString modeFilter = 'semua'.obs; // 'semua' | 'datang' | 'tempat'
  final RxBool tampilPeta = false.obs;

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;

  DateTime? _terakhirMuat;
  final Set<String> _sudahDilihat = <String>{};
  StreamSubscription<QuerySnapshot>? _subSaya;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (user) => _onUser(user));
    _onUser(_authCtrl.currentUser.value);
  }

  @override
  void onClose() {
    _subSaya?.cancel();
    super.onClose();
  }

  void _onUser(UserModel? user) {
    if (user != null) {
      fetchAktif(); // ulangi setelah login (sebelum login aturan Firestore menolak)
      _dengarkanProfilSaya(user.uid);
      fetchFavorit();
      if (user.isAdmin) fetchPendingVerifikasi();
    } else {
      _subSaya?.cancel();
      _subSaya = null;
      punyaSaya.value = null;
      pendingVerifikasi.clear();
      semuaAdmin.clear();
      favorit.clear();
      daftarAktif.clear();
    }
  }

  // ─── Profil jasa milik saya (realtime: status verifikasi langsung berubah) ─
  void _dengarkanProfilSaya(String uid) {
    _subSaya?.cancel();
    _subSaya = _firestore
        .collection('penyedia_jasa')
        .where('uid_penyedia', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      punyaSaya.value =
          snap.docs.isNotEmpty ? ServiceModel.fromFirestore(snap.docs.first) : null;
    }, onError: (e) {
      errorMsg.value = 'Gagal memuat profil jasa: $e';
    });
  }

  Future<void> fetchPunyaSaya() async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final snap = await _firestore
          .collection('penyedia_jasa')
          .where('uid_penyedia', isEqualTo: uid)
          .limit(1)
          .get();
      punyaSaya.value =
          snap.docs.isNotEmpty ? ServiceModel.fromFirestore(snap.docs.first) : null;
    } catch (e) {
      errorMsg.value = 'Gagal memuat profil jasa: $e';
    }
  }

  // ─── FETCH: semua penyedia jasa berstatus aktif ──────────
  Future<void> fetchAktif() async {
    try {
      isLoading.value = true;
      errorMsg.value = '';
      final snap = await _firestore
          .collection('penyedia_jasa')
          .where('status', isEqualTo: 'aktif')
          .get();
      daftarAktif.value =
          snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList();
      _terakhirMuat = DateTime.now();
    } catch (e) {
      errorMsg.value = 'Gagal memuat penyedia jasa: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Muat ulang hanya bila data sudah lebih tua dari [menit] (hemat kuota).
  Future<void> muatJikaLama({int menit = 3}) async {
    final t = _terakhirMuat;
    if (t == null || DateTime.now().difference(t).inMinutes >= menit) {
      await fetchAktif();
    }
  }

  Stream<ServiceModel?> jasaStream(String id) {
    return _firestore
        .collection('penyedia_jasa')
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? ServiceModel.fromFirestore(d) : null);
  }

  Future<ServiceModel?> ambilJasa(String id) async {
    try {
      final d = await _firestore.collection('penyedia_jasa').doc(id).get();
      return d.exists ? ServiceModel.fromFirestore(d) : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Hasil pencarian (filter + urutan) ───────────────────
  List<ServiceModel> get hasilCari {
    final user = _authCtrl.currentUser.value;
    final double lat = user?.lokasiLat ?? -6.239265;
    final double lng = user?.lokasiLng ?? 106.530200;

    Iterable<ServiceModel> list = daftarAktif;
    final kat = filterKategori.value;
    if (kat != 'semua') list = list.where((s) => s.kategori == kat);
    final q = kataKunci.value;
    if (q.trim().isNotEmpty) list = list.where((s) => s.cocokKata(q));
    if (hanyaBuka.value) list = list.where((s) => s.sedangBuka);
    if (hanyaTerverifikasi.value) list = list.where((s) => s.ktpOk);
    if (hanyaFavorit.value) list = list.where((s) => favorit.contains(s.id));
    final rMin = ratingMin.value;
    if (rMin > 0) {
      list = list.where((s) => s.ratingCount > 0 && s.ratingAvg >= rMin);
    }
    final mode = modeFilter.value;
    if (mode != 'semua') {
      list = list.where((s) => s.modeLayanan == 'keduanya' || s.modeLayanan == mode);
    }
    final hMaks = hargaMaks.value;
    if (hMaks > 0) {
      list = list.where((s) => s.tarifMulai > 0 && s.tarifMulai <= hMaks);
    }

    final hasil = list.toList();
    for (final s in hasil) {
      s.jarakKm = AppUtils.hitungJarak(lat, lng, s.lokasiLat, s.lokasiLng);
    }
    final jMaks = jarakMaksKm.value;
    if (jMaks > 0) {
      hasil.removeWhere((s) => (s.jarakKm ?? 0) > jMaks);
    }

    switch (urutan.value) {
      case 'terdekat':
        hasil.sort((a, b) => (a.jarakKm ?? 9999).compareTo(b.jarakKm ?? 9999));
        break;
      case 'rating':
        hasil.sort((a, b) {
          final c = b.ratingTerbobot.compareTo(a.ratingTerbobot);
          return c != 0 ? c : b.ratingCount.compareTo(a.ratingCount);
        });
        break;
      case 'terlaris':
        hasil.sort((a, b) => b.pesananSelesai.compareTo(a.pesananSelesai));
        break;
      case 'termurah':
        hasil.sort((a, b) {
          final ha = a.tarifMulai <= 0 ? 1 << 40 : a.tarifMulai;
          final hb = b.tarifMulai <= 0 ? 1 << 40 : b.tarifMulai;
          return ha.compareTo(hb);
        });
        break;
      case 'terbaru':
        hasil.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      default: // rekomendasi
        hasil.sort((a, b) => b.skorRekomendasi.compareTo(a.skorRekomendasi));
    }
    return hasil;
  }

  /// Jumlah filter lanjutan yang sedang aktif (untuk badge tombol filter)
  int get jumlahFilterAktif {
    int n = 0;
    if (hanyaBuka.value) n++;
    if (hanyaTerverifikasi.value) n++;
    if (hanyaFavorit.value) n++;
    if (ratingMin.value > 0) n++;
    if (jarakMaksKm.value > 0) n++;
    if (hargaMaks.value > 0) n++;
    if (modeFilter.value != 'semua') n++;
    return n;
  }

  void setFilter(String kategori) => filterKategori.value = kategori;

  void resetFilter() {
    hanyaBuka.value = false;
    hanyaTerverifikasi.value = false;
    hanyaFavorit.value = false;
    ratingMin.value = 0;
    jarakMaksKm.value = 0;
    hargaMaks.value = 0;
    modeFilter.value = 'semua';
  }

  // ─── Favorit (disimpan di dokumen pengguna) ──────────────
  Future<void> fetchFavorit() async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      final raw = doc.data()?['favorit_jasa'];
      favorit.clear();
      if (raw is List) favorit.addAll(raw.map((e) => '$e'));
    } catch (_) {}
  }

  Future<void> toggleFavorit(ServiceModel s) async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    final bool ada = favorit.contains(s.id);
    if (ada) {
      favorit.remove(s.id);
    } else {
      favorit.add(s.id);
    }
    try {
      await _firestore.collection('users').doc(uid).update({
        'favorit_jasa': ada
            ? FieldValue.arrayRemove([s.id])
            : FieldValue.arrayUnion([s.id]),
      });
    } catch (e) {
      if (ada) {
        favorit.add(s.id);
      } else {
        favorit.remove(s.id);
      }
      errorMsg.value = 'Gagal menyimpan favorit: $e';
    }
  }

  // ─── Statistik profil: dilihat & dihubungi ───────────────
  Future<void> catatDilihat(ServiceModel s) async {
    final u = _authCtrl.currentUser.value;
    if (u == null || u.isStaff || s.uidPenyedia == u.uid) return;
    if (!_sudahDilihat.add(s.id)) return; // sekali per sesi
    try {
      await _firestore
          .collection('penyedia_jasa')
          .doc(s.id)
          .update({'dilihat': FieldValue.increment(1)});
    } catch (_) {}
  }

  Future<void> catatDihubungi(ServiceModel s) async {
    final u = _authCtrl.currentUser.value;
    if (u == null || u.isStaff || s.uidPenyedia == u.uid) return;
    try {
      await _firestore
          .collection('penyedia_jasa')
          .doc(s.id)
          .update({'dihubungi': FieldValue.increment(1)});
    } catch (_) {}
  }

  // ─── Portofolio (subkoleksi, dimuat hanya di halaman detail) ─
  Future<List<PortofolioFoto>> muatPortofolio(String serviceId) async {
    try {
      final snap = await _firestore
          .collection('penyedia_jasa')
          .doc(serviceId)
          .collection('portofolio')
          .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final ta = (a.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb);
      });
      return docs
          .map((d) => PortofolioFoto(id: d.id, foto: '${d.data()['foto'] ?? ''}'))
          .where((p) => p.foto.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Miniatur kecil untuk kartu daftar (≈ ≤45 KB) dari foto pertama.
  Future<String?> _buatSampul(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final awal = img.decodeImage(bytes);
      if (awal == null) return null;
      img.Image g = awal;
      if (g.width > 420) g = img.copyResize(g, width: 420);
      var out = img.encodeJpg(g, quality: 60);
      if (out.length > 45 * 1024) {
        g = img.copyResize(g, width: 320);
        out = img.encodeJpg(g, quality: 50);
      }
      return 'data:image/jpeg;base64,${base64Encode(out)}';
    } catch (_) {
      return null;
    }
  }

  // ─── SIMPAN profil jasa (daftar baru / edit) ─────────────
  Future<bool> simpanProfil({
    ServiceModel? existing,
    required ProfilJasaInput input,
    List<File> fotoBaru = const [],
    List<String> idPortofolioHapus = const [],
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final user = _authCtrl.currentUser.value;
      if (user == null) return false;
      final cmp = Get.find<ComplaintController>();
      await cmp.fetchMyKtp();

      if (existing == null && !cmp.ktpOk) {
        errorMsg.value = 'need_verified'.tr;
        return false;
      }
      if (existing != null && existing.diblokir) {
        errorMsg.value = 'Profil jasa Anda diblokir Admin dan tidak dapat diubah.';
        return false;
      }
      if (existing == null && punyaSaya.value != null) {
        errorMsg.value = 'Anda sudah memiliki profil jasa.';
        return false;
      }

      final List<String> encoded = [];
      for (final f in fotoBaru) {
        final d = await ImageUtil.encode(f);
        if (d == null) throw 'Foto terlalu besar, pilih foto lain.';
        encoded.add(d);
      }
      String? sampul;
      if (encoded.isNotEmpty && (existing == null || existing.fotoSampul.isEmpty)) {
        sampul = await _buatSampul(fotoBaru.first);
      }

      final now = Timestamp.fromDate(DateTime.now());

      if (existing == null) {
        final data = input.toMap();
        data.addAll({
          'uid_penyedia': user.uid,
          'nama_penyedia': user.nama,
          'foto_url': user.fotoUrl,
          'foto_sampul': sampul ?? '',
          'status': 'pending',
          'alasan_penolakan': null,
          'dikunci': false,
          'ktp_ok': cmp.ktpOk,
          'rating_avg': 0.0,
          'rating_count': 0,
          'rating_dist': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
          'aspek_sum': {'kualitas': 0.0, 'ketepatan': 0.0, 'komunikasi': 0.0},
          'aspek_n': 0,
          'ketersediaan': 'buka',
          'ketersediaan_catatan': '',
          'tutup_sampai': null,
          'penuh_otomatis': false,
          'unggulan': false,
          'peringatan': 0,
          'dilihat': 0,
          'dihubungi': 0,
          'pesanan_total': 0,
          'pesanan_selesai': 0,
          'created_at': now,
          'diperbarui_at': now,
        });
        final ref = _firestore.collection('penyedia_jasa').doc();
        await ref.set(data);
        await _tulisPortofolio(ref.id, encoded, const []);
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'isPenyediaJasa': true});
        await notifPeran(['admin'],
            judul: 'Pengajuan Jasa Baru',
            isi:
                '${user.nama} mendaftar sebagai penyedia jasa (${AppUtils.labelKategoriJasa(input.kategori)}).',
            tipe: 'jasa',
            targetId: ref.id);
        return true;
      }

      // ── Edit ──
      final updates = input.toMap();
      updates['nama_penyedia'] = user.nama;
      updates['foto_url'] = user.fotoUrl;
      updates['diperbarui_at'] = now;
      if (existing.ktpOk != cmp.ktpOk) updates['ktp_ok'] = cmp.ktpOk;
      if (sampul != null) updates['foto_sampul'] = sampul;

      // Perubahan mendasar (kategori / pindah lokasi > 300 m) → verifikasi ulang
      final bool kategoriBerubah = existing.kategori != input.kategori;
      final double geser = AppUtils.hitungJarak(
          existing.lokasiLat, existing.lokasiLng, input.lat, input.lng);
      final bool perluVerifikasi = kategoriBerubah || geser > 0.3;
      bool jadiPending = false;
      if (existing.status == 'ditolak' ||
          (existing.status == 'aktif' && perluVerifikasi)) {
        updates['status'] = 'pending';
        updates['alasan_penolakan'] = null;
        jadiPending = true;
      }

      await _firestore
          .collection('penyedia_jasa')
          .doc(existing.id)
          .update(updates);
      await _tulisPortofolio(existing.id, encoded, idPortofolioHapus);
      if (jadiPending) {
        await notifPeran(['admin'],
            judul: 'Profil Jasa Perlu Verifikasi Ulang',
            isi: '${user.nama} mengubah data utama profil jasanya.',
            tipe: 'jasa',
            targetId: existing.id);
        await fetchAktif();
      }
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyimpan profil jasa: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _tulisPortofolio(
      String serviceId, List<String> baru, List<String> hapusIds) async {
    if (baru.isEmpty && hapusIds.isEmpty) return;
    final col = _firestore
        .collection('penyedia_jasa')
        .doc(serviceId)
        .collection('portofolio');
    final batch = _firestore.batch();
    for (final id in hapusIds) {
      batch.delete(col.doc(id));
    }
    for (final foto in baru) {
      batch.set(col.doc(), {
        'foto': foto,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  // ─── Aktif / nonaktif oleh pemilik ───────────────────────
  Future<bool> toggleAktifNonaktif(ServiceModel s, bool aktifkan) async {
    try {
      if (s.dikunci || s.diblokir) {
        errorMsg.value =
            'Profil jasa dikunci Admin. Hubungi Admin desa untuk mengaktifkan kembali.';
        return false;
      }
      if (s.status != 'aktif' && s.status != 'nonaktif') {
        errorMsg.value = 'Profil belum disetujui Admin.';
        return false;
      }
      await _firestore.collection('penyedia_jasa').doc(s.id).update({
        'status': aktifkan ? 'aktif' : 'nonaktif',
        'diperbarui_at': Timestamp.fromDate(DateTime.now()),
      });
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengubah status: $e';
      return false;
    }
  }

  // ─── SAKLAR KETERSEDIAAN: Buka / Penuh / Tutup ───────────
  Future<bool> setKetersediaan(
    String docId, {
    required String status, // 'buka' | 'penuh' | 'tutup'
    String catatan = '',
    DateTime? tutupSampai,
  }) async {
    try {
      await _firestore.collection('penyedia_jasa').doc(docId).update({
        'ketersediaan': status,
        'ketersediaan_catatan': status == 'buka' ? '' : catatan.trim(),
        'tutup_sampai': (status == 'buka' || tutupSampai == null)
            ? null
            : Timestamp.fromDate(tutupSampai),
        'penuh_otomatis': false,
        'ketersediaan_diubah': Timestamp.fromDate(DateTime.now()),
      });
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengubah ketersediaan: $e';
      return false;
    }
  }

  Future<bool> setTanggalLibur(String docId, List<DateTime> tanggal) async {
    try {
      final unik = <String, DateTime>{};
      for (final d in tanggal) {
        final t = DateTime(d.year, d.month, d.day);
        unik['${t.year}-${t.month}-${t.day}'] = t;
      }
      final list = unik.values.toList()..sort();
      await _firestore.collection('penyedia_jasa').doc(docId).update({
        'tanggal_libur': list.map((d) => Timestamp.fromDate(d)).toList(),
      });
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyimpan tanggal libur: $e';
      return false;
    }
  }

  // ─── ADMIN: antrean verifikasi, semua jasa, kurasi ───────
  Future<void> fetchPendingVerifikasi() async {
    try {
      final snap = await _firestore
          .collection('penyedia_jasa')
          .where('status', isEqualTo: 'pending')
          .get();
      final list = snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      pendingVerifikasi.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat antrean verifikasi: $e';
    }
  }

  Future<void> fetchSemuaAdmin() async {
    try {
      final snap = await _firestore.collection('penyedia_jasa').get();
      final list = snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      semuaAdmin.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat daftar jasa: $e';
    }
  }

  Future<bool> verifikasi(
    String docId,
    String uidPemilik, {
    required bool setuju,
    String? alasan,
  }) async {
    try {
      await _firestore.collection('penyedia_jasa').doc(docId).update({
        'status': setuju ? 'aktif' : 'ditolak',
        'alasan_penolakan': setuju ? null : (alasan ?? ''),
        'dikunci': false,
        'diverifikasi_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: setuju ? 'Menyetujui profil jasa' : 'Menolak profil jasa',
          targetTipe: 'jasa',
          targetId: docId,
          detail: uidPemilik,
          alasan: setuju ? '' : (alasan ?? ''));
      await fetchPendingVerifikasi();
      await fetchAktif();
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: uidPemilik,
        judul: setuju ? 'Profil Jasa Disetujui 🎉' : 'Profil Jasa Ditolak',
        isi: setuju
            ? 'Selamat! Profil jasa Anda kini tampil di pencarian warga.'
            : 'Profil jasa Anda ditolak Admin. Alasan: ${alasan ?? '-'}',
        tipe: 'jasa',
        targetId: docId,
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memverifikasi: $e';
      return false;
    }
  }

  /// Admin mengubah status: 'aktif' | 'nonaktif' | 'diblokir'
  Future<bool> setStatusAdmin(ServiceModel s, String status,
      {String alasan = ''}) async {
    try {
      await _firestore.collection('penyedia_jasa').doc(s.id).update({
        'status': status,
        'alasan_penolakan': status == 'aktif' ? null : alasan,
        'dikunci': status != 'aktif',
        'diperbarui_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: status == 'aktif'
              ? 'Mengaktifkan jasa'
              : status == 'diblokir'
                  ? 'Memblokir jasa'
                  : 'Menonaktifkan jasa',
          targetTipe: 'jasa',
          targetId: s.id,
          detail: s.nama,
          alasan: alasan);
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: s.uidPenyedia,
        judul: status == 'aktif'
            ? 'Profil Jasa Diaktifkan'
            : status == 'diblokir'
                ? 'Profil Jasa Diblokir'
                : 'Profil Jasa Dinonaktifkan Admin',
        isi: status == 'aktif'
            ? 'Profil jasa Anda kembali tampil di pencarian warga.'
            : 'Alasan: ${alasan.isEmpty ? '-' : alasan}. Hubungi Admin desa bila keberatan.',
        tipe: 'jasa',
        targetId: s.id,
      );
      await fetchSemuaAdmin();
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengubah status jasa: $e';
      return false;
    }
  }

  Future<bool> setUnggulan(ServiceModel s, bool unggulan) async {
    try {
      await _firestore
          .collection('penyedia_jasa')
          .doc(s.id)
          .update({'unggulan': unggulan});
      await AuditLog.catat(
          aksi: unggulan ? 'Menetapkan Pilihan Desa' : 'Mencabut Pilihan Desa',
          targetTipe: 'jasa',
          targetId: s.id,
          detail: s.nama);
      if (unggulan) {
        await Get.find<NotificationController>().kirimKe(
          uidTujuan: s.uidPenyedia,
          judul: 'Jasa Anda jadi Pilihan Desa ⭐',
          isi: 'Admin desa menetapkan jasa Anda sebagai Pilihan Desa.',
          tipe: 'jasa',
          targetId: s.id,
        );
      }
      await fetchSemuaAdmin();
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengubah Pilihan Desa: $e';
      return false;
    }
  }

  // ─── ULASAN ───────────────────────────────────────────────
  Stream<List<ReviewModel>> reviewsStream(String serviceId) {
    return _firestore
        .collection('penyedia_jasa')
        .doc(serviceId)
        .collection('reviews')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ReviewModel.fromFirestore(d)).toList());
  }

  /// Ulasan hanya untuk pesanan yang sudah SELESAI (1 ulasan per pesanan).
  Future<bool> kirimUlasan(
    OrderModel o, {
    required int rating,
    required Map<String, int> aspek,
    required String komentar,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final user = _authCtrl.currentUser.value;
      if (user == null || user.uid != o.uidPemesan) return false;
      if (o.status != 'selesai') {
        errorMsg.value = 'Ulasan hanya bisa diberikan setelah pesanan selesai.';
        return false;
      }
      final svcRef = _firestore.collection('penyedia_jasa').doc(o.serviceId);
      final revRef = svcRef.collection('reviews').doc(o.id);
      final ordRef = _firestore.collection('pesanan_jasa').doc(o.id);

      await _firestore.runTransaction((tx) async {
        final svc = await tx.get(svcRef);
        final ord = await tx.get(ordRef);
        final rv = await tx.get(revRef);
        final dOrd = (ord.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        if (rv.exists || dOrd['sudah_diulas'] == true) {
          throw 'Anda sudah memberi ulasan untuk pesanan ini.';
        }
        final d = (svc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        final double avgLama = (d['rating_avg'] ?? 0.0).toDouble();
        final int countLama = ((d['rating_count'] ?? 0) as num).toInt();
        final double avgBaru = ((avgLama * countLama) + rating) / (countLama + 1);

        final dist = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
        final rawD = d['rating_dist'];
        if (rawD is Map) {
          rawD.forEach((k, v) {
            if (v is num) dist['$k'] = v.toInt();
          });
        }
        dist['$rating'] = (dist['$rating'] ?? 0) + 1;

        final asp = <String, double>{
          'kualitas': 0,
          'ketepatan': 0,
          'komunikasi': 0
        };
        final rawA = d['aspek_sum'];
        if (rawA is Map) {
          rawA.forEach((k, v) {
            if (v is num) asp['$k'] = v.toDouble();
          });
        }
        for (final k in asp.keys.toList()) {
          asp[k] = (asp[k] ?? 0.0) + (aspek[k] ?? rating).toDouble();
        }
        final int aspekN = ((d['aspek_n'] ?? 0) as num).toInt() + 1;

        tx.set(revRef, {
          'id_pengguna': user.uid,
          'nama_pengguna': user.nama,
          'rating': rating,
          'aspek': {
            'kualitas': aspek['kualitas'] ?? rating,
            'ketepatan': aspek['ketepatan'] ?? rating,
            'komunikasi': aspek['komunikasi'] ?? rating,
          },
          'komentar': komentar.trim(),
          'balasan': '',
          'tampil': true,
          'order_id': o.id,
          'nama_layanan': o.namaLayanan,
          'created_at': Timestamp.fromDate(DateTime.now()),
        });
        tx.update(svcRef, {
          'rating_avg': double.parse(avgBaru.toStringAsFixed(2)),
          'rating_count': countLama + 1,
          'rating_dist': dist,
          'aspek_sum': asp,
          'aspek_n': aspekN,
        });
        tx.update(ordRef, {'sudah_diulas': true});
      });

      await Get.find<NotificationController>().kirimKe(
        uidTujuan: o.uidPenyedia,
        judul: 'Ulasan Baru ⭐',
        isi: '${user.nama} memberi rating $rating untuk "${o.namaLayanan}".',
        tipe: 'pesanan',
        targetId: o.id,
      );
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim ulasan: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> balasUlasan(String serviceId, ReviewModel r, String teks) async {
    try {
      await _firestore
          .collection('penyedia_jasa')
          .doc(serviceId)
          .collection('reviews')
          .doc(r.id)
          .update({
        'balasan': teks.trim(),
        'balasan_at': Timestamp.fromDate(DateTime.now()),
      });
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: r.idPengguna,
        judul: 'Penyedia membalas ulasan Anda',
        isi: teks.trim(),
        tipe: 'jasa',
        targetId: serviceId,
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim balasan: $e';
      return false;
    }
  }

  /// Admin: sembunyikan / tampilkan ulasan (rating dihitung ulang).
  Future<bool> setUlasanTampil(String serviceId, ReviewModel r, bool tampil,
      {String alasan = ''}) async {
    try {
      await _firestore
          .collection('penyedia_jasa')
          .doc(serviceId)
          .collection('reviews')
          .doc(r.id)
          .update({'tampil': tampil});
      await hitungUlangRating(serviceId);
      await AuditLog.catat(
          aksi: tampil ? 'Menampilkan ulasan jasa' : 'Menyembunyikan ulasan jasa',
          targetTipe: 'jasa',
          targetId: serviceId,
          detail: '${r.namaPengguna}: ${r.komentar}',
          alasan: alasan);
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memoderasi ulasan: $e';
      return false;
    }
  }

  Future<void> hitungUlangRating(String serviceId) async {
    final svcRef = _firestore.collection('penyedia_jasa').doc(serviceId);
    final snap = await svcRef.collection('reviews').get();
    double jumlah = 0;
    int n = 0;
    final dist = <String, int>{'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
    final asp = <String, double>{'kualitas': 0, 'ketepatan': 0, 'komunikasi': 0};
    for (final d in snap.docs) {
      final r = ReviewModel.fromFirestore(d);
      if (!r.tampil) continue;
      n++;
      jumlah += r.rating;
      dist['${r.rating}'] = (dist['${r.rating}'] ?? 0) + 1;
      for (final k in asp.keys.toList()) {
        asp[k] = (asp[k] ?? 0.0) + (r.aspek[k] ?? r.rating).toDouble();
      }
    }
    await svcRef.update({
      'rating_avg': n == 0 ? 0.0 : double.parse((jumlah / n).toStringAsFixed(2)),
      'rating_count': n,
      'rating_dist': dist,
      'aspek_sum': asp,
      'aspek_n': n,
    });
  }

  // ─── LAPOR JASA BERMASALAH ────────────────────────────────
  Future<bool> laporkanJasa(
    ServiceModel s, {
    required String jenis,
    required String alasan,
    String orderId = '',
  }) async {
    final user = _authCtrl.currentUser.value;
    if (user == null) return false;
    try {
      // id tetap = satu pelapor satu laporan per jasa (anti-spam)
      final id = '${s.id}_${user.uid}';
      await _firestore.collection('laporan_jasa').doc(id).set({
        'service_id': s.id,
        'nama_penyedia': s.nama,
        'uid_penyedia': s.uidPenyedia,
        'uid_pelapor': user.uid,
        'nama_pelapor': user.nama,
        'jenis': jenis,
        'alasan': alasan.trim(),
        'order_id': orderId,
        'status': 'baru',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      await notifPeran(['admin'],
          judul: 'Laporan Jasa Bermasalah',
          isi:
              '${s.nama}: ${ServiceReportModel.jenisLabel[jenis] ?? jenis}',
          tipe: 'jasa',
          targetId: s.id);
      return true;
    } on FirebaseException catch (e) {
      errorMsg.value = e.code == 'permission-denied'
          ? 'Anda sudah melaporkan jasa ini. Laporan sedang atau sudah ditinjau Admin.'
          : 'Gagal mengirim laporan: ${e.message}';
      return false;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim laporan: $e';
      return false;
    }
  }

  Stream<List<ServiceReportModel>> laporanStream() {
    return _firestore
        .collection('laporan_jasa')
        .where('status', isEqualTo: 'baru')
        .snapshots()
        .map((s) {
      final list =
          s.docs.map((d) => ServiceReportModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Admin menindaklanjuti laporan.
  /// [tindakan]: 'abaikan' | 'peringatan' | 'nonaktif' | 'blokir'
  Future<bool> tindakLaporan(ServiceReportModel r,
      {required String tindakan, String catatan = ''}) async {
    try {
      final svcRef = _firestore.collection('penyedia_jasa').doc(r.serviceId);
      final notif = Get.find<NotificationController>();
      final alasanTeks = r.labelJenis;

      if (tindakan == 'peringatan') {
        final snap = await svcRef.get();
        final int n = ((snap.data()?['peringatan'] ?? 0) as num).toInt() + 1;
        final upd = <String, dynamic>{'peringatan': n};
        if (n >= 3) {
          upd['status'] = 'nonaktif';
          upd['dikunci'] = true;
          upd['alasan_penolakan'] = 'Dinonaktifkan otomatis setelah 3 peringatan.';
        }
        await svcRef.update(upd);
        await notif.kirimKe(
          uidTujuan: r.uidPenyedia,
          judul: 'Peringatan dari Admin ($n/3)',
          isi:
              'Ada laporan warga: $alasanTeks. ${catatan.isEmpty ? '' : 'Catatan: $catatan. '}${n >= 3 ? 'Jasa Anda dinonaktifkan karena sudah 3 peringatan.' : 'Setelah 3 peringatan jasa Anda akan dinonaktifkan.'}',
          tipe: 'jasa',
          targetId: r.serviceId,
        );
      } else if (tindakan == 'nonaktif' || tindakan == 'blokir') {
        await svcRef.update({
          'status': tindakan == 'blokir' ? 'diblokir' : 'nonaktif',
          'dikunci': true,
          'alasan_penolakan':
              catatan.isEmpty ? 'Laporan warga: $alasanTeks' : catatan,
        });
        await notif.kirimKe(
          uidTujuan: r.uidPenyedia,
          judul: tindakan == 'blokir'
              ? 'Profil Jasa Diblokir'
              : 'Jasa Dinonaktifkan Admin',
          isi:
              'Karena laporan warga: $alasanTeks. Hubungi Admin desa bila keberatan.',
          tipe: 'jasa',
          targetId: r.serviceId,
        );
        await fetchAktif();
      }

      await _firestore.collection('laporan_jasa').doc(r.id).update({
        'status': 'selesai',
        'tindakan': tindakan,
        'catatan_admin': catatan.trim(),
        'ditangani_at': Timestamp.fromDate(DateTime.now()),
      });
      if (r.uidPelapor.isNotEmpty) {
        await notif.kirimKe(
          uidTujuan: r.uidPelapor,
          judul: 'Laporan Anda sudah ditinjau',
          isi: 'Terima kasih. Admin telah menindaklanjuti laporan Anda tentang ${r.namaPenyedia}.',
          tipe: 'jasa',
          targetId: r.serviceId,
        );
      }
      await AuditLog.catat(
          aksi: 'Menindak laporan jasa ($tindakan)',
          targetTipe: 'jasa',
          targetId: r.serviceId,
          detail: '${r.namaPenyedia} • ${r.alasan}',
          alasan: catatan);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memproses laporan: $e';
      return false;
    }
  }
}


// ============================================================
// order_controller.dart
// Pesanan Jasa — dari permintaan warga sampai selesai + ulasan.
//   menunggu → (nego) → diterima → dikerjakan → menunggu_konfirmasi
//   → selesai.  Cabang: ditolak, dibatalkan.
// Realtime lewat snapshot Firestore (gratis), notifikasi dalam aplikasi
// di setiap perubahan status. Pembayaran dilakukan langsung (di luar app).
// ============================================================

class OrderController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  /// Pesanan masuk (saya sebagai penyedia)
  final RxList<OrderModel> masuk = <OrderModel>[].obs;

  /// Pesanan saya (saya sebagai pemesan)
  final RxList<OrderModel> keluar = <OrderModel>[].obs;

  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;

  StreamSubscription<QuerySnapshot>? _subMasuk;
  StreamSubscription<QuerySnapshot>? _subKeluar;
  bool _sinkronBerjalan = false;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (user) => _onUser(user));
    // kapasitas dicek lagi bila profil jasa saya berubah
    ever(Get.find<ServiceController>().punyaSaya, (_) => _sinkronKapasitas());
    _onUser(_authCtrl.currentUser.value);
  }

  @override
  void onClose() {
    _subMasuk?.cancel();
    _subKeluar?.cancel();
    super.onClose();
  }

  void _onUser(UserModel? user) {
    _subMasuk?.cancel();
    _subKeluar?.cancel();
    _subMasuk = null;
    _subKeluar = null;
    if (user == null || user.isStaff) {
      masuk.clear();
      keluar.clear();
      return;
    }
    _subMasuk = _firestore
        .collection('pesanan_jasa')
        .where('uid_penyedia', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
      masuk.value = _urut(snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
      _sinkronKapasitas();
    }, onError: (e) {
      errorMsg.value = 'Gagal memuat pesanan masuk: $e';
    });
    _subKeluar = _firestore
        .collection('pesanan_jasa')
        .where('uid_pemesan', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
      keluar.value = _urut(snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
    }, onError: (e) {
      errorMsg.value = 'Gagal memuat pesanan saya: $e';
    });
  }

  List<OrderModel> _urut(List<OrderModel> l) {
    l.sort((a, b) => (b.diperbaruiAt ?? b.createdAt)
        .compareTo(a.diperbaruiAt ?? a.createdAt));
    return l;
  }

  // ─── Badge & ringkasan ───────────────────────────────────
  int get badgePenyedia => masuk.where((o) => o.perluTindakanPenyedia).length;
  int get badgePemesan => keluar.where((o) => o.perluTindakanPemesan).length;
  int get badgeTotal => badgePenyedia + badgePemesan;

  int get jumlahBaru => masuk.where((o) => o.status == 'menunggu').length;
  int get jumlahBerjalan => masuk
      .where((o) =>
          o.status == 'diterima' ||
          o.status == 'dikerjakan' ||
          o.status == 'nego' ||
          o.status == 'menunggu_konfirmasi')
      .length;

  bool _bulanIni(DateTime? t) {
    if (t == null) return false;
    final n = DateTime.now();
    return t.year == n.year && t.month == n.month;
  }

  int get selesaiBulanIni => masuk
      .where((o) => o.status == 'selesai' && _bulanIni(o.selesaiAt ?? o.diperbaruiAt))
      .length;

  int get pendapatanBulanIni => masuk
      .where((o) => o.status == 'selesai' && _bulanIni(o.selesaiAt ?? o.diperbaruiAt))
      .fold<int>(0, (a, o) => a + o.biayaAkhir);

  Stream<OrderModel?> pesananStream(String id) {
    return _firestore
        .collection('pesanan_jasa')
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? OrderModel.fromFirestore(d) : null);
  }

  Future<OrderModel?> _segar(String id) async {
    try {
      final d = await _firestore.collection('pesanan_jasa').doc(id).get();
      return d.exists ? OrderModel.fromFirestore(d) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _notif(String uid, String judul, String isi, String orderId) async {
    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: uid,
        judul: judul,
        isi: isi,
        tipe: 'pesanan',
        targetId: orderId,
      );
    } catch (_) {}
  }

  // ─── 1. BUAT PESANAN (warga) ─────────────────────────────
  Future<OrderModel?> buatPesanan({
    required ServiceModel s,
    PaketJasa? paket,
    required String namaLayanan,
    required int jumlah,
    required String deskripsi,
    required List<File> foto,
    required DateTime tanggal,
    required String jam,
    required String mode,
    required String alamat,
    required double lat,
    required double lng,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final user = _authCtrl.currentUser.value;
      if (user == null) return null;
      if (s.uidPenyedia == user.uid) {
        errorMsg.value = 'Anda tidak bisa memesan jasa sendiri.';
        return null;
      }
      final tgl = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final alasan = s.alasanTidakBisaDipesan(tgl);
      if (alasan != null) {
        errorMsg.value = alasan;
        return null;
      }
      // Anti-spam: maksimal 3 pesanan menunggu, 1 per penyedia
      final menunggu = keluar.where((o) => o.status == 'menunggu').toList();
      if (menunggu.length >= 3) {
        errorMsg.value =
            'Anda masih punya 3 pesanan yang belum dijawab penyedia. Tunggu dijawab atau batalkan dulu.';
        return null;
      }
      if (menunggu.any((o) => o.serviceId == s.id)) {
        errorMsg.value =
            'Pesanan Anda ke penyedia ini masih menunggu jawaban. Tunggu atau batalkan dulu.';
        return null;
      }

      final List<String> fotoEnc = [];
      for (final f in foto.take(2)) {
        final d = await ImageUtil.encode(f);
        if (d == null) throw 'Foto terlalu besar, pilih foto lain.';
        fotoEnc.add(d);
      }

      final int harga = paket?.harga ?? 0;
      final int estimasi = harga * jumlah;
      final now = DateTime.now();
      final ref = _firestore.collection('pesanan_jasa').doc();
      await ref.set({
        'service_id': s.id,
        'uid_penyedia': s.uidPenyedia,
        'nama_penyedia': s.nama,
        'uid_pemesan': user.uid,
        'nama_pemesan': user.nama,
        'telp_pemesan': user.nomorTelepon,
        'kategori': s.kategori,
        'nama_layanan': namaLayanan,
        'paket_id': paket?.id ?? '',
        'harga': harga,
        'satuan': paket?.satuan ?? '',
        'jumlah': jumlah,
        'estimasi_biaya': estimasi,
        'deskripsi': deskripsi.trim(),
        'foto': fotoEnc,
        'tanggal': Timestamp.fromDate(tgl),
        'jam': jam,
        'mode': mode,
        'alamat': alamat.trim(),
        'lat': lat,
        'lng': lng,
        'status': 'menunggu',
        'harga_final': null,
        'tanggal_final': null,
        'catatan_penyedia': '',
        'alasan_batal': '',
        'dibatalkan_oleh': '',
        'lunas': false,
        'sudah_diulas': false,
        'log': [
          {
            'status': 'menunggu',
            'waktu': Timestamp.fromDate(now),
            'oleh': user.nama,
            'catatan': 'Pesanan dikirim',
          }
        ],
        'created_at': Timestamp.fromDate(now),
        'diperbarui_at': Timestamp.fromDate(now),
      });

      try {
        await _firestore
            .collection('penyedia_jasa')
            .doc(s.id)
            .update({'pesanan_total': FieldValue.increment(1)});
      } catch (_) {}

      await _notif(
        s.uidPenyedia,
        'Pesanan Baru 📦',
        '${user.nama} memesan "$namaLayanan" untuk ${AppUtils.formatTanggal(tgl)}.',
        ref.id,
      );

      // Ringkasan pesanan otomatis masuk ke obrolan (tanpa notifikasi ganda)
      try {
        final chat = Get.find<ChatController>();
        final room = await chat.bukaAtauBuatRoom(
          otherUid: s.uidPenyedia,
          otherNama: s.namaPenyedia,
          otherFoto: s.fotoUrl,
        );
        final teks = '📦 Pesanan baru: $namaLayanan'
            '${jumlah > 1 ? ' ×$jumlah' : ''}\n'
            'Tanggal: ${AppUtils.formatTanggal(tgl)}${jam.isEmpty ? '' : ' • $jam'}\n'
            '${mode == 'datang' ? 'Lokasi: ${alamat.trim()}' : 'Di tempat penyedia'}'
            '${deskripsi.trim().isEmpty ? '' : '\nKebutuhan: ${deskripsi.trim()}'}';
        await chat.kirimPesan(room.id, teks,
            otherUid: s.uidPenyedia, notif: false);
      } catch (_) {}

      return await _segar(ref.id);
    } catch (e) {
      errorMsg.value = 'Gagal membuat pesanan: $e';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── Pembantu perubahan status ───────────────────────────
  /// Ubah status dengan syarat status sekarang [dariStatus] (hindari tabrakan
  /// bila dua pihak menekan tombol hampir bersamaan).
  Future<bool> _ubah(
    OrderModel o,
    List<String> dariStatus,
    String statusBaru, {
    Map<String, dynamic> extra = const {},
    String catatan = '',
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final user = _authCtrl.currentUser.value;
      if (user == null) return false;
      final terkini = await _segar(o.id);
      if (terkini == null) {
        errorMsg.value = 'Pesanan tidak ditemukan.';
        return false;
      }
      if (!dariStatus.contains(terkini.status)) {
        errorMsg.value =
            'Status pesanan sudah berubah menjadi "${OrderModel.labelStatus(terkini.status)}". Muat ulang.';
        return false;
      }
      final now = DateTime.now();
      final data = <String, dynamic>{
        'status': statusBaru,
        'diperbarui_at': Timestamp.fromDate(now),
        'log': FieldValue.arrayUnion([
          {
            'status': statusBaru,
            'waktu': Timestamp.fromDate(now),
            'oleh': user.nama,
            'catatan': catatan,
          }
        ]),
      };
      data.addAll(extra);
      await _firestore.collection('pesanan_jasa').doc(o.id).update(data);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memperbarui pesanan: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── 2. PENYEDIA: terima / ajukan penawaran / tolak ──────
  /// Terima pesanan. Bila harga atau tanggal diubah → jadi penawaran (nego)
  /// yang harus disetujui pemesan lebih dulu.
  Future<bool> terima(
    OrderModel o, {
    int? hargaBaru,
    DateTime? tanggalBaru,
    String catatan = '',
  }) async {
    final bool hargaBeda = hargaBaru != null && hargaBaru != o.estimasiBiaya;
    final bool tglBeda = tanggalBaru != null &&
        !(tanggalBaru.year == o.tanggal.year &&
            tanggalBaru.month == o.tanggal.month &&
            tanggalBaru.day == o.tanggal.day);
    final int? hargaFinal = hargaBaru ?? (o.estimasiBiaya > 0 ? o.estimasiBiaya : null);

    if (hargaBeda || tglBeda || (o.estimasiBiaya == 0 && hargaBaru != null)) {
      final tglFinal = tanggalBaru ?? o.tanggal;
      final ok = await _ubah(o, ['menunggu'], 'nego',
          extra: {
            'harga_final': hargaFinal,
            'tanggal_final': Timestamp.fromDate(
                DateTime(tglFinal.year, tglFinal.month, tglFinal.day)),
            'catatan_penyedia': catatan.trim(),
          },
          catatan: catatan.trim().isEmpty ? 'Mengajukan penawaran' : catatan.trim());
      if (ok) {
        await _notif(
            o.uidPemesan,
            'Penawaran dari ${o.namaPenyedia}',
            '${hargaFinal == null ? 'Harga disepakati nanti' : rupiah(hargaFinal)}'
                ' • ${AppUtils.formatTanggal(tglFinal)}. Buka pesanan untuk menyetujui.',
            o.id);
      }
      return ok;
    }

    final ok = await _ubah(o, ['menunggu'], 'diterima',
        extra: {
          'harga_final': hargaFinal,
          'catatan_penyedia': catatan.trim(),
        },
        catatan: catatan.trim().isEmpty ? 'Pesanan diterima' : catatan.trim());
    if (ok) {
      await _notif(o.uidPemesan, 'Pesanan Diterima ✅',
          '${o.namaPenyedia} menerima pesanan "${o.namaLayanan}".', o.id);
    }
    return ok;
  }

  Future<bool> tolak(OrderModel o, String alasan) async {
    final ok = await _ubah(o, ['menunggu'], 'ditolak',
        extra: {'alasan_batal': alasan.trim(), 'dibatalkan_oleh': 'penyedia'},
        catatan: alasan.trim());
    if (ok) {
      await _notif(o.uidPemesan, 'Pesanan Ditolak',
          '${o.namaPenyedia} tidak dapat menerima pesanan Anda. Alasan: ${alasan.trim()}', o.id);
    }
    return ok;
  }

  // ─── 3. PEMESAN: jawab penawaran ─────────────────────────
  Future<bool> setujuiPenawaran(OrderModel o) async {
    final ok = await _ubah(o, ['nego'], 'diterima',
        catatan: 'Penawaran disetujui');
    if (ok) {
      await _notif(o.uidPenyedia, 'Penawaran Disetujui ✅',
          '${o.namaPemesan} menyetujui penawaran untuk "${o.namaLayanan}".', o.id);
    }
    return ok;
  }

  Future<bool> tolakPenawaran(OrderModel o, {String alasan = ''}) async {
    final teks = alasan.trim().isEmpty ? 'Penawaran tidak disetujui' : alasan.trim();
    final ok = await _ubah(o, ['nego'], 'dibatalkan',
        extra: {'alasan_batal': teks, 'dibatalkan_oleh': 'pemesan'},
        catatan: teks);
    if (ok) {
      await _notif(o.uidPenyedia, 'Penawaran Ditolak',
          '${o.namaPemesan} tidak menyetujui penawaran. $teks', o.id);
    }
    return ok;
  }

  // ─── 4. PENYEDIA: kerjakan & tandai selesai ──────────────
  Future<bool> mulaiKerjakan(OrderModel o) async {
    final ok = await _ubah(o, ['diterima'], 'dikerjakan',
        catatan: 'Pekerjaan dimulai');
    if (ok) {
      await _notif(o.uidPemesan, 'Pesanan Sedang Dikerjakan 🔧',
          '${o.namaPenyedia} mulai mengerjakan "${o.namaLayanan}".', o.id);
    }
    return ok;
  }

  Future<bool> tandaiSelesai(OrderModel o,
      {required bool lunas, int? biayaAkhir, String catatan = ''}) async {
    final ok = await _ubah(o, ['dikerjakan'], 'menunggu_konfirmasi',
        extra: {
          'lunas': lunas,
          if (biayaAkhir != null) 'harga_final': biayaAkhir,
          if (catatan.trim().isNotEmpty) 'catatan_penyedia': catatan.trim(),
        },
        catatan: catatan.trim().isEmpty ? 'Pekerjaan selesai' : catatan.trim());
    if (ok) {
      await _notif(
          o.uidPemesan,
          'Pekerjaan Selesai — mohon konfirmasi',
          '${o.namaPenyedia} menandai "${o.namaLayanan}" selesai. Konfirmasi lalu beri ulasan.',
          o.id);
    }
    return ok;
  }

  // ─── 5. PEMESAN: konfirmasi selesai / belum beres ────────
  Future<bool> konfirmasiSelesai(OrderModel o) async {
    final ok = await _ubah(o, ['menunggu_konfirmasi'], 'selesai',
        extra: {'selesai_at': Timestamp.fromDate(DateTime.now())},
        catatan: 'Dikonfirmasi selesai oleh pemesan');
    if (ok) {
      try {
        await _firestore
            .collection('penyedia_jasa')
            .doc(o.serviceId)
            .update({'pesanan_selesai': FieldValue.increment(1)});
      } catch (_) {}
      await _notif(o.uidPenyedia, 'Pesanan Selesai 🎉',
          '${o.namaPemesan} mengonfirmasi "${o.namaLayanan}" selesai.', o.id);
    }
    return ok;
  }

  Future<bool> belumBeres(OrderModel o, String catatan) async {
    final ok = await _ubah(o, ['menunggu_konfirmasi'], 'dikerjakan',
        catatan: 'Belum beres: ${catatan.trim()}');
    if (ok) {
      await _notif(o.uidPenyedia, 'Pekerjaan Belum Sesuai',
          '${o.namaPemesan}: ${catatan.trim()}', o.id);
    }
    return ok;
  }

  // ─── 6. BATALKAN ─────────────────────────────────────────
  Future<bool> batalkan(OrderModel o, String alasan,
      {required bool olehPemesan}) async {
    final dari = olehPemesan
        ? ['menunggu', 'nego', 'diterima']
        : ['diterima', 'dikerjakan', 'nego'];
    final ok = await _ubah(o, dari, 'dibatalkan',
        extra: {
          'alasan_batal': alasan.trim(),
          'dibatalkan_oleh': olehPemesan ? 'pemesan' : 'penyedia',
        },
        catatan: alasan.trim());
    if (ok) {
      await _notif(
          olehPemesan ? o.uidPenyedia : o.uidPemesan,
          'Pesanan Dibatalkan',
          '${olehPemesan ? o.namaPemesan : o.namaPenyedia} membatalkan "${o.namaLayanan}". Alasan: ${alasan.trim()}',
          o.id);
    }
    return ok;
  }

  // ─── Kapasitas otomatis (dijalankan di perangkat penyedia) ──
  /// Bila jumlah pesanan berjalan mencapai kapasitas → status otomatis
  /// "Penuh"; bila kembali longgar → "Buka" lagi (hanya jika penuhnya otomatis).
  Future<void> _sinkronKapasitas() async {
    if (_sinkronBerjalan) return;
    final svc = Get.find<ServiceController>().punyaSaya.value;
    if (svc == null || svc.status != 'aktif') return;
    final int berjalan =
        masuk.where((o) => o.status == 'diterima' || o.status == 'dikerjakan').length;
    final bool penuh = svc.kapasitasAktif > 0 && berjalan >= svc.kapasitasAktif;
    try {
      _sinkronBerjalan = true;
      final ref = _firestore.collection('penyedia_jasa').doc(svc.id);
      if (penuh && svc.ketersediaan == 'buka') {
        await ref.update({
          'ketersediaan': 'penuh',
          'penuh_otomatis': true,
          'ketersediaan_catatan': 'Kapasitas pesanan sedang penuh',
          'tutup_sampai': null,
        });
      } else if (!penuh && svc.penuhOtomatis && svc.ketersediaan == 'penuh') {
        await ref.update({
          'ketersediaan': 'buka',
          'penuh_otomatis': false,
          'ketersediaan_catatan': '',
        });
      }
    } catch (_) {
      // pelengkap — kegagalan tidak boleh mengganggu alur utama
    } finally {
      _sinkronBerjalan = false;
    }
  }
}
