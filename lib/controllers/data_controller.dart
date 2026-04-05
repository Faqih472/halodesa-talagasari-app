// ============================================================
// data_controller.dart - TAHAP 2 FINAL
// Controller sentral: Informasi Desa + semua logic CRUD
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/app_models.dart';
import '../core/app_utils.dart';
import 'auth_controller.dart';

class DataController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── Reactive State ──────────────────────────────────────
  final RxList<NewsModel> publishedNews = <NewsModel>[].obs;
  final RxList<NewsModel> myRequests = <NewsModel>[].obs;
  final RxList<NewsModel> pendingList = <NewsModel>[].obs;
  final RxList<NewsModel> draftList = <NewsModel>[].obs;
  final RxList<NewsModel> kadesQueue = <NewsModel>[].obs;

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
      publishedNews.value =
          snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
    } catch (e) {
      // Coba tanpa orderBy jika index belum ada
      try {
        final snapshot = await _firestore
            .collection('announcements')
            .where('status', isEqualTo: 'published')
            .get();
        publishedNews.value =
            snapshot.docs.map((d) => NewsModel.fromFirestore(d)).toList();
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

  // ─── SUBMIT: Warga ajukan informasi ──────────────────────
  Future<bool> submitInformasi({
    required String judul,
    required String isi,
    required String kategori,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return false;

      // Rule-based: kategori sensitif → pending_kades, lainnya → menunggu_review_admin
      final statusAwal = AppUtils.tentukanStatusAwal(kategori);

      await _firestore.collection('announcements').add({
        'judul': judul.trim(),
        'isi': isi.trim(),
        'kategori': kategori,
        'status': statusAwal,
        'authorId': uid,
        'foto_url': '',
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
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return false;

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
        'authorId': uid,
        'foto_url': '',
        'alasan_penolakan': null,
        'created_at': Timestamp.fromDate(DateTime.now()),
        'published_at':
        publishedAt != null ? Timestamp.fromDate(publishedAt) : null,
        'approved_by_uid': status == 'published' ? uid : null,
      });

      await fetchDraftList();
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
  Future<bool> approveNews(String docId) async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      await _firestore.collection('announcements').doc(docId).update({
        'status': 'published',
        'published_at': Timestamp.fromDate(DateTime.now()),
        'approved_by_uid': uid,
      });
      await fetchPendingList();
      await fetchDraftList();
      await fetchKadesQueue();
      await fetchPublishedNews();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyetujui: $e';
      return false;
    }
  }

  // ─── KIRIM KE KADES: Admin eskalasi konten sensitif ──────
  Future<bool> kirimKeKades(String docId) async {
    try {
      await _firestore.collection('announcements').doc(docId).update({
        'status': 'pending_kades',
      });
      await fetchPendingList();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim ke Kades: $e';
      return false;
    }
  }

  // ─── REJECT: Tolak konten ─────────────────────────────────
  Future<bool> rejectNews(String docId, {String? alasan}) async {
    try {
      await _firestore.collection('announcements').doc(docId).update({
        'status': 'ditolak',
        'alasan_penolakan': alasan ?? '',
        'rejected_at': Timestamp.fromDate(DateTime.now()),
      });
      await fetchPendingList();
      await fetchMyRequests();
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
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menghapus: $e';
      return false;
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