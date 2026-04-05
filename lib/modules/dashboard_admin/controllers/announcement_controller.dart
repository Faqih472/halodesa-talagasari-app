import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/announcement_model.dart';

class AnnouncementController extends GetxController {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Stream untuk Warga (Hanya yang Published)
  Stream<List<AnnouncementModel>> streamWarga() {
    return firestore
        .collection('announcements')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => query.docs
        .map((doc) => AnnouncementModel.fromMap(doc.data()))
        .toList());
  }

  // Stream untuk Kades (Hanya yang Pending)
  Stream<List<AnnouncementModel>> streamKades() {
    return firestore
        .collection('announcements')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((query) => query.docs
        .map((doc) => AnnouncementModel.fromMap(doc.data()))
        .toList());
  }

  // Fungsi Admin: Tambah Berita
  Future<void> addAnnouncement(String judul, String isi) async {
    try {
      String id = firestore.collection('announcements').doc().id;
      AnnouncementModel newPost = AnnouncementModel(
        id: id,
        judul: judul,
        isi: isi,
        status: 'pending', // Otomatis pending untuk di-approve Kades
        author: 'Admin Desa',
        createdAt: DateTime.now(),
      );
      await firestore.collection('announcements').doc(id).set(newPost.toMap());
      Get.back();
      Get.snackbar("Sukses", "Berita dikirim ke Kepala Desa untuk disetujui");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  // Fungsi Kades: Approve Berita
  Future<void> approveAnnouncement(String id) async {
    await firestore.collection('announcements').doc(id).update({'status': 'published'});
  }
}