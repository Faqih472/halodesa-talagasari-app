import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../dashboard_admin/controllers/announcement_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class WargaHomeView extends StatelessWidget {
  final announceC = Get.put(AnnouncementController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Informasi Desa Talagasari"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(onPressed: () => Get.find<AuthController>().logout(), icon: const Icon(Icons.logout))
        ],
      ),
      body: StreamBuilder(
        stream: announceC.streamWarga(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada informasi."));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var data = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(data.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data.isi),
                  trailing: const Icon(Icons.info_outline, color: Colors.teal),
                ),
              );
            },
          );
        },
      ),
    );
  }
}