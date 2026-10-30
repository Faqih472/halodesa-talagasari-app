// ============================================================
// app_contact.dart — Konfigurasi desa (GANTI sesuai kondisi nyata)
// Format nomor: kode negara tanpa "+" dan tanpa 0 di depan (62812...).
// ============================================================

class AppContact {
  // Pusat Bantuan
  static const String adminNama = 'Admin Desa Talagasari';
  static const String adminTelp = '6281234567890';

  static const String kadesNama = 'Kepala Desa Talagasari';
  static const String kadesTelp = '6281234567891';

  // Nomor penting (halaman SOS) — ganti dengan nomor setempat
  static const List<Map<String, String>> nomorPenting = [
    {'nama': 'Polisi', 'nomor': '110'},
    {'nama': 'Ambulans / Gawat Darurat', 'nomor': '119'},
    {'nama': 'Pemadam Kebakaran', 'nomor': '113'},
    {'nama': 'Puskesmas Cikupa', 'nomor': '02159000000'},
    {'nama': 'Ketua RT / Hansip setempat', 'nomor': '6281234567892'},
  ];


  // Identitas desa untuk kop surat
  static const String kopPemerintah = 'PEMERINTAH KABUPATEN TANGERANG';
  static const String kopKecamatan = 'KECAMATAN CIKUPA';
  static const String kopDesa = 'DESA TALAGASARI';
  static const String kopAlamat =
      'Jl. Raya Talagasari, Kec. Cikupa, Kab. Tangerang, Banten';
}
