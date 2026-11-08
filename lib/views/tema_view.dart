import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../core/tema_app.dart';

/// Tiga pilihan terpisah: warna tema (bagian atas dan tombol),
/// warna latar (layar dan kartu), dan warna teks.
class TemaView extends StatelessWidget {
  const TemaView({super.key});

  void _segarkan() {
    Get.changeTheme(AppTheme.buildTheme(TemaApp.rol.value));
    Get.forceAppUpdate();
  }

  Widget _sat(RxInt n) => Row(children: [
        const Icon(Icons.opacity, size: 18),
        const SizedBox(width: 6),
        const Text('Saturasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Expanded(
          child: Slider(
            min: 0,
            max: 100,
            divisions: 100,
            value: n.value.toDouble(),
            onChanged: (v) => n.value = v.round(),
            onChangeEnd: (_) {
              TemaApp.simpanSat();
              _segarkan();
            },
          ),
        ),
        SizedBox(
            width: 44,
            child: Text('${n.value}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
      ]);

  Widget _judul(String t, String sub) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        ]),
      );

  /// Grid pilihan. [warnaDari] menentukan warna lingkaran tiap pilihan.
  Widget _grid(String aktif, void Function(String) pilih, Color Function(TemaWarna) warnaDari,
      {required String namaDefault, required Color warnaDefault}) {
    final item = <(String, String, String, Color)>[
      ('default', namaDefault, 'Bawaan', warnaDefault),
      for (final x in TemaApp.daftar.skip(1)) (x.id, x.nama, x.warna, warnaDari(x)),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: [
        for (final x in item)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => pilih(x.$1),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: x.$1 == aktif ? TemaApp.sekarang.utama : const Color(0xFFE3E3E3),
                    width: x.$1 == aktif ? 2.5 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: x.$4,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                  child: x.$1 == aktif
                      ? Icon(Icons.check_rounded,
                          color: x.$4.computeLuminance() > 0.6 ? Colors.black87 : Colors.white)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(x.$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                Text(x.$3, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              ]),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = TemaApp.sekarang;
      final la = TemaApp.latarId.value;
      final te = TemaApp.teksId.value;
      return Scaffold(
        appBar: AppBar(title: const Text('Tema Aplikasi')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          // Pratinjau langsung: gabungan ketiga pilihan
          Container(
            decoration: BoxDecoration(
              color: TemaApp.warnaLatar,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: t.utama,
                child: Row(children: [
                  const Icon(Icons.menu, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(t.nama,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: TemaApp.warnaKartu, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  CircleAvatar(backgroundColor: t.swatch, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Contoh kartu info desa. Warna teks ini ikut pilihan Anda.',
                        style: TextStyle(color: TemaApp.warnaTeks, fontSize: 13.5)),
                  ),
                ]),
              ),
            ]),
          ),
          _judul('1. Warna tema', 'Bagian atas, tombol, dan ikon utama'),
          _grid(t.id, (id) {
            TemaApp.pilih(id);
            _segarkan();
          }, (x) => x.swatch, namaDefault: 'Hijau Desa', warnaDefault: TemaApp.daftar.first.utama),
          _sat(TemaApp.satTema),
          _judul('2. Warna latar', 'Layar dan kartu yang sekarang putih/krem'),
          _grid(la, (id) {
            TemaApp.pilihLatar(id);
            _segarkan();
          }, (x) => TemaApp.latarContoh(x),
              namaDefault: 'Krem Putih', warnaDefault: const Color(0xFFFAF6EC)),
          _sat(TemaApp.satLatar),
          _judul('3. Warna teks', 'Tulisan utama (judul, isi, nama)'),
          _grid(te, (id) {
            TemaApp.pilihTeks(id);
            _segarkan();
          }, (x) => TemaApp.teksDari(x),
              namaDefault: 'Gelap Biasa', warnaDefault: const Color(0xFF2B2A22)),
          _sat(TemaApp.satTeks),
        ]),
      );
    });
  }
}
