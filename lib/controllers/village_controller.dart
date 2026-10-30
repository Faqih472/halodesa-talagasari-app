// ============================================================
// village_controller.dart — Layanan desa lanjutan
//   • AuditLog          : catatan keputusan Admin/Kades/RT
//   • SosController     : tombol darurat + lokasi GPS
//   • PollController    : polling / musyawarah online
//   • AgendaController  : kalender agenda + konfirmasi hadir
//   • LetterController  : surat online (Admin cek → Kades terbitkan)
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../core/app_contact.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart' show Retensi;
import 'auth_controller.dart';
import 'chat_controller.dart';
import 'complaint_controller.dart';

// ─────────────────────────────────────────────────────────────
// AUDIT LOG
// ─────────────────────────────────────────────────────────────
class AuditLog {
  /// Catat satu aksi. Tidak pernah melempar error (pelengkap alur utama).
  static Future<void> catat({
    required String aksi,
    String targetTipe = '',
    String targetId = '',
    String detail = '',
    String alasan = '', // alasan penolakan (kalau ada) — tampil merah di log
  }) async {
    try {
      final u = Get.find<AuthController>().currentUser.value;
      if (u == null) return;
      await FirebaseFirestore.instance.collection('audit_log').add({
        'aktor_uid': u.uid,
        'aktor_nama': u.nama,
        'aktor_peran': u.role,
        'aksi': aksi,
        'target_tipe': targetTipe,
        'target_id': targetId,
        'detail': detail,
        if (alasan.trim().isNotEmpty) 'alasan': alasan.trim(),
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}
  }

  static Stream<List<AuditModel>> stream({int limit = 200}) {
    return FirebaseFirestore.instance
        .collection('audit_log')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => AuditModel.fromFirestore(d)).toList());
  }
}

// ─────────────────────────────────────────────────────────────
// Helper notifikasi ke banyak peran
// ─────────────────────────────────────────────────────────────
Future<void> notifPeran(
  List<String> peran, {
  required String judul,
  required String isi,
  String tipe = 'info',
  String? targetId,
  String? kecualiUid, // jangan kirim ke pengirimnya sendiri
}) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: peran)
        .get();
    final notif = Get.find<NotificationController>();
    for (final d in snap.docs) {
      if (kecualiUid != null && d.id == kecualiUid) continue;
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

// ─────────────────────────────────────────────────────────────
// SOS
// ─────────────────────────────────────────────────────────────
class SosController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  final RxBool sending = false.obs;
  final RxString errorMsg = ''.obs;

  /// Kirim SOS: ambil GPS terbaru (cadangan: lokasi terakhir akun).
  Future<bool> kirimSos() async {
    final user = _authCtrl.currentUser.value;
    if (user == null) return false;
    try {
      sending.value = true;
      errorMsg.value = '';

      double lat = user.lokasiLat;
      double lng = user.lokasiLng;
      try {
        LocationPermission izin = await Geolocator.checkPermission();
        if (izin == LocationPermission.denied) {
          izin = await Geolocator.requestPermission();
        }
        if (izin == LocationPermission.always ||
            izin == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}

      final ref = await _firestore.collection('sos').add({
        'uid': user.uid,
        'nama': user.nama,
        'peran': user.role,
        'telepon': user.nomorTelepon,
        'lat': lat,
        'lng': lng,
        'status': 'baru',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });

      // Penerima: Admin & Kades. Bila pengirimnya sendiri Admin/Kades,
      // petugas lain tetap menerima (pengirim dikecualikan).
      await notifPeran(
        ['admin', 'kades'],
        judul: '🚨 SOS DARURAT',
        isi:
            '${user.isStaff ? '${AppTheme.labelRole(user.role)} ' : ''}${user.nama} membutuhkan bantuan segera. Telp: ${user.nomorTelepon.isEmpty ? '-' : user.nomorTelepon}',
        tipe: 'sos',
        targetId: ref.id,
        kecualiUid: user.uid,
      );
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim SOS: $e';
      return false;
    } finally {
      sending.value = false;
    }
  }

  Stream<List<SosModel>> stream() {
    return _firestore
        .collection('sos')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => SosModel.fromFirestore(d)).toList());
  }

  Future<void> tandaiDitangani(SosModel s) async {
    try {
      await _firestore.collection('sos').doc(s.id).update({
        'status': 'ditangani',
        'ditangani_oleh': _authCtrl.currentUser.value?.uid,
      });
      await AuditLog.catat(
          aksi: 'Menandai SOS ditangani',
          targetTipe: 'sos',
          targetId: s.id,
          detail: s.nama);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────
// POLLING
// ─────────────────────────────────────────────────────────────
class PollController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();
  final RxString errorMsg = ''.obs;
  final RxBool isSubmitting = false.obs;

  Stream<List<PollModel>> stream() {
    return _firestore
        .collection('polling')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PollModel.fromFirestore(d)).toList());
  }

  Future<bool> buat(String pertanyaan, List<String> opsi, DateTime tutup,
      {File? foto}) async {
    final u = _authCtrl.currentUser.value;
    if (u == null || !u.isStaff) return false;
    try {
      isSubmitting.value = true;
      String fotoUrl = '';
      if (foto != null) {
        final enc = await ImageUtil.encode(foto);
        if (enc == null) {
          errorMsg.value = 'Foto terlalu besar, pilih foto lain.';
          return false;
        }
        fotoUrl = enc;
      }
      final ref = await _firestore.collection('polling').add({
        'foto_url': fotoUrl,
        'pertanyaan': pertanyaan.trim(),
        'opsi': opsi.map((e) => e.trim()).toList(),
        'tutup': Timestamp.fromDate(tutup),
        'dibuat_oleh': u.nama,
        'dibuat_uid': u.uid,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: 'Membuat polling',
          targetTipe: 'polling',
          targetId: ref.id,
          detail: pertanyaan.trim());
      await notifPeran(['warga'],
          judul: 'Polling Baru',
          isi: pertanyaan.trim(),
          tipe: 'info',
          targetId: ref.id);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal membuat polling: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> hapus(PollModel p) async {
    try {
      await _firestore.collection('polling').doc(p.id).delete();
      await AuditLog.catat(
          aksi: 'Menghapus polling',
          targetTipe: 'polling',
          targetId: p.id,
          detail: p.pertanyaan);
    } catch (_) {}
  }

  /// Pilihan saya (null = belum memilih)
  Future<int?> pilihanSaya(String pollId) async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return null;
    try {
      final d = await _firestore
          .collection('polling')
          .doc(pollId)
          .collection('suara')
          .doc(uid)
          .get();
      if (!d.exists) return null;
      return ((d.data()!['opsi_index'] ?? 0) as num).toInt();
    } catch (_) {
      return null;
    }
  }

  /// Satu akun = satu suara (id dokumen = uid). Wajib terverifikasi KTP.
  Future<bool> pilih(PollModel p, int index) async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return false;
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      final cmp = Get.find<ComplaintController>();
      await cmp.fetchMyKtp();
      if (!cmp.ktpOk) {
        errorMsg.value = 'poll_need_ktp'.tr;
        return false;
      }
      if (p.ditutup) {
        errorMsg.value = 'poll_closed_err'.tr;
        return false;
      }
      if (await pilihanSaya(p.id) != null) {
        errorMsg.value = 'poll_already'.tr;
        return false;
      }
      await _firestore
          .collection('polling')
          .doc(p.id)
          .collection('suara')
          .doc(uid)
          .set({
        'opsi_index': index,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengirim suara: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Jumlah suara per opsi (hitungan agregat di server)
  Future<List<int>> hasil(PollModel p) async {
    final hasil = <int>[];
    for (int i = 0; i < p.opsi.length; i++) {
      try {
        final snap = await _firestore
            .collection('polling')
            .doc(p.id)
            .collection('suara')
            .where('opsi_index', isEqualTo: i)
            .count()
            .get();
        hasil.add(snap.count ?? 0);
      } catch (_) {
        hasil.add(0);
      }
    }
    return hasil;
  }
}

// ─────────────────────────────────────────────────────────────
// AGENDA
// ─────────────────────────────────────────────────────────────
class AgendaController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();
  final RxString errorMsg = ''.obs;
  final RxBool isSubmitting = false.obs;

  Stream<List<AgendaModel>> stream() {
    return _firestore
        .collection('agenda')
        .orderBy('waktu', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => AgendaModel.fromFirestore(d)).toList());
  }

  Future<bool> buat({
    required String judul,
    required String deskripsi,
    required String lokasi,
    required DateTime waktu,
    File? foto,
  }) async {
    final u = _authCtrl.currentUser.value;
    if (u == null || !u.isStaff) return false;
    try {
      isSubmitting.value = true;
      String fotoUrl = '';
      if (foto != null) {
        final enc = await ImageUtil.encode(foto);
        if (enc == null) {
          errorMsg.value = 'Foto terlalu besar, pilih foto lain.';
          return false;
        }
        fotoUrl = enc;
      }
      final ref = await _firestore.collection('agenda').add({
        'foto_url': fotoUrl,
        'judul': judul.trim(),
        'deskripsi': deskripsi.trim(),
        'lokasi': lokasi.trim(),
        'waktu': Timestamp.fromDate(waktu),
        'dibuat_oleh': u.nama,
        'dibuat_uid': u.uid,
        'reminder_terkirim': false,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      await AuditLog.catat(
          aksi: 'Membuat agenda',
          targetTipe: 'agenda',
          targetId: ref.id,
          detail: judul.trim());
      await notifPeran(['warga'],
          judul: 'Agenda Desa Baru',
          isi: judul.trim(),
          tipe: 'agenda',
          targetId: ref.id);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal membuat agenda: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> hapus(AgendaModel a) async {
    try {
      await _firestore.collection('agenda').doc(a.id).delete();
      await AuditLog.catat(
          aksi: 'Menghapus agenda',
          targetTipe: 'agenda',
          targetId: a.id,
          detail: a.judul);
    } catch (_) {}
  }

  Stream<bool> sayaHadir(String id) {
    final uid = _authCtrl.currentUser.value?.uid ?? '-';
    return _firestore
        .collection('agenda')
        .doc(id)
        .collection('hadir')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  Stream<int> jumlahHadir(String id) {
    return _firestore
        .collection('agenda')
        .doc(id)
        .collection('hadir')
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> toggleHadir(AgendaModel a, bool hadir) async {
    final u = _authCtrl.currentUser.value;
    if (u == null) return;
    final ref = _firestore
        .collection('agenda')
        .doc(a.id)
        .collection('hadir')
        .doc(u.uid);
    try {
      if (hadir) {
        await ref.set({
          'nama': u.nama,
          'created_at': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        await ref.delete();
      }
    } catch (e) {
      errorMsg.value = 'Gagal memperbarui kehadiran: $e';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SURAT ONLINE
// ─────────────────────────────────────────────────────────────
class LetterController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  final RxList<LetterModel> mine = <LetterModel>[].obs;
  final RxList<LetterModel> antrian = <LetterModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (u) {
      if (u == null) {
        mine.clear();
        antrian.clear();
      }
    });
  }

  List<LetterModel> _urut(List<QueryDocumentSnapshot> docs) =>
      docs.map((d) => LetterModel.fromFirestore(d)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> fetchMine() async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    try {
      isLoading.value = true;
      final snap = await _firestore
          .collection('surat')
          .where('uid', isEqualTo: uid)
          .get();
      mine.value = _urut(snap.docs);
    } catch (e) {
      errorMsg.value = 'Gagal memuat surat: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> ajukan({required String jenis, required String keperluan}) async {
    final u = _authCtrl.currentUser.value;
    if (u == null) return false;
    final cmp = Get.find<ComplaintController>();
    await cmp.fetchMyKtp();
    if (!cmp.ktpOk) {
      errorMsg.value = 'need_verified'.tr;
      return false;
    }
    try {
      isSubmitting.value = true;
      errorMsg.value = '';
      // Data surat diambil dari data verifikasi identitas (sudah dicek Admin)
      final k = cmp.myKtp.value;
      final alamat = [
        k.alamat,
        'RT ${k.rt}/RW ${k.rw}',
        'Desa Talagasari, Kec. Cikupa, Kab. Tangerang',
      ].join(', ');

      final ref = await _firestore.collection('surat').add({
        'uid': u.uid,
        'nama': k.nama.isNotEmpty ? k.nama : u.nama,
        'nik': k.nik,
        'jenis': jenis,
        'keperluan': keperluan.trim(),
        'alamat': alamat,
        'tempat_lahir': k.tempatLahir,
        'jenis_kelamin': k.jenisKelamin,
        'tanggal_lahir':
            k.tanggalLahir != null ? Timestamp.fromDate(k.tanggalLahir!) : null,
        'status': 'menunggu_review',
        'alasan': null,
        'nomor': '',
        'kode': '',
        'penandatangan': '',
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
      await fetchMine();
      await notifPeran(['admin'],
          judul: 'Pengajuan Surat Baru',
          isi: '${u.nama}: ${LetterModel.labelJenis(jenis)}',
          tipe: 'surat',
          targetId: ref.id);
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal mengajukan surat: $e';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> fetchAntrian() async {
    final u = _authCtrl.currentUser.value;
    if (u == null || !u.isStaff) return;
    try {
      isLoading.value = true;
      final snap = await _firestore
          .collection('surat')
          .where('status',
              whereIn: u.isAdmin
                  ? ['menunggu_review', 'terbit']
                  : ['pending_kades'])
          .get();
      antrian.value = _urut(snap.docs);
    } catch (e) {
      errorMsg.value = 'Gagal memuat antrian surat: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Admin: data sudah benar → teruskan ke Kades
  Future<bool> teruskanKeKades(LetterModel l) async {
    try {
      await _firestore.collection('surat').doc(l.id).update({
        'status': 'pending_kades',
        'diperiksa_oleh': _authCtrl.currentUser.value?.uid,
      });
      await AuditLog.catat(
          aksi: 'Meneruskan surat ke Kades',
          targetTipe: 'surat',
          targetId: l.id,
          detail: '${LetterModel.labelJenis(l.jenis)} • ${l.nama}');
      await _notif(l.uid, 'Surat Diteruskan ke Kades',
          '${LetterModel.labelJenis(l.jenis)} Anda lolos pemeriksaan Admin dan menunggu persetujuan Kepala Desa.',
          l.id);
      await notifPeran(['kades'],
          judul: 'Surat Perlu Ditandatangani',
          isi: '${l.nama}: ${LetterModel.labelJenis(l.jenis)}',
          tipe: 'surat',
          targetId: l.id);
      await fetchAntrian();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal meneruskan surat: $e';
      return false;
    }
  }

  /// Kades: terbitkan → nomor surat otomatis + kode verifikasi
  Future<bool> terbitkan(LetterModel l) async {
    final kades = _authCtrl.currentUser.value;
    if (kades == null || !kades.isKades) return false;
    try {
      final now = DateTime.now();
      final counterRef =
          _firestore.collection('counters').doc('surat_${now.year}');
      int urut = 1;
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        urut = (snap.exists ? ((snap.data()!['n'] ?? 0) as num).toInt() : 0) + 1;
        tx.set(counterRef, {'n': urut});
      });

      final nomor =
          '${urut.toString().padLeft(3, '0')}/${LetterModel.kodeJenis(l.jenis)}/TLG/${_romawi(now.month)}/${now.year}';
      final kode = _kodeAcak(10);

      await _firestore.collection('surat').doc(l.id).update({
        'status': 'terbit',
        'nomor': nomor,
        'kode': kode,
        'penandatangan': kades.nama,
        'terbit_at': Timestamp.fromDate(now),
      });
      await _firestore.collection('surat_verifikasi').doc(kode).set({
        'surat_id': l.id,
        'nomor': nomor,
        'jenis': LetterModel.labelJenis(l.jenis),
        'nama_samar': _samarkan(l.nama),
        'penandatangan': kades.nama,
        'status': 'menunggu_ttd',
        'terbit_at': Timestamp.fromDate(now),
      });
      await AuditLog.catat(
          aksi: 'Menyetujui surat',
          targetTipe: 'surat',
          targetId: l.id,
          detail: '$nomor • ${l.nama}');
      await _notif(l.uid, 'Surat Disetujui ✅',
          '${LetterModel.labelJenis(l.jenis)} Anda disetujui. Cetak PDF-nya lalu datang ke kantor desa untuk tanda tangan basah dan stempel.',
          l.id);
      await fetchAntrian();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menerbitkan surat: $e';
      return false;
    }
  }

  Future<bool> tolak(LetterModel l, String alasan) async {
    try {
      await _firestore.collection('surat').doc(l.id).update({
        'status': 'ditolak',
        'alasan': alasan.trim(),
      });
      await AuditLog.catat(
          aksi: 'Menolak surat',
          targetTipe: 'surat',
          targetId: l.id,
          detail: '${LetterModel.labelJenis(l.jenis)} • ${l.nama}',
          alasan: alasan);
      await _notif(l.uid, 'Pengajuan Surat Ditolak',
          'Alasan: ${alasan.trim()}', l.id);
      await fetchAntrian();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menolak surat: $e';
      return false;
    }
  }

  /// Admin: warga sudah datang & surat sudah ditandatangani basah + distempel
  Future<bool> tandaiDitandatangani(LetterModel l) async {
    try {
      final now = DateTime.now();
      final sampai = DateTime(now.year, now.month + LetterModel.masaBulan(l.jenis),
          now.day, 23, 59);
      await _firestore.collection('surat').doc(l.id).update({
        'status': 'ditandatangani',
        'ttd_at': Timestamp.fromDate(now),
        'berlaku_sampai': Timestamp.fromDate(sampai),
      });
      await _firestore.collection('surat_verifikasi').doc(l.kode).update({
        'status': 'sah',
        'ttd_at': Timestamp.fromDate(now),
        'berlaku_sampai': Timestamp.fromDate(sampai),
      });
      await AuditLog.catat(
          aksi: 'Surat ditandatangani',
          targetTipe: 'surat',
          targetId: l.id,
          detail: '${l.nomor} • ${l.nama}');
      await _notif(l.uid, 'Surat Sah',
          '${LetterModel.labelJenis(l.jenis)} Anda sudah ditandatangani dan berlaku sampai ${sampai.day}/${sampai.month}/${sampai.year}.',
          l.id);
      await fetchAntrian();
      return true;
    } catch (e) {
      errorMsg.value = 'Gagal menyimpan: $e';
      return false;
    }
  }

  /// Cek keaslian surat dari kode surat (Admin/Kades). Null = tidak ditemukan.
  Future<Map<String, dynamic>?> cekKode(String kode) async {
    try {
      final d = await _firestore
          .collection('surat_verifikasi')
          .doc(kode.trim().toUpperCase())
          .get();
      return d.exists ? d.data() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _notif(String uid, String judul, String isi, String id) async {
    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: uid,
        judul: judul,
        isi: isi,
        tipe: 'surat',
        targetId: id,
      );
    } catch (_) {}
  }

  static String _romawi(int bulan) => const [
        'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'
      ][bulan - 1];

  static String _kodeAcak(int n) {
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => huruf[r.nextInt(huruf.length)]).join();
  }

  /// "Budi Santoso" → "Bu** Sa*****"
  static String _samarkan(String nama) {
    return nama.split(' ').map((k) {
      if (k.length <= 2) return k;
      return k.substring(0, 2) + '*' * (k.length - 2);
    }).join(' ');
  }
}


// ─────────────────────────────────────────────────────────────
// RETENSI DATA — pembersihan otomatis (gratis, tanpa Cloud Functions)
//
// Berjalan di perangkat Admin/Kades saat aplikasi dibuka, maksimal 1x per
// ~20 jam untuk seluruh desa (penanda di dokumen meta/retensi).
//   • Informasi lewat masa berlaku (+7 hari)         → dihapus
//   • Informasi lama TANPA masa berlaku (permanen)    → dihapus
//   • Pengajuan informasi ditolak > 30 hari           → dihapus
//   • Log Keputusan > 90 hari, Riwayat SOS > 90 hari  → dihapus
//   • Laporan jasa selesai > 30 hari                  → dihapus
//   • Umpan balik warga > 180 hari                    → dihapus
// Notifikasi dibersihkan oleh pemiliknya sendiri (bersihkanNotifSaya).
// ─────────────────────────────────────────────────────────────
class RetensiService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Timestamp _batas(int hari) =>
      Timestamp.fromDate(DateTime.now().subtract(Duration(days: hari)));

  /// Hapus semua dokumen hasil query (bertahap, aman untuk batas 500/batch)
  static Future<int> _hapusQuery(Query q, {bool Function(DocumentSnapshot)? hanya}) async {
    int total = 0;
    for (int putaran = 0; putaran < 10; putaran++) {
      final snap = await q.limit(200).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      int n = 0;
      for (final d in snap.docs) {
        if (hanya != null && !hanya(d)) continue;
        batch.delete(d.reference);
        n++;
      }
      if (n == 0) break;
      await batch.commit();
      total += n;
      if (snap.docs.length < 200) break;
    }
    return total;
  }

  static Future<void> jalankan() async {
    try {
      final u = Get.find<AuthController>().currentUser.value;
      if (u == null || !u.isStaff) return;

      final ref = _db.collection('meta').doc('retensi');
      final meta = await ref.get();
      final Timestamp? terakhir = meta.data()?['last_run'] as Timestamp?;
      if (terakhir != null &&
          DateTime.now().difference(terakhir.toDate()).inHours < 20) {
        return;
      }
      final bool legacySelesai = meta.data()?['legacy_done'] == true;
      // Tandai dulu agar petugas lain tidak ikut menjalankan bersamaan.
      await ref.set({
        'last_run': Timestamp.fromDate(DateTime.now()),
        'last_run_by': u.uid,
      }, SetOptions(merge: true));

      // 1) Informasi lewat masa berlaku
      await _hapusQuery(_db
          .collection('announcements')
          .where('berlaku_sampai', isLessThan: _batas(Retensi.infoKadaluarsaHari)));

      // 2) Informasi lama tanpa masa berlaku (permanen) — sapuan penuh sekali saja
      if (!legacySelesai) {
        final semua = await _db.collection('announcements').get();
        final batch = _db.batch();
        int n = 0;
        for (final d in semua.docs) {
          if ((d.data())['berlaku_sampai'] == null) {
            batch.delete(d.reference);
            n++;
          }
        }
        if (n > 0) await batch.commit();
        await ref.set({'legacy_done': true}, SetOptions(merge: true));
      } else {
        await _hapusQuery(_db
            .collection('announcements')
            .where('berlaku_sampai', isNull: true));
      }

      // 3) Pengajuan informasi yang ditolak > 30 hari
      final batasTolak =
          DateTime.now().subtract(const Duration(days: Retensi.infoDitolakHari));
      await _hapusQuery(
        _db.collection('announcements').where('status', isEqualTo: 'ditolak'),
        hanya: (d) {
          final m = d.data() as Map<String, dynamic>;
          final t = (m['rejected_at'] ?? m['created_at']) as Timestamp?;
          return t != null && t.toDate().isBefore(batasTolak);
        },
      );

      // 4) Log keputusan, SOS, laporan jasa, umpan balik
      await _hapusQuery(_db
          .collection('audit_log')
          .where('created_at', isLessThan: _batas(Retensi.auditHari)));
      await _hapusQuery(_db
          .collection('sos')
          .where('created_at', isLessThan: _batas(Retensi.sosHari)));
      await _hapusQuery(
        _db
            .collection('laporan_jasa')
            .where('created_at', isLessThan: _batas(Retensi.laporanJasaHari)),
        hanya: (d) => (d.data() as Map<String, dynamic>)['status'] == 'selesai',
      );
      await _hapusQuery(_db
          .collection('umpan_balik')
          .where('created_at', isLessThan: _batas(Retensi.umpanBalikHari)));
    } catch (_) {
      // Pembersihan bersifat pelengkap — jangan pernah mengganggu pemakaian.
    }
  }

  /// Bersihkan notifikasi milik pengguna yang sedang login:
  /// sudah dibaca > 14 hari, atau apa pun yang lebih tua dari 30 hari.
  static Future<void> bersihkanNotifSaya(String uid) async {
    try {
      final koleksi =
          _db.collection('users').doc(uid).collection('notifications');
      final batasMaks =
          DateTime.now().subtract(const Duration(days: Retensi.notifMaksHari));
      await _hapusQuery(
        koleksi.where('created_at', isLessThan: _batas(Retensi.notifDibacaHari)),
        hanya: (d) {
          final m = d.data() as Map<String, dynamic>;
          final t = (m['created_at'] as Timestamp?)?.toDate();
          if (t == null) return true;
          return (m['dibaca'] == true) || t.isBefore(batasMaks);
        },
      );
    } catch (_) {}
  }

  /// Tombol manual: hapus semua notifikasi yang sudah dibaca
  static Future<int> hapusNotifDibaca(String uid) async {
    try {
      return await _hapusQuery(_db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('dibaca', isEqualTo: true));
    } catch (_) {
      return 0;
    }
  }
}
