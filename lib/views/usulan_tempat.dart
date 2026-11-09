import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/core.dart';
import '../core/ui_helpers.dart';
import 'info_sosial.dart' show GaleriFoto;

/// Bagian "Terkait tempat tertentu?" untuk usulan: alamat baku, titik peta, foto.
/// Semuanya OPSIONAL. Peta tidak terisi otomatis dari lokasi pengguna.
class TempatUsulan {
  final int maksFoto;
  TempatUsulan({this.maksFoto = 3});

  final AlamatDesaCtrl alamat = AlamatDesaCtrl();
  bool pakaiPeta = false;
  LatLng titik = LatLng(-6.239265, 106.530200);
  List<File> foto = [];

  void dispose() => alamat.dispose();

  bool get adaAlamat =>
      alamat.perum.text.trim().isNotEmpty ||
      alamat.blok.text.trim().isNotEmpty ||
      alamat.nomor.text.trim().isNotEmpty ||
      alamat.jalan.text.trim().isNotEmpty ||
      alamat.kampung.text.trim().isNotEmpty;

  /// Data siap simpan ke Firestore (gabungkan ke dokumen usulan).
  Future<Map<String, dynamic>> data() async {
    final urls = <String>[];
    for (final f in foto.take(maksFoto)) {
      final e = await ImageUtil.encode(f);
      if (e != null) urls.add(e);
    }
    return {
      'alamat': adaAlamat ? alamat.teks : '',
      'lat': pakaiPeta ? titik.latitude : 0.0,
      'lng': pakaiPeta ? titik.longitude : 0.0,
      'foto_list': urls,
    };
  }

  Widget bangun(StateSetter setS, Color warna) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      BlokAlamatDesa(c: alamat, wajib: false),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: pakaiPeta,
        onChanged: (v) => setS(() => pakaiPeta = v),
        title: const Text('Tandai titik di peta (opsional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: const Text('Ketuk peta, tombol Lokasi saya, atau Cari alamat.',
            style: TextStyle(fontSize: 12)),
      ),
      if (pakaiPeta) PemilihPeta(titik: titik, warna: warna, onChanged: (p) => titik = p),
      const SizedBox(height: 8),
      FotoPicker(
        maks: maksFoto,
        label: maksFoto == 1 ? 'Foto (opsional, maksimal 1)' : 'Foto (opsional, maksimal $maksFoto)',
        bantuan: 'Contoh: foto jalan rusak, denah lokasi, atau poster acara.',
        onChanged: (baru, lama) => foto = baru,
      ),
    ]);
  }
}

/// Tampilan alamat + foto + titik pada kartu usulan (untuk pembaca/staf).
Widget infoTempatUsulan(Map<String, dynamic> m) {
  final alamat = '${m['alamat'] ?? ''}';
  final foto = (m['foto_list'] is List) ? (m['foto_list'] as List).map((e) => '$e').toList() : <String>[];
  final lat = (m['lat'] as num?)?.toDouble() ?? 0;
  final lng = (m['lng'] as num?)?.toDouble() ?? 0;
  if (alamat.isEmpty && foto.isEmpty && lat == 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (alamat.isNotEmpty)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.place_outlined, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text(alamat, style: const TextStyle(fontSize: 12.5))),
        ]),
      if (lat != 0 || lng != 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('Titik peta: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11.5)),
        ),
      if (foto.isNotEmpty) ...[
        const SizedBox(height: 6),
        GaleriFoto(foto: foto),
      ],
    ]),
  );
}
