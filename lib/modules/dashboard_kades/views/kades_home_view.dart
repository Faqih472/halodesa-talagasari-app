import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../dashboard_admin/controllers/announcement_controller.dart';

class KadesHomeView extends StatelessWidget {
  final announceC = Get.put(AnnouncementController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kades: Persetujuan Berita"), backgroundColor: Colors.blueGrey),
      body: StreamBuilder(
        stream: announceC.streamKades(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Tidak ada antrean berita."));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var data = snapshot.data![index];
              return ListTile(
                title: Text(data.judul),
                subtitle: Text("Dari: ${data.author}"),
                trailing: ElevatedButton(
                  onPressed: () => announceC.approveAnnouncement(data.id),
                  child: const Text("Approve"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}