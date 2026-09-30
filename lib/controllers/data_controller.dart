// ============================================================
// data_controller.dart — DataController + ServiceController
// ============================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../core/models.dart';
import 'auth_controller.dart';
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
      final before = await _firestore.collection('announcements').doc(docId).get();
      final authorId = before.data()?['authorId'];
      final judul = before.data()?['judul'] ?? '';

      await _firestore.collection('announcements').doc(docId).update({
        'status': 'published',
        'published_at': Timestamp.fromDate(DateTime.now()),
        'approved_by_uid': uid,
      });
      await fetchPendingList();
      await fetchDraftList();
      await fetchKadesQueue();
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
      final before = await _firestore.collection('announcements').doc(docId).get();
      final authorId = before.data()?['authorId'];
      final judul = before.data()?['judul'] ?? '';

      await _firestore.collection('announcements').doc(docId).update({
        'status': 'ditolak',
        'alasan_penolakan': alasan ?? '',
        'rejected_at': Timestamp.fromDate(DateTime.now()),
      });
      await fetchPendingList();
      await fetchMyRequests();

      if (authorId != null && authorId.toString().isNotEmpty) {
        try {
          await Get.find<NotificationController>().kirimKe(
            uidTujuan: authorId,
            judul: 'Pengajuan Ditolak',
            isi: '"$judul" ditolak. ${alasan ?? ''}'.trim(),
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


// ============================================================
// service_controller.dart
// Modul Direktori Jasa Lokal Berbasis Lokasi (Elisitasi #15-22)
// - Pendaftaran & edit profil penyedia jasa (+ foto portofolio)
// - Verifikasi oleh Admin
// - Pencarian & pengurutan berdasarkan jarak (Haversine)
// - Nonaktifkan sementara
// - Ulasan & rating
// ============================================================

class ServiceController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── Reactive State ──────────────────────────────────────
  final RxList<ServiceModel> daftarAktif = <ServiceModel>[].obs;
  final RxList<ServiceModel> pendingVerifikasi = <ServiceModel>[].obs;
  final Rx<ServiceModel?> punyaSaya = Rx<ServiceModel?>(null);
  final RxString filterKategori = 'semua'.obs;

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAktif();
    ever(_authCtrl.currentUser, (user) {
      if (user != null) {
        fetchAktif(); // ulangi setelah login (sebelum login aturan Firestore bisa menolak)
        fetchPunyaSaya();
        if (user.isAdmin) fetchPendingVerifikasi();
      } else {
        punyaSaya.value = null;
        pendingVerifikasi.clear();
      }
    });
    if (_authCtrl.currentUser.value != null) {
      fetchPunyaSaya();
      if (_authCtrl.currentUser.value!.isAdmin) fetchPendingVerifikasi();
    }
  }

  // ─── FETCH: Semua penyedia jasa berstatus aktif ──────────
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
    } catch (e) {
      errorMsg.value = 'Gagal memuat penyedia jasa: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ─── FETCH: Profil jasa milik pengguna saat ini ──────────
  Future<void> fetchPunyaSaya() async {
    try {
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return;
      final snap = await _firestore
          .collection('penyedia_jasa')
          .where('uid_penyedia', isEqualTo: uid)
          .limit(1)
          .get();
      punyaSaya.value = snap.docs.isNotEmpty
          ? ServiceModel.fromFirestore(snap.docs.first)
          : null;
    } catch (e) {
      errorMsg.value = 'Gagal memuat profil jasa: $e';
    }
  }

  // ─── FETCH: Antrean verifikasi untuk Admin ───────────────
  Future<void> fetchPendingVerifikasi() async {
    try {
      final snap = await _firestore
          .collection('penyedia_jasa')
          .where('status', isEqualTo: 'pending')
          .get();
      final list =
          snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      pendingVerifikasi.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat antrean verifikasi: $e';
    }
  }

  // ─── Daftar terfilter + terurut jarak terdekat ───────────
  List<ServiceModel> get daftarDenganJarak {
    final user = _authCtrl.currentUser.value;
    final double lat = user?.lokasiLat ?? -6.239265;
    final double lng = user?.lokasiLng ?? 106.530200;

    Iterable<ServiceModel> list = daftarAktif;
    if (filterKategori.value != 'semua') {
      list = list.where((s) => s.kategori == filterKategori.value);
    }

    final withJarak = list
        .map((s) => s.copyWithJarak(
            AppUtils.hitungJarak(lat, lng, s.lokasiLat, s.lokasiLng)))
        .toList();
    withJarak.sort((a, b) => (a.jarakKm ?? 999999).compareTo(b.jarakKm ?? 999999));
    return withJarak;
  }

  void setFilter(String kategori) => filterKategori.value = kategori;

  // ─── Upload beberapa foto portofolio ke Firebase Storage ─
  Future<List<String>> _uploadFotoPortofolio(String uid, List<File> files) async {
    final List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      final ref = _storage.ref().child(
          'penyedia_jasa/$uid/portofolio_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      await ref.putFile(files[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  // ─── DAFTAR sebagai penyedia jasa baru ───────────────────
  Future<bool> daftarJasa({
    required String kategori,
    required String deskripsi,
    List<File> fotoPortofolio = const [],
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final user = _authCtrl.currentUser.value;
      if (user == null) return false;

      List<String> urls = [];
      if (fotoPortofolio.isNotEmpty) {
        urls = await _uploadFotoPortofolio(user.uid, fotoPortofolio);
      }

      await _firestore.collection('penyedia_jasa').add({
        'uid_penyedia': user.uid,
        'nama_penyedia': user.nama,
        'foto_url': user.fotoUrl,
        'kategori': kategori,
        'deskripsi': deskripsi.trim(),
        'foto_portofolio': urls,
        'lokasi_lat': user.lokasiLat,
        'lokasi_lng': user.lokasiLng,
        'status': 'pending',
        'alasan_penolakan': null,
        'rating_avg': 0.0,
        'rating_count': 0,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'isPenyediaJasa': true,
      });

      await fetchPunyaSaya();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mendaftar sebagai penyedia jasa: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── EDIT profil jasa (foto/deskripsi = ringan, kategori = butuh reverifikasi) ─
  Future<bool> editJasa({
    required String docId,
    required String kategori,
    required String deskripsi,
    List<File> fotoBaru = const [],
    required bool kategoriBerubah,
  }) async {
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final uid = _authCtrl.currentUser.value?.uid;
      if (uid == null) return false;

      final Map<String, dynamic> updates = {
        'deskripsi': deskripsi.trim(),
        'kategori': kategori,
      };

      if (fotoBaru.isNotEmpty) {
        final urls = await _uploadFotoPortofolio(uid, fotoBaru);
        updates['foto_portofolio'] = FieldValue.arrayUnion(urls);
      }

      // Elisitasi #22: perubahan mendasar (kategori) memicu verifikasi ulang
      if (kategoriBerubah) {
        updates['status'] = 'pending';
      }

      await _firestore.collection('penyedia_jasa').doc(docId).update(updates);
      await fetchPunyaSaya();
      if (kategoriBerubah) await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memperbarui profil jasa: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── Nonaktifkan / Aktifkan kembali (Elisitasi #21) ─────
  Future<bool> toggleAktifNonaktif(String docId, bool aktifkan) async {
    try {
      await _firestore.collection('penyedia_jasa').doc(docId).update({
        'status': aktifkan ? 'aktif' : 'nonaktif',
      });
      await fetchPunyaSaya();
      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengubah status: $e';
      return false;
    }
  }

  // ─── VERIFIKASI oleh Admin (Elisitasi #17) ──────────────
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
      });
      await fetchPendingVerifikasi();
      await fetchAktif();

      try {
        await Get.find<NotificationController>().kirimKe(
          uidTujuan: uidPemilik,
          judul: setuju ? 'Profil Jasa Disetujui 🎉' : 'Profil Jasa Ditolak',
          isi: setuju
              ? 'Selamat! Profil jasa Anda kini tampil di pencarian warga.'
              : 'Profil jasa Anda ditolak Admin. ${alasan ?? ''}'.trim(),
          tipe: 'jasa',
          targetId: docId,
        );
      } catch (_) {}

      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memverifikasi: $e';
      return false;
    }
  }

  // ─── ULASAN & RATING ──────────────────────────────────────
  Future<bool> tambahReview(
    String docId, {
    required int rating,
    required String komentar,
  }) async {
    try {
      final user = _authCtrl.currentUser.value;
      if (user == null) return false;
      final docRef = _firestore.collection('penyedia_jasa').doc(docId);
      String uidPemilik = '';

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() as Map<String, dynamic>;
        uidPemilik = data['uid_penyedia'] ?? '';
        final double avgLama = (data['rating_avg'] ?? 0.0).toDouble();
        final int countLama = ((data['rating_count'] ?? 0) as num).toInt();
        final double avgBaru =
            ((avgLama * countLama) + rating) / (countLama + 1);

        final reviewRef = docRef.collection('reviews').doc();
        tx.set(reviewRef, {
          'id_pengguna': user.uid,
          'nama_pengguna': user.nama,
          'rating': rating,
          'komentar': komentar.trim(),
          'created_at': Timestamp.fromDate(DateTime.now()),
        });
        tx.update(docRef, {
          'rating_avg': double.parse(avgBaru.toStringAsFixed(2)),
          'rating_count': countLama + 1,
        });
      });

      if (uidPemilik.isNotEmpty) {
        try {
          await Get.find<NotificationController>().kirimKe(
            uidTujuan: uidPemilik,
            judul: 'Ulasan Baru ⭐',
            isi: '${user.nama} memberi rating $rating untuk jasa Anda.',
            tipe: 'jasa',
            targetId: docId,
          );
        } catch (_) {}
      }

      await fetchAktif();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim ulasan: $e';
      return false;
    }
  }

  Stream<QuerySnapshot> reviewsStream(String docId) {
    return _firestore
        .collection('penyedia_jasa')
        .doc(docId)
        .collection('reviews')
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}
