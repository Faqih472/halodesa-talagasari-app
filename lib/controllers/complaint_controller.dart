// ============================================================
// complaint_controller.dart — Pengaduan Warga + Verifikasi KTP
//
// Pengaduan:
//   warga kirim → Admin saring (setujui/tolak)
//     • kategori ringan → diproses Admin → selesai
//     • kategori berat (keamanan, kekerasan) → Kades → diproses → selesai
//   Laporan TIDAK tampil publik; hanya pelapor, Admin, dan Kades.
//
// Verifikasi KTP: warga unggah foto KTP → Admin cek manual.
// Hanya warga terverifikasi yang boleh membuat pengaduan.
// ============================================================

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';
import 'auth_controller.dart';
import 'chat_controller.dart';
import 'village_controller.dart';

class ComplaintController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  // ─── State ───────────────────────────────────────────────
  final RxList<ComplaintModel> myComplaints = <ComplaintModel>[].obs;
  final RxList<ComplaintModel> antrian = <ComplaintModel>[].obs; // Admin/Kades
  final Rx<KtpModel> myKtp = KtpModel(uid: '').obs;
  final RxList<KtpModel> ktpMenunggu = <KtpModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (user) {
      if (user == null) {
        myComplaints.clear();
        antrian.clear();
        ktpMenunggu.clear();
        myKtp.value = KtpModel(uid: '');
      }
    });
  }

  /// Identitas terverifikasi? (lencana "Terverifikasi")
  bool get ktpOk =>
      (_authCtrl.currentUser.value?.isVerified ?? false) ||
      myKtp.value.terverifikasi;

  // ─────────────────────────────────────────────────────────
  // VERIFIKASI IDENTITAS — sisi warga (teks saja, tanpa foto)
  // ─────────────────────────────────────────────────────────
  Future<void> fetchMyKtp() async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('verifikasi_ktp').doc(uid).get();
      myKtp.value = doc.exists
          ? KtpModel.fromFirestore(doc)
          : KtpModel(uid: uid, status: 'belum');
    } catch (_) {}
  }

  Future<bool> kirimKtp({
    required String nama,
    required String nik,
    required String tempatLahir,
    required DateTime tanggalLahir,
    required String jenisKelamin,
    required String alamat,
    required String rt,
    required String rw,
    required String fotoSelfie, // data URL base64 dari kamera depan
    required String fotoKtp, // data URL base64 foto KTP saja
  }) async {
    final user = _authCtrl.currentUser.value;
    if (user == null) return false;
    if (myKtp.value.status == 'diblokir') {
      errorMsg.value = 'ktp_blocked'.tr;
      return false;
    }
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      // 2 foto (selfie + KTP) dari kamera, sudah dikecilkan & berupa base64.
      // Disimpan gratis di Firestore, hanya terbaca pemilik & Admin, dan
      // DIHAPUS otomatis setelah Admin memutuskan.
      if (!fotoSelfie.startsWith('data:') || !fotoKtp.startsWith('data:')) {
        errorMsg.value = 'Ambil kedua foto (selfie dan KTP) lewat kamera.';
        return false;
      }
      await _firestore.collection('verifikasi_ktp').doc(user.uid).set({
        'uid': user.uid,
        'nama': nama.trim(),
        'email': user.email,
        'telepon': user.nomorTelepon,
        'status': 'menunggu',
        'nik': nik.trim(),
        'tempat_lahir': tempatLahir.trim(),
        'tanggal_lahir': Timestamp.fromDate(tanggalLahir),
        'jenis_kelamin': jenisKelamin,
        'alamat': alamat.trim(),
        'rt': rt.trim(),
        'rw': rw.trim(),
        'foto_selfie': fotoSelfie,
        'foto_ktp': fotoKtp,
        'alasan': null,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      await fetchMyKtp();
      await _notifAdmin(
        judul: 'Verifikasi Identitas Baru',
        isi: '${user.nama} mengajukan verifikasi identitas.',
        tipe: 'sistem',
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim data: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // VERIFIKASI IDENTITAS — sisi Admin
  // ─────────────────────────────────────────────────────────
  Future<void> fetchKtpMenunggu() async {
    try {
      final snap = await _firestore
          .collection('verifikasi_ktp')
          .where('status', isEqualTo: 'menunggu')
          .get();
      final list = snap.docs.map((d) => KtpModel.fromFirestore(d)).toList()
        ..sort((a, b) => (a.createdAt ?? DateTime.now())
            .compareTo(b.createdAt ?? DateTime.now()));
      ktpMenunggu.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat verifikasi: $e';
    }
  }

  Future<bool> putuskanKtp(KtpModel k,
      {required bool setuju, String? alasan}) async {
    try {
      await _firestore.collection('verifikasi_ktp').doc(k.uid).update({
        'status': setuju ? 'terverifikasi' : 'ditolak',
        // Data minimal: foto KTP tidak disimpan setelah diperiksa
        'foto_ktp': FieldValue.delete(),
        'foto_selfie': FieldValue.delete(),
        'alasan': setuju ? null : alasan,
        'reviewed_by': _authCtrl.currentUser.value?.uid,
        'reviewed_at': Timestamp.fromDate(DateTime.now()),
      });
      // Lencana + data resmi KTP dipakai untuk surat
      await _firestore.collection('users').doc(k.uid).update(setuju
          ? {
              'isVerified': true,
              'alamat_lengkap': k.alamat,
              'alamat_rt': k.rt,
              'alamat_rw': k.rw,
              if (k.jenisKelamin.isNotEmpty) 'jenis_kelamin': k.jenisKelamin,
              if (k.tanggalLahir != null)
                'tanggal_lahir': Timestamp.fromDate(k.tanggalLahir!),
            }
          : {'isVerified': false});
      await fetchKtpMenunggu();
      await AuditLog.catat(
          aksi: setuju ? 'Memverifikasi identitas' : 'Menolak verifikasi identitas',
          targetTipe: 'ktp',
          targetId: k.uid,
          detail: k.nama,
          alasan: setuju ? '' : (alasan ?? ''));
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: k.uid,
        judul: setuju ? 'Akun Terverifikasi ✅' : 'Verifikasi Identitas Ditolak',
        isi: setuju
            ? 'Akun Anda kini bisa memakai semua fitur desa.'
            : 'Alasan: ${alasan ?? '-'}. Perbaiki data lalu ajukan ulang.',
        tipe: 'sistem',
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memproses verifikasi: $e';
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // PENGADUAN — sisi warga
  // ─────────────────────────────────────────────────────────
  Future<void> fetchMine() async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    try {
      isLoading.value = true;
      final snap = await _firestore
          .collection('pengaduan')
          .where('uid_pelapor', isEqualTo: uid)
          .get();
      myComplaints.value = _urut(snap.docs);
    } catch (e) {
      errorMsg.value = 'Gagal memuat pengaduan: $e';
    } finally {
      isLoading.value = false;
    }
  }

  List<ComplaintModel> _urut(List<QueryDocumentSnapshot> docs) {
    final list = docs.map((d) => ComplaintModel.fromFirestore(d)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<bool> kirim({
    required String kategori,
    required String judul,
    required String isi,
    List<File> foto = const [],
    bool rahasia = false,
    DateTime? tglKejadian,
    String terlapor = '',
    double? lat,
    double? lng,
  }) async {
    final user = _authCtrl.currentUser.value;
    if (user == null) return false;
    if (!ktpOk) {
      errorMsg.value = 'Verifikasi KTP dulu sebelum membuat pengaduan.';
      return false;
    }
    try {
      isSubmitting.value = true;
      errorMsg.value = '';

      // Batas anti-spam: maksimal 3 pengaduan per hari
      await fetchMine();
      final now = DateTime.now();
      final awalHari = DateTime(now.year, now.month, now.day);
      final hariIni =
          myComplaints.where((c) => c.createdAt.isAfter(awalHari)).length;
      if (hariIni >= 3) {
        errorMsg.value = 'cmp_limit'.tr;
        return false;
      }

      final List<String> urls = [];
      for (final f in foto) {
        final enc = await ImageUtil.encode(f);
        if (enc == null) {
          errorMsg.value = 'Foto terlalu besar, pilih foto lain.';
          return false;
        }
        urls.add(enc);
      }

      final alamat = [
        if (user.alamatLengkap.isNotEmpty) user.alamatLengkap,
        if (user.alamatRt.isNotEmpty || user.alamatRw.isNotEmpty)
          'RT ${user.alamatRt}/RW ${user.alamatRw}',
      ].join(', ');

      final ref = await _firestore.collection('pengaduan').add({
        'uid_pelapor': user.uid,
        'nama_pelapor': user.nama,
        'kategori': kategori,
        'judul': judul.trim(),
        'isi': isi.trim(),
        'foto_urls': urls,
        'lat': lat ?? user.lokasiLat,
        'lng': lng ?? user.lokasiLng,
        'tanggal_kejadian':
            tglKejadian != null ? Timestamp.fromDate(tglKejadian) : null,
        'terlapor': terlapor.trim(),
        'alamat': alamat,
        'rahasia': rahasia,
        'status': 'menunggu_review',
        'penanganan': '',
        'alasan_penolakan': null,
        'tanggapan': null,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });

      await _catatAktivitas(ref.id,
          tipe: 'status', status: 'menunggu_review', isi: '');
      await fetchMine();
      await _notifAdmin(
        judul: 'Pengaduan Baru',
        isi: '${ComplaintModel.labelKategori(kategori)}: ${judul.trim()}',
        tipe: 'pengaduan',
        targetId: ref.id,
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim pengaduan: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // PENGADUAN — antrian Admin / Kades
  // ─────────────────────────────────────────────────────────
  Future<void> fetchAntrian() async {
    final user = _authCtrl.currentUser.value;
    if (user == null || !user.isStaff) return;
    try {
      isLoading.value = true;
      final bool admin = user.isAdmin;
      final snap = await _firestore
          .collection('pengaduan')
          .where('status',
              whereIn: admin
                  ? ['menunggu_review', 'diproses']
                  : ['pending_kades', 'diproses'])
          .get();
      final list = _urut(snap.docs).where((c) {
        if (admin) {
          return c.status == 'menunggu_review' || c.penanganan == 'admin';
        }
        return c.status == 'pending_kades' || c.penanganan == 'kades';
      }).toList();
      antrian.value = list;
    } catch (e) {
      errorMsg.value = 'Gagal memuat antrian pengaduan: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Semua pengaduan (selain ditolak) untuk peta sebaran — Admin/Kades
  final RxList<ComplaintModel> semua = <ComplaintModel>[].obs;

  Future<void> fetchSemua() async {
    final user = _authCtrl.currentUser.value;
    if (user == null || !user.isStaff) return;
    try {
      isLoading.value = true;
      final snap = await _firestore.collection('pengaduan').limit(500).get();
      semua.value = _urut(snap.docs)
          .where((c) => c.status != 'ditolak' && (c.lat != 0 || c.lng != 0))
          .toList();
    } catch (e) {
      errorMsg.value = 'Gagal memuat peta pengaduan: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Admin menyetujui: ringan → diproses (Admin), berat → diteruskan ke Kades
  Future<bool> setujui(ComplaintModel c) async {
    final bool berat = c.isBerat;
    final ok = await _ubah(c, {
      'status': berat ? 'pending_kades' : 'diproses',
      'penanganan': berat ? '' : 'admin',
    });
    if (!ok) return false;
    await _notifPelapor(
      c,
      berat ? 'Pengaduan Diteruskan ke Kades' : 'Pengaduan Sedang Diproses',
      berat
          ? '"${c.judul}" lolos pemeriksaan dan diteruskan ke Kepala Desa.'
          : '"${c.judul}" lolos pemeriksaan dan sedang ditindaklanjuti.',
    );
    if (berat) {
      await _notifKades(
        judul: 'Pengaduan Perlu Persetujuan',
        isi: '${ComplaintModel.labelKategori(c.kategori)}: ${c.judul}',
        targetId: c.id,
      );
    }
    return true;
  }

  /// Kades menerima pengaduan berat → diproses (Kades)
  Future<bool> terimaKades(ComplaintModel c) async {
    final ok = await _ubah(c, {'status': 'diproses', 'penanganan': 'kades'});
    if (ok) {
      await _notifPelapor(c, 'Pengaduan Sedang Diproses',
          '"${c.judul}" diterima Kepala Desa dan sedang ditindaklanjuti.');
    }
    return ok;
  }

  Future<bool> tolak(ComplaintModel c, String alasan) async {
    final ok = await _ubah(c, {
      'status': 'ditolak',
      'alasan_penolakan': alasan.trim(),
    });
    if (ok) {
      await _notifPelapor(c, 'Pengaduan Ditolak',
          '"${c.judul}" ditolak. Alasan: ${alasan.trim()}');
    }
    return ok;
  }

  Future<bool> selesaikan(ComplaintModel c, String tanggapan) async {
    final ok = await _ubah(c, {
      'status': 'selesai',
      'tanggapan': tanggapan.trim(),
    });
    if (ok) {
      await _notifPelapor(c, 'Pengaduan Selesai ✅',
          '"${c.judul}" telah ditangani. Tanggapan: ${tanggapan.trim()}');
    }
    return ok;
  }

  /// Admin: kirim peringatan ke pelapor (mis. laporan tidak sesuai)
  Future<bool> peringati(ComplaintModel c, String pesan) async {
    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: c.uidPelapor,
        judul: 'Peringatan dari Admin',
        isi: pesan.trim(),
        tipe: 'sistem',
        targetId: c.id,
      );
      await AuditLog.catat(
          aksi: 'Memberi peringatan pelapor',
          targetTipe: 'pengaduan',
          targetId: c.id,
          detail: c.judul);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim peringatan: $e';
      return false;
    }
  }

  /// Admin: blokir pelapor dari fitur pengaduan (laporan palsu/penyalahgunaan)
  Future<bool> blokirPelapor(ComplaintModel c, String alasan) async {
    try {
      await _firestore.collection('verifikasi_ktp').doc(c.uidPelapor).set({
        'uid': c.uidPelapor,
        'nama': c.namaPelapor,
        'status': 'diblokir',
        'alasan': alasan.trim(),
        'reviewed_by': _authCtrl.currentUser.value?.uid,
        'reviewed_at': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: c.uidPelapor,
        judul: 'Fitur Pengaduan Dibatasi',
        isi: 'Akun Anda diblokir dari fitur pengaduan. Alasan: ${alasan.trim()}',
        tipe: 'sistem',
      );
      await AuditLog.catat(
          aksi: 'Memblokir pelapor pengaduan',
          targetTipe: 'ktp',
          targetId: c.uidPelapor,
          detail: '${c.namaPelapor} • ${alasan.trim()}');
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memblokir pelapor: $e';
      return false;
    }
  }

  String _aksiAudit(String status, String? penanganan) {
    switch (status) {
      case 'pending_kades':
        return 'Meneruskan pengaduan ke Kades';
      case 'diproses':
        return 'Menyetujui pengaduan';
      case 'ditolak':
        return 'Menolak pengaduan';
      case 'selesai':
        return 'Menyelesaikan pengaduan';
      default:
        return 'Mengubah pengaduan';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Timeline + balasan dua arah + rating kepuasan
  // ─────────────────────────────────────────────────────────
  Stream<List<ActivityModel>> aktivitasStream(String id) {
    return _firestore
        .collection('pengaduan')
        .doc(id)
        .collection('aktivitas')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => ActivityModel.fromFirestore(d)).toList());
  }

  Future<void> _catatAktivitas(String id,
      {required String tipe, required String isi, String status = ''}) async {
    try {
      final u = _authCtrl.currentUser.value;
      await _firestore.collection('pengaduan').doc(id).collection('aktivitas').add({
        'tipe': tipe,
        'isi': isi,
        'status': status,
        'oleh': u?.nama ?? '',
        'peran': u?.role ?? 'warga',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}
  }

  /// Balasan: pelapor ↔ petugas (Admin / Kades)
  Future<bool> kirimKomentar(ComplaintModel c, String teks) async {
    final u = _authCtrl.currentUser.value;
    if (u == null || teks.trim().isEmpty) return false;
    try {
      await _firestore.collection('pengaduan').doc(c.id).collection('aktivitas').add({
        'tipe': 'komentar',
        'isi': teks.trim(),
        'status': '',
        'oleh': u.nama,
        'peran': u.role,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      if (u.uid == c.uidPelapor) {
        await notifPeran(
          (c.status == 'pending_kades' || c.penanganan == 'kades')
              ? ['kades']
              : ['admin'],
          judul: 'Balasan dari Pelapor',
          isi: '${c.judul}: ${teks.trim()}',
          tipe: 'pengaduan',
          targetId: c.id,
        );
      } else {
        await _notifPelapor(c, 'Balasan dari Petugas', teks.trim());
      }
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim balasan: $e';
      return false;
    }
  }

  /// Rating kepuasan oleh pelapor setelah laporan selesai (sekali saja)
  Future<bool> beriRating(ComplaintModel c, int rating, String ulasan) async {
    try {
      await _firestore.collection('pengaduan').doc(c.id).update({
        'rating': rating,
        'ulasan_rating': ulasan.trim(),
        'rated_at': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim rating: $e';
      return false;
    }
  }

  Future<bool> _ubah(ComplaintModel c, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('pengaduan').doc(c.id).update({
        ...data,
        'updated_at': Timestamp.fromDate(DateTime.now()),
        'diproses_oleh': _authCtrl.currentUser.value?.uid,
      });
      final String st = (data['status'] ?? '') as String;
      await _catatAktivitas(c.id,
          tipe: 'status',
          status: st,
          isi: (data['alasan_penolakan'] ?? data['tanggapan'] ?? '') as String);
      await AuditLog.catat(
          aksi: _aksiAudit(st, data['penanganan'] as String?),
          targetTipe: 'pengaduan',
          targetId: c.id,
          detail: c.judul,
          alasan: st == 'ditolak'
              ? (data['alasan_penolakan'] ?? '').toString()
              : '');
      await fetchAntrian();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal memperbarui pengaduan: $e';
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Notifikasi
  // ─────────────────────────────────────────────────────────
  Future<void> _notifPelapor(ComplaintModel c, String judul, String isi) async {
    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: c.uidPelapor,
        judul: judul,
        isi: isi,
        tipe: 'pengaduan',
        targetId: c.id,
      );
    } catch (_) {}
  }

  Future<void> _notifAdmin({
    required String judul,
    required String isi,
    String tipe = 'pengaduan',
    String? targetId,
  }) =>
      _notifRole('admin',
          judul: judul, isi: isi, tipe: tipe, targetId: targetId);

  Future<void> _notifKades({
    required String judul,
    required String isi,
    String? targetId,
  }) =>
      _notifRole('kades', judul: judul, isi: isi, targetId: targetId);

  Future<void> _notifRole(
    String role, {
    required String judul,
    required String isi,
    String tipe = 'pengaduan',
    String? targetId,
  }) async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      final notif = Get.find<NotificationController>();
      for (final d in snap.docs) {
        await notif.kirimKe(
          uidTujuan: d.id,
          judul: judul,
          isi: isi,
          tipe: tipe,
          targetId: targetId,
        );
      }
    } catch (_) {}
  }
}
