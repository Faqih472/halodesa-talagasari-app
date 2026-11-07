import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../core/tema_app.dart';

/// Layar pilih tema warna. Saat dipilih, seluruh aplikasi berubah warna.
class TemaView extends StatelessWidget {
  const TemaView({super.key});

  void _pilih(String id) {
    TemaApp.pilih(id);
    Get.changeTheme(AppTheme.buildTheme('warga'));
    Get.forceAppUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = TemaApp.sekarang;
      return Scaffold(
        appBar: AppBar(title: const Text('Tema Aplikasi')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          // Pratinjau langsung
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.gelap, t.utama, t.terang]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    color: t.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.nama,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('Warna ${t.warna}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () {},
                    child: const Text('Tombol'))),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () {},
                    child: const Text('Tombol garis'))),
          ]),
          const SizedBox(height: 18),
          const Text('Pilih warna',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
            children: [
              for (final x in TemaApp.daftar)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pilih(x.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: x.id == t.id ? x.utama : const Color(0xFFE3E3E3),
                          width: x.id == t.id ? 2.5 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [x.swatch, Color.lerp(x.swatch, x.gelap, .45)!]),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                        child: x.id == t.id
                            ? Icon(Icons.check_rounded,
                                color: x.id == 'nova' || x.id == 'lunar' || x.id == 'solar'
                                    ? Colors.black87
                                    : Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(x.nama,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      Text(x.warna,
                          style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                    ]),
                  ),
                ),
            ],
          ),
        ]),
      );
    });
  }
}
