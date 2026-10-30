// ============================================================
// feedback_controller.dart — Kritik, Saran & Rating
//
// Warga dapat menilai:
//   • Aplikasi            (error, lambat, fitur tidak berguna, dst.)
//   • Pelayanan Admin     (dibaca Kades)
//   • Pelayanan Kades     (dibaca Admin)
// Penilaian pelayanan hanya untuk warga TERVERIFIKASI (anti akun palsu),
// maksimal 1x per target per 14 hari (anti spam), dan boleh anonim terhadap
// petugas. Data otomatis dihapus setelah 180 hari.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../core/models_extra.dart';
import 'auth_controller.dart';
import 'complaint_controller.dart';
import 'village_controller.dart';

class FeedbackController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthController _auth = Get.find<AuthController>();

  static const int jedaHari = 14;

  final RxBool isSubmitting = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMsg = ''.obs;
  final RxList<FeedbackModel> masuk = <FeedbackModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    ever(_auth.currentUser, (u) {
      if (u == null) masuk.clear();
    });
  }

  /// Target yang boleh dibaca oleh peran yang sedang login
  List<String> get targetDibaca {
    final role = _auth.role;
    if (role == 'admin') return ['kades', 'aplikasi'];
    if (role == 'kades') return ['admin', 'aplikasi'];
    return const [];
  }

  // ─── WARGA: kirim penilaian ──────────────────────────────
  Future<bool> kirim({
    required String target,
    required int rating,
    required List<String> aspek,
    required String komentar,
    required bool anonim,
  }) async {
    final u = _auth.currentUser.value;
    if (u == null) return false;
    errorMsg.value = '';

    if (rating < 1 || rating > 5) {
      errorMsg.value = 'Pilih jumlah bintang dulu.';
      return false;
    }
    if (target != 'aplikasi') {
      if (u.isStaff) {
        errorMsg.value = 'Penilaian pelayanan hanya untuk warga.';
        return false;
      }
      final cmp = Get.find<ComplaintController>();
      await cmp.fetchMyKtp();
      if (!cmp.ktpOk) {
        errorMsg.value =
            'Penilaian pelayanan hanya untuk warga yang sudah terverifikasi.';
        return false;
      }
    }
    if (rating <= 2 && komentar.trim().length < 10) {
      errorMsg.value =
          'Untuk nilai rendah, jelaskan masalahnya (minimal 10 huruf) agar bisa ditindaklanjuti.';
      return false;
    }

    try {
      isSubmitting.value = true;
      // Anti spam: 1x per target per 14 hari
      final lama = await _db
          .collection('umpan_balik')
          .where('uid', isEqualTo: u.uid)
          .where('target', isEqualTo: target)
          .get();
      final batas = DateTime.now().subtract(const Duration(days: jedaHari));
      final terlalu = lama.docs.any((d) {
        final t = (d.data()['created_at'] as Timestamp?)?.toDate();
        return t != null && t.isAfter(batas);
      });
      if (terlalu) {
        errorMsg.value =
            'Anda sudah menilai ini dalam $jedaHari hari terakhir. Coba lagi nanti.';
        return false;
      }

      final ref = await _db.collection('umpan_balik').add({
        'uid': u.uid,
        'nama': anonim ? 'Anonim' : u.nama,
        'anonim': anonim,
        'target': target,
        'rating': rating,
        'aspek': aspek,
        'komentar': komentar.trim(),
        'status': 'baru',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });

      // Beri tahu hanya untuk nilai rendah (supaya tidak jadi spam notifikasi)
      if (rating <= 2) {
        final penerima = target == 'admin'
            ? ['kades']
            : target == 'kades'
                ? ['admin']
                : ['admin', 'kades'];
        await notifPeran(penerima,
            judul: 'Umpan Balik Nilai Rendah',
            isi:
                '${FeedbackModel.labelTarget(target)}: $rating/5 — buka menu Umpan Balik Warga.',
            tipe: 'sistem',
            targetId: ref.id);
      }
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim penilaian: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─── STAF: baca umpan balik yang menjadi haknya ──────────
  Future<void> muat() async {
    final u = _auth.currentUser.value;
    if (u == null || !u.isStaff) return;
    try {
      isLoading.value = true;
      final hasil = <FeedbackModel>[];
      for (final t in targetDibaca) {
        final snap = await _db
            .collection('umpan_balik')
            .where('target', isEqualTo: t)
            .limit(300)
            .get();
        hasil.addAll(snap.docs.map((d) => FeedbackModel.fromFirestore(d)));
      }
      hasil.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      masuk.value = hasil;
    } catch (e) {
      errorMsg.value = 'Gagal memuat umpan balik: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> tandaiDitinjau(FeedbackModel f) async {
    try {
      await _db.collection('umpan_balik').doc(f.id).update({
        'status': 'ditinjau',
        'ditinjau_oleh': _auth.currentUser.value?.uid,
        'ditinjau_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: 'Meninjau umpan balik warga',
          targetTipe: 'umpan_balik',
          targetId: f.id,
          detail:
              '${FeedbackModel.labelTarget(f.target)} • ${f.rating}/5');
      await muat();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menandai: $e';
      return false;
    }
  }
}
