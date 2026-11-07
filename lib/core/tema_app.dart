import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Satu pilihan tema warna aplikasi.
class TemaWarna {
  final String id, nama, warna;
  final Color utama, terang, gelap, latar, swatch;
  const TemaWarna(this.id, this.nama, this.warna, this.utama, this.terang,
      this.gelap, this.latar, {Color? swatch})
      : swatch = swatch ?? utama;
}

class TemaApp {
  static const _kunci = 'tema_warna';
  static final RxString aktif = 'desa'.obs;

  static const List<TemaWarna> daftar = [
    TemaWarna('desa', 'Hijau Desa', 'Hijau (bawaan)', Color(0xFF2F6F4E),
        Color(0xFF5FA37B), Color(0xFF1B4A33), Color(0xFFFAF6EC)),
    TemaWarna('crimson', 'Crimson Aurora', 'Merah', Color(0xFFC62839),
        Color(0xFFE8606E), Color(0xFF8E1424), Color(0xFFFFF5F5)),
    TemaWarna('inferno', 'Inferno Bloom', 'Oranye', Color(0xFFE8590C),
        Color(0xFFFF8A4C), Color(0xFFA33C00), Color(0xFFFFF6EE)),
    TemaWarna('solar', 'Solar Flare', 'Kuning', Color(0xFFC79100),
        Color(0xFFF2C230), Color(0xFF8A6400), Color(0xFFFFFBE8),
        swatch: Color(0xFFFFC800)),
    TemaWarna('emerald', 'Emerald Mist', 'Hijau', Color(0xFF0E9F6E),
        Color(0xFF4CD3A0), Color(0xFF066747), Color(0xFFF1FBF6)),
    TemaWarna('nebula', 'Blue Nebula', 'Biru', Color(0xFF2563EB),
        Color(0xFF6B9BFF), Color(0xFF173D99), Color(0xFFF2F6FF)),
    TemaWarna('neon', 'Neon Frost', 'Cyan', Color(0xFF0891B2),
        Color(0xFF3FD0EE), Color(0xFF065D75), Color(0xFFF0FBFE),
        swatch: Color(0xFF00E5FF)),
    TemaWarna('oceanic', 'Oceanic Void', 'Biru Tua', Color(0xFF14306B),
        Color(0xFF3F61A8), Color(0xFF0A1B42), Color(0xFFF1F4FA)),
    TemaWarna('eclipse', 'Purple Eclipse', 'Ungu', Color(0xFF7C3AED),
        Color(0xFFA879FF), Color(0xFF4F1FA3), Color(0xFFF7F3FF)),
    TemaWarna('stardust', 'Pink Stardust', 'Pink', Color(0xFFDB4F87),
        Color(0xFFFF8DB8), Color(0xFF9E2A5C), Color(0xFFFFF4F8)),
    TemaWarna('rift', 'Magenta Rift', 'Magenta', Color(0xFFB5179E),
        Color(0xFFE05BCB), Color(0xFF7A0A6A), Color(0xFFFFF2FC),
        swatch: Color(0xFFFF00C8)),
    TemaWarna('genesis', 'Aqua Genesis', 'Turquoise', Color(0xFF0F9D94),
        Color(0xFF46D6CB), Color(0xFF096A64), Color(0xFFF0FCFB),
        swatch: Color(0xFF1ED6C8)),
    TemaWarna('toxic', 'Toxic Bloom', 'Lime', Color(0xFF5E9E0A),
        Color(0xFF9BD93A), Color(0xFF3B6804), Color(0xFFF7FDEB),
        swatch: Color(0xFFA6E22E)),
    TemaWarna('terra', 'Terra Ember', 'Cokelat', Color(0xFF7B4A2D),
        Color(0xFFB07650), Color(0xFF4E2B16), Color(0xFFFBF5EF)),
    TemaWarna('cosmos', 'Golden Cosmos', 'Gold', Color(0xFFB8860B),
        Color(0xFFE6B84A), Color(0xFF7D5A05), Color(0xFFFFF9EA),
        swatch: Color(0xFFD4AF37)),
    TemaWarna('nova', 'White Nova', 'Putih', Color(0xFF4A5568),
        Color(0xFF8795A8), Color(0xFF2D3748), Color(0xFFFFFFFF),
        swatch: Color(0xFFFFFFFF)),
    TemaWarna('phantom', 'Midnight Phantom', 'Hitam', Color(0xFF1C1C24),
        Color(0xFF4A4A57), Color(0xFF0B0B10), Color(0xFFF3F3F6)),
    TemaWarna('storm', 'Titanium Storm', 'Abu-abu', Color(0xFF5F6B76),
        Color(0xFF98A4AE), Color(0xFF3A434B), Color(0xFFF4F6F7)),
    TemaWarna('lunar', 'Lunar Steel', 'Silver', Color(0xFF78828C),
        Color(0xFFC0C7CE), Color(0xFF4B545C), Color(0xFFF8F9FA),
        swatch: Color(0xFFC0C0C0)),
  ];

  static TemaWarna get sekarang =>
      daftar.firstWhere((t) => t.id == aktif.value, orElse: () => daftar.first);

  static bool get bawaan => aktif.value == 'desa';

  static void muat() {
    try {
      aktif.value = GetStorage().read<String>(_kunci) ?? 'desa';
    } catch (_) {}
  }

  static void pilih(String id) {
    aktif.value = id;
    try {
      GetStorage().write(_kunci, id);
    } catch (_) {}
  }
}
