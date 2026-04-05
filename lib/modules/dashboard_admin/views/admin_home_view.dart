import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/announcement_controller.dart';

class AdminHomeView extends StatelessWidget {
  final judulC = TextEditingController();
  final isiC = TextEditingController();
  final announceC = Get.put(AnnouncementController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin: Kelola Berita"), backgroundColor: Colors.orange ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: judulC, decoration: const InputDecoration(labelText: "Judul Berita")),
            const SizedBox(height: 10),
            TextField(controller: isiC, maxLines: 3, decoration: const InputDecoration(labelText: "Isi Berita")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => announceC.addAnnouncement(judulC.text, isiC.text),
              child: const Text("Kirim ke Kades"),
            )
          ],
        ),
      ),
    );
  }
}