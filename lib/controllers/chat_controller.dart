// ============================================================
// chat_controller.dart — ChatController + NotificationController
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../core/models.dart';
import 'auth_controller.dart';

// ============================================================
// chat_controller.dart
// Modul Komunikasi Real-time (Elisitasi #23-27)
// - Room ID deterministik: "uidTerkecil_uidTerbesar" (tanpa query)
// - Firestore Realtime Listener untuk daftar chat & pesan
// - Badge belum-dibaca per pengguna
// ============================================================

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  final RxList<ChatRoomModel> daftarChat = <ChatRoomModel>[].obs;
  final RxString errorMsg = ''.obs;

  StreamSubscription? _roomSub;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (user) {
      if (user != null) {
        listenMyRooms();
      } else {
        _roomSub?.cancel();
        daftarChat.clear();
      }
    });
    if (_authCtrl.currentUser.value != null) listenMyRooms();
  }

  @override
  void onClose() {
    _roomSub?.cancel();
    super.onClose();
  }

  /// ID room deterministik agar 1 pasangan pengguna selalu punya 1 room
  /// yang sama tanpa perlu query pencarian.
  String buatRoomId(String uidA, String uidB) {
    final list = [uidA, uidB]..sort();
    return '${list[0]}_${list[1]}';
  }

  // ─── Dengarkan semua room milik pengguna (realtime) ──────
  void listenMyRooms() {
    final myUid = _authCtrl.currentUser.value?.uid;
    if (myUid == null) {
      daftarChat.clear();
      return;
    }
    _roomSub?.cancel();
    _roomSub = _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .listen((snap) {
      final list =
          snap.docs.map((d) => ChatRoomModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final wa = a.waktuTerakhir ?? DateTime(2000);
        final wb = b.waktuTerakhir ?? DateTime(2000);
        return wb.compareTo(wa);
      });
      daftarChat.value = list;
    }, onError: (e) {
      errorMsg.value = 'Gagal memuat daftar obrolan: $e';
    });
  }

  int get totalUnread {
    final myUid = _authCtrl.currentUser.value?.uid;
    if (myUid == null) return 0;
    return daftarChat.fold<int>(0, (sum, r) => sum + r.unreadUntuk(myUid));
  }

  // ─── Buka room yang sudah ada, atau buat baru bila belum ─
  Future<ChatRoomModel> bukaAtauBuatRoom({
    required String otherUid,
    required String otherNama,
    required String otherFoto,
  }) async {
    final me = _authCtrl.currentUser.value!;
    final roomId = buatRoomId(me.uid, otherUid);
    final ref = _firestore.collection('chat_rooms').doc(roomId);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'participants': [me.uid, otherUid],
        'nama_pengguna': {me.uid: me.nama, otherUid: otherNama},
        'foto_pengguna': {me.uid: me.fotoUrl, otherUid: otherFoto},
        'pesan_terakhir': '',
        'waktu_terakhir': Timestamp.fromDate(DateTime.now()),
        'id_pengirim_terakhir': '',
        'unread_count': {me.uid: 0, otherUid: 0},
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    }

    final finalSnap = await ref.get();
    return ChatRoomModel.fromFirestore(finalSnap);
  }

  // ─── Stream pesan realtime dalam satu room ───────────────
  Stream<List<MessageModel>> pesanStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('waktu', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromFirestore(d)).toList());
  }

  // ─── Kirim pesan ──────────────────────────────────────────
  Future<void> kirimPesan(
    String roomId,
    String isi, {
    required String otherUid,
  }) async {
    final teks = isi.trim();
    if (teks.isEmpty) return;
    final myUid = _authCtrl.currentUser.value?.uid;
    if (myUid == null) return;

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final msgRef = roomRef.collection('messages').doc();

    final batch = _firestore.batch();
    batch.set(msgRef, {
      'idPengirim': myUid,
      'isi': teks,
      'waktu': Timestamp.fromDate(DateTime.now()),
      'sudahDibaca': false,
    });
    batch.update(roomRef, {
      'pesan_terakhir': teks,
      'waktu_terakhir': Timestamp.fromDate(DateTime.now()),
      'id_pengirim_terakhir': myUid,
      'unread_count.$otherUid': FieldValue.increment(1),
    });

    try {
      await batch.commit();
    } catch (e) {
      errorMsg.value = 'Gagal mengirim pesan: $e';
      return;
    }

    try {
      await Get.find<NotificationController>().kirimKe(
        uidTujuan: otherUid,
        judul: 'Pesan baru dari ${_authCtrl.currentUser.value?.nama ?? ''}',
        isi: teks,
        tipe: 'chat',
        targetId: roomId,
      );
    } catch (_) {}
  }

  // ─── Tandai seluruh pesan masuk sebagai sudah dibaca ─────
  Future<void> tandaiDibaca(String roomId) async {
    final myUid = _authCtrl.currentUser.value?.uid;
    if (myUid == null) return;
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'unread_count.$myUid': 0,
      });

      final unread = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .where('sudahDibaca', isEqualTo: false)
          .limit(50)
          .get();

      if (unread.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final d in unread.docs) {
        if (d.data()['idPengirim'] != myUid) {
          batch.update(d.reference, {'sudahDibaca': true});
        }
      }
      await batch.commit();
    } catch (_) {}
  }
}


// ============================================================
// notification_controller.dart
// Pusat notifikasi dalam-aplikasi, realtime via Firestore.
// Dipakai oleh DataController (approve/reject info),
// ServiceController (verifikasi jasa & ulasan baru), dan
// ChatController (pesan baru masuk).
// ============================================================

class NotificationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authCtrl = Get.find<AuthController>();

  final RxList<AppNotification> daftar = <AppNotification>[].obs;
  final RxInt unreadCount = 0.obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    ever(_authCtrl.currentUser, (user) {
      if (user != null) {
        _listen(user.uid);
      } else {
        _sub?.cancel();
        daftar.clear();
        unreadCount.value = 0;
      }
    });
    if (_authCtrl.currentUser.value != null) {
      _listen(_authCtrl.currentUser.value!.uid);
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listen(String uid) {
    _sub?.cancel();
    _sub = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      final list =
          snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
      daftar.value = list;
      unreadCount.value = list.where((n) => !n.dibaca).length;
    }, onError: (_) {});
  }

  /// Kirim notifikasi ke pengguna lain (dipanggil dari controller lain)
  Future<void> kirimKe({
    required String uidTujuan,
    required String judul,
    required String isi,
    String tipe = 'info',
    String? targetId,
  }) async {
    if (uidTujuan.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uidTujuan)
          .collection('notifications')
          .add({
        'judul': judul,
        'isi': isi,
        'tipe': tipe,
        'target_id': targetId,
        'dibaca': false,
        'created_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // Notifikasi bersifat pelengkap, kegagalan tidak boleh mengganggu
      // alur utama (approve, chat, dsb).
    }
  }

  Future<void> tandaiDibaca(String id) async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .update({'dibaca': true});
    } catch (_) {}
  }

  Future<void> tandaiSemuaDibaca() async {
    final uid = _authCtrl.currentUser.value?.uid;
    if (uid == null) return;
    try {
      final batch = _firestore.batch();
      for (final n in daftar.where((n) => !n.dibaca)) {
        batch.update(
          _firestore
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(n.id),
          {'dibaca': true},
        );
      }
      await batch.commit();
    } catch (_) {}
  }
}
