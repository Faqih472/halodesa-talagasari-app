// ============================================================
// ui_helpers.dart — Fungsi tampilan kecil yang dipakai bersama
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputFormatter, TextEditingValue, TextSelection;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'motif.dart' show kartuTalagasari;
import 'core.dart'
    show AppUtils, AppTheme, ImageUtil, tambahBulan, batasMaksBerlaku, labelSisaWaktu;

void showSnack(bool ok, String okMsg, String errMsg, {String? okTitle}) {
  Get.snackbar(
    ok ? (okTitle ?? 'success'.tr) : 'failed'.tr,
    ok ? okMsg : errMsg,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}

Widget loadingChild() => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

/// Dialog isian teks. Mengembalikan null bila dibatalkan.
Future<String?> mintaTeks(String judul, String label, {int minHuruf = 3}) async {
  final ctrl = TextEditingController();
  final hasil = await Get.dialog<String>(
    AlertDialog(
      title: Text(judul),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().length < minHuruf) return;
            Get.back(result: ctrl.text.trim());
          },
          child: Text('cmp_send'.tr),
        ),
      ],
    ),
  );
  return hasil;
}

/// Buka WhatsApp / telepon / peta di aplikasi luar
Future<void> bukaUri(Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) showSnack(false, '', 'help_failed'.tr);
  } catch (_) {
    showSnack(false, '', 'help_failed'.tr);
  }
}

Uri uriTelp(String nomor) => Uri(scheme: 'tel', path: nomor.startsWith('62') ? '+$nomor' : nomor);

Uri uriPeta(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

/// Kartu putih membulat standar
/// Kartu daftar bergaris warna di kiri (gaya Beranda), dipakai di Jasa/Lowongan/Lapak.
Widget kartuGaris({required Widget child, required Color warna, VoidCallback? onTap, EdgeInsets? margin}) {
  return Container(
    margin: margin ?? const EdgeInsets.fromLTRB(16, 7, 16, 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: warna.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 5))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: warna, width: 5))),
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget kartu({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
  return Container(
    margin: margin ?? const EdgeInsets.fromLTRB(16, 6, 16, 6),
    padding: padding ?? const EdgeInsets.all(14),
    decoration: kartuTalagasari(radius: 18),
    child: child,
  );
}


/// Pilihan "Berlaku sampai" untuk informasi (masa tayang). WAJIB diisi.
/// Pilihan cepat: 3 hari, 1 minggu, 2 minggu, 1/3/6/9/12 bulan, atau Kustom
/// (pilih tanggal sendiri). Maksimal 12 bulan dari hari ini.
class ExpiryPicker extends StatefulWidget {
  final DateTime? initial;
  final bool wajib; // dipertahankan untuk kompatibilitas; kini selalu wajib
  final ValueChanged<DateTime?> onChanged;
  const ExpiryPicker(
      {super.key, this.initial, this.wajib = true, required this.onChanged});

  @override
  State<ExpiryPicker> createState() => _ExpiryPickerState();
}

class _ExpiryPickerState extends State<ExpiryPicker> {
  late DateTime _tgl;
  String _pilihan = ''; // kunci chip yang aktif; 'kustom' bila tanggal manual

  static DateTime _akhirHari(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59);

  // kunci → (label, fungsi tanggal)
  static final List<_OpsiMasa> _opsi = [
    _OpsiMasa('3h', '3 hari', (n) => _akhirHari(n.add(const Duration(days: 3)))),
    _OpsiMasa('1m', '1 minggu', (n) => _akhirHari(n.add(const Duration(days: 7)))),
    _OpsiMasa('2m', '2 minggu', (n) => _akhirHari(n.add(const Duration(days: 14)))),
    _OpsiMasa('1b', '1 bulan', (n) => tambahBulan(n, 1)),
    _OpsiMasa('3b', '3 bulan', (n) => tambahBulan(n, 3)),
    _OpsiMasa('6b', '6 bulan', (n) => tambahBulan(n, 6)),
    _OpsiMasa('9b', '9 bulan', (n) => tambahBulan(n, 9)),
    _OpsiMasa('12b', '12 bulan', (n) => tambahBulan(n, 12)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final awal = widget.initial;
    if (awal != null && awal.isAfter(now)) {
      _tgl = awal;
      _pilihan = 'kustom';
    } else {
      _tgl = _opsi[2].hitung(now); // default 2 minggu
      _pilihan = '2m';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_tgl);
    });
  }

  void _pakai(_OpsiMasa o) {
    final maks = batasMaksBerlaku();
    var d = o.hitung(DateTime.now());
    if (d.isAfter(maks)) d = maks;
    setState(() {
      _tgl = d;
      _pilihan = o.kunci;
    });
    widget.onChanged(_tgl);
  }

  Future<void> _kustom() async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _tgl.isBefore(now) ? now : _tgl,
      firstDate: now,
      lastDate: batasMaksBerlaku(),
      helpText: 'Pilih tanggal berakhir (maks. 1 tahun)',
    );
    if (p == null) return;
    setState(() {
      _tgl = _akhirHari(p);
      _pilihan = 'kustom';
    });
    widget.onChanged(_tgl);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).primaryColor;
    Widget chip(String kunci, String label, VoidCallback onTap) {
      final bool aktif = _pilihan == kunci;
      return ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: aktif ? Colors.white : Colors.black87)),
        selected: aktif,
        showCheckmark: false,
        selectedColor: primary,
        backgroundColor: Colors.grey.shade200,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Masa berlaku informasi (wajib)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ..._opsi.map((o) => chip(o.kunci, o.label, () => _pakai(o))),
            chip('kustom', 'Kustom...', _kustom),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tampil sampai ${AppUtils.formatTanggal(_tgl)}  (${labelSisaWaktu(_tgl)} lagi). Setelah itu otomatis hilang dari beranda. Maksimal 1 tahun.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpsiMasa {
  final String kunci;
  final String label;
  final DateTime Function(DateTime) hitung;
  const _OpsiMasa(this.kunci, this.label, this.hitung);
}

// ─────────────────────────────────────────────────────────────
// Lihat foto layar penuh (zoom) — dipakai di semua fitur
// ─────────────────────────────────────────────────────────────
void tampilkanFoto(String url) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(child: ImageUtil.image(url, fit: BoxFit.contain)),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Foto penuh ala Facebook: seluruh gambar terlihat (tidak terpotong),
/// lebar mengikuti kartu, tinggi menyesuaikan rasio asli (maks. 520).
/// Mengetuk = zoom layar penuh.
Widget fotoFull(String url, {double radius = 10, double maksTinggi = 520}) {
  return GestureDetector(
    onTap: () => tampilkanFoto(url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: double.infinity,
        color: Colors.grey.shade100,
        constraints: BoxConstraints(maxHeight: maksTinggi),
        child: Center(
          child: ImageUtil.image(url, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}

/// Banner foto (untuk kartu/detail). Mengetuk = zoom.
Widget fotoBanner(String url, {double tinggi = 160, double radius = 10}) {
  return GestureDetector(
    onTap: () => tampilkanFoto(url),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageUtil.image(url,
          width: double.infinity, height: tinggi, fit: BoxFit.cover),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// FotoPicker — pilih foto (galeri/kamera), gratis tanpa Firebase Storage.
// Foto dikecilkan lalu disimpan sebagai teks base64 di Firestore.
//  • [fotoLama]  : foto yang sudah tersimpan (mode edit), bisa dihapus
//  • [onChanged] : (fotoBaru, fotoLamaTersisa)
// ─────────────────────────────────────────────────────────────
class FotoPicker extends StatefulWidget {
  final int maks;
  final String label;
  final String? bantuan;
  final List<String> fotoLama;
  final int lebar;
  final int mutu;
  final int maksByte;
  final bool bolehKamera;
  final void Function(List<File> baru, List<String> lamaTersisa) onChanged;

  const FotoPicker({
    super.key,
    required this.onChanged,
    this.maks = 1,
    this.label = 'Foto (opsional)',
    this.bantuan,
    this.fotoLama = const [],
    this.lebar = 900,
    this.mutu = 55,
    this.maksByte = ImageUtil.maksByte,
    this.bolehKamera = true,
  });

  @override
  State<FotoPicker> createState() => _FotoPickerState();
}

class _FotoPickerState extends State<FotoPicker> with AutomaticKeepAliveClientMixin {
  // Tetap hidup saat form di-scroll, agar foto yang sudah dipilih tidak hilang.
  @override
  bool get wantKeepAlive => true;

  final List<File> _baru = [];
  late List<String> _lama;

  @override
  void initState() {
    super.initState();
    _lama = List<String>.from(widget.fotoLama);
  }

  int get _total => _baru.length + _lama.length;

  void _lapor() => widget.onChanged(List<File>.from(_baru), List<String>.from(_lama));

  Future<void> _tambah() async {
    ImageSource? sumber = ImageSource.gallery;
    if (widget.bolehKamera) {
      sumber = await Get.bottomSheet<ImageSource>(
        SafeArea(
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => Get.back(result: ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Ambil dengan kamera'),
                  onTap: () => Get.back(result: ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (sumber == null) return;
    try {
      final x = await ImagePicker().pickImage(
          source: sumber, maxWidth: widget.lebar.toDouble(), imageQuality: widget.mutu);
      if (x == null) return;
      final f = File(x.path);
      if (await f.length() > widget.maksByte) {
        showSnack(false, '',
            'Foto terlalu besar. Pilih foto lain atau ambil ulang dengan resolusi lebih kecil.');
        return;
      }
      setState(() => _baru.add(f));
      _lapor();
    } catch (e) {
      showSnack(false, '', 'Tidak dapat memilih foto: $e');
    }
  }

  Widget _kotak(Widget isi, VoidCallback hapus) => Stack(
        children: [
          Container(
            width: 84,
            height: 84,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: isi,
          ),
          Positioned(
            top: 2,
            right: 10,
            child: GestureDetector(
              onTap: hapus,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_total < widget.maks)
                GestureDetector(
                  onTap: _tambah,
                  child: Container(
                    width: 84,
                    height: 84,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primary.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        color: primary),
                  ),
                ),
              ..._lama.asMap().entries.map((e) => _kotak(
                    ImageUtil.image(e.value, width: 84, height: 84),
                    () {
                      setState(() => _lama.removeAt(e.key));
                      _lapor();
                    },
                  )),
              ..._baru.asMap().entries.map((e) => _kotak(
                    Image.file(e.value, width: 84, height: 84, fit: BoxFit.cover),
                    () {
                      setState(() => _baru.removeAt(e.key));
                      _lapor();
                    },
                  )),
            ],
          ),
        ),
        if (widget.bantuan != null) ...[
          const SizedBox(height: 4),
          Text(widget.bantuan!,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary, height: 1.3)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ALASAN PENOLAKAN TERSTRUKTUR
// Setiap pengajuan yang ditolak Admin/Kades wajib memilih alasan baku
// (atau "Lainnya" + teks). Hasilnya dicatat di notifikasi pemohon dan di
// Log Keputusan agar bisa ditelusuri.
// ─────────────────────────────────────────────────────────────
class AlasanTolak {
  static const String lainnya = 'Lainnya';

  static const Map<String, List<String>> daftar = {
    'informasi': [
      'Data belum lengkap',
      'Isi tidak jelas / teks asal-asalan',
      'Bukan informasi untuk Desa Talagasari',
      'Duplikat dengan informasi yang sudah ada',
      'Mengandung hoaks / SARA / promosi berlebihan',
      'Masa berlaku tidak sesuai',
    ],
    'jasa': [
      'Data profil belum lengkap',
      'Deskripsi tidak jelas / asal-asalan',
      'Kategori jasa tidak sesuai',
      'Bukan warga / lokasi di luar Desa Talagasari',
      'Foto tidak pantas atau tidak sesuai',
      'Terindikasi data palsu',
    ],
    'pengaduan': [
      'Data belum lengkap / kurang bukti',
      'Isi laporan tidak jelas / asal-asalan',
      'Bukan kewenangan pemerintah desa',
      'Laporan duplikat',
      'Laporan sudah pernah ditangani',
      'Terindikasi laporan tidak benar',
    ],
    'ktp': [
      'Data tidak sesuai dengan KTP / data kependudukan',
      'Foto KTP tidak jelas / terpotong',
      'NIK tidak valid',
      'Bukan penduduk Desa Talagasari',
      'Data belum lengkap',
    ],
    'lowongan': [
      'Pekerjaan tidak jelas / deskripsi asal-asalan',
      'Meminta uang dari pelamar',
      'Upah tidak wajar atau menyesatkan',
      'Bukan untuk warga / lokasi di luar Desa Talagasari',
      'Mengandung unsur SARA / dewasa / melanggar hukum',
      'Data kontak tidak valid',
    ],
    'foto': [
      'Foto tidak pantas / mengandung unsur dewasa',
      'Bukan foto wajah',
      'Foto buram / tidak jelas',
      'Mengandung SARA / kekerasan',
      'Menggunakan foto orang lain / tokoh terkenal',
    ],
    'hapus': [
      'Alasan penghapusan kurang jelas',
      'Masih ada pesanan atau lamaran yang berjalan',
      'Cukup dinonaktifkan / ditutup sementara saja',
      'Data masih diperlukan untuk pemeriksaan laporan',
    ],
    'surat': [
      'Data tidak sesuai data kependudukan',
      'Keperluan surat tidak jelas',
      'Persyaratan belum lengkap',
      'Pengajuan duplikat',
      'Surat tidak diperlukan untuk keperluan tersebut',
    ],
  };
}

/// Dialog pilih alasan penolakan. Mengembalikan teks alasan siap simpan,
/// mis. "Data belum lengkap — foto KTP buram", atau null bila dibatalkan.
Future<String?> pilihAlasanTolak(String konteks, {String? judul}) async {
  final opsi = [...(AlasanTolak.daftar[konteks] ?? const <String>[]), AlasanTolak.lainnya];
  final catatanCtrl = TextEditingController();
  String? pilih;
  String? galat;

  final hasil = await Get.dialog<String>(
    StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(judul ?? 'Alasan penolakan'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih alasan yang paling sesuai. Alasan akan dikirim ke pemohon dan dicatat di Log Keputusan.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 8),
                ...opsi.map((o) => InkWell(
                      onTap: () => setD(() {
                        pilih = o;
                        galat = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              pilih == o
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: pilih == o ? Colors.red.shade700 : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(o,
                                    style: const TextStyle(fontSize: 13.5, height: 1.3))),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: catatanCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: pilih == AlasanTolak.lainnya
                        ? 'Tulis alasan (wajib)'
                        : 'Catatan tambahan (opsional)',
                  ),
                ),
                if (galat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(galat!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(100, 44)),
            onPressed: () {
              if (pilih == null) {
                setD(() => galat = 'Pilih salah satu alasan dulu.');
                return;
              }
              final cat = catatanCtrl.text.trim();
              if (pilih == AlasanTolak.lainnya && cat.length < 5) {
                setD(() => galat = 'Alasan "Lainnya" wajib ditulis (min. 5 huruf).');
                return;
              }
              final teks = pilih == AlasanTolak.lainnya
                  ? cat
                  : (cat.isEmpty ? pilih! : '$pilih — $cat');
              Get.back(result: teks);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
  return hasil;
}

/// Kebijakan masa simpan data (dalam hari). Dijalankan otomatis oleh
/// RetensiService agar database tidak dipenuhi data yang sudah tidak berguna.
class Retensi {
  static const int notifDibacaHari = 14;   // notifikasi sudah dibaca
  static const int notifMaksHari = 30;     // semua notifikasi
  static const int auditHari = 90;         // Log Keputusan
  static const int sosHari = 90;           // Riwayat SOS
  static const int laporanJasaHari = 30;   // laporan jasa yang sudah selesai
  static const int infoKadaluarsaHari = 7; // info lewat masa berlaku → dihapus
  static const int infoDitolakHari = 30;   // pengajuan info yang ditolak
  static const int umpanBalikHari = 180;   // kritik & saran warga
}


// ─────────────────────────────────────────────────────────────
// Atur foto profil bulat: geser + cubit/slider zoom, lingkaran = bagian
// yang akan tampil. Hasil: file JPG persegi kecil (siap simpan).
// ─────────────────────────────────────────────────────────────
Future<File?> potongFotoBulat(File sumber) async {
  final hasil = await Get.to<File>(() => _PotongBulatView(sumber: sumber));
  return hasil;
}

class _PotongBulatView extends StatefulWidget {
  final File sumber;
  const _PotongBulatView({required this.sumber});

  @override
  State<_PotongBulatView> createState() => _PotongBulatViewState();
}

class _PotongBulatViewState extends State<_PotongBulatView> {
  static const double _u = 300;
  final GlobalKey _kunci = GlobalKey();
  final TransformationController _tc = TransformationController();
  Size? _ukuran;
  double _skala = 1;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final bytes = await widget.sumber.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final double w = frame.image.width.toDouble();
      final double h = frame.image.height.toDouble();
      frame.image.dispose();
      final double k = _u / (w < h ? w : h);
      final Size ukr = Size(w * k, h * k);
      _tc.value = Matrix4.translationValues(
          -(ukr.width - _u) / 2, -(ukr.height - _u) / 2, 0);
      if (mounted) setState(() => _ukuran = ukr);
    } catch (_) {
      Get.back();
      showSnack(false, '', 'Foto tidak bisa dibuka. Pilih foto lain.');
    }
  }

  void _setSkala(double s) {
    final Size? ukr = _ukuran;
    if (ukr == null) return;
    final Offset pusat = _tc.toScene(const Offset(_u / 2, _u / 2));
    final double tx = (_u / 2 - pusat.dx * s)
        .clamp(_u - ukr.width * s, 0.0)
        .toDouble();
    final double ty = (_u / 2 - pusat.dy * s)
        .clamp(_u - ukr.height * s, 0.0)
        .toDouble();
    _tc.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    setState(() => _skala = s);
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    setState(() => _menyimpan = true);
    try {
      final RenderRepaintBoundary b = _kunci.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image gambar = await b.toImage(pixelRatio: 1.2);
      final ByteData? data =
          await gambar.toByteData(format: ui.ImageByteFormat.png);
      final img.Image? dec = img.decodePng(data!.buffer.asUint8List());
      if (dec == null) throw 'decode';
      int mutu = 80;
      List<int> out = img.encodeJpg(dec, quality: mutu);
      while (out.length > 55 * 1024 && mutu > 40) {
        mutu -= 10;
        out = img.encodeJpg(dec, quality: mutu);
      }
      final Directory dir = await Directory.systemTemp.createTemp('foto');
      final File f = File('${dir.path}/profil.jpg');
      await f.writeAsBytes(out);
      Get.back(result: f);
    } catch (_) {
      if (mounted) setState(() => _menyimpan = false);
      showSnack(false, '', 'Gagal memotong foto. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size? ukr = _ukuran;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Atur Foto Profil'),
      ),
      body: ukr == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      'Geser dan cubit foto agar wajah pas di dalam lingkaran. Bagian di luar lingkaran tidak akan tampil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: _u,
                    height: _u,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _kunci,
                          child: ClipRect(
                            child: SizedBox(
                              width: _u,
                              height: _u,
                              child: InteractiveViewer(
                                transformationController: _tc,
                                constrained: false,
                                minScale: 1,
                                maxScale: 5,
                                boundaryMargin: EdgeInsets.zero,
                                onInteractionUpdate: (_) {
                                  final double s = _tc.value
                                      .getMaxScaleOnAxis()
                                      .clamp(1.0, 5.0)
                                      .toDouble();
                                  if ((s - _skala).abs() > 0.01) {
                                    setState(() => _skala = s);
                                  }
                                },
                                child: SizedBox(
                                  width: ukr.width,
                                  height: ukr.height,
                                  child: Image.file(widget.sumber,
                                      fit: BoxFit.fill),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const IgnorePointer(
                          child: SizedBox(
                            width: _u,
                            height: _u,
                            child: CustomPaint(painter: _LubangBulatPainter()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _skala.clamp(1.0, 5.0).toDouble(),
                          min: 1,
                          max: 5,
                          onChanged: _setSkala,
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white70),
                    ],
                  ),
                ),
                const Spacer(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back(),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                minimumSize: const Size.fromHeight(48)),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _menyimpan ? null : _simpan,
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                            child: _menyimpan
                                ? loadingChild()
                                : const Text('Simpan Foto'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Lapisan gelap dengan lubang lingkaran + garis bantu
class _LubangBulatPainter extends CustomPainter {
  const _LubangBulatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 2;
    final Path gelap = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(gelap, Paint()..color = Colors.black.withOpacity(0.6));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
    final Paint garis = Paint()
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.35);
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), garis);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), garis);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), garis);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), garis);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Memberi titik ribuan otomatis saat mengetik angka (1500000 -> 1.500.000).
class RibuanFormatter extends TextInputFormatter {
  static String format(num n) {
    final d = n.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write('.');
      b.write(d[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return const TextEditingValue(text: '');
    final t = format(int.parse(d));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ============================================================
// LOKASI REALTIME + PETA BERSAMA
// Aplikasi TIDAK bisa menyalakan GPS sendiri (aturan Android/iOS); bila
// GPS mati, layar pengaturan lokasi dibuka dan pengguna diberi petunjuk.
// ============================================================
class LokasiLangsung extends ChangeNotifier {
  LatLng? posisi;
  double akurasi = 0;
  bool aktif = false;
  bool mencari = false; // menunggu titik GPS pertama
  bool _pertama = true;
  bool _selesai = false;
  StreamSubscription<Position>? _sub;
  Timer? _polling;
  final void Function(LatLng p, bool pertama)? onPosisi;
  LokasiLangsung({this.onPosisi});

  static Future<void>? _izinBerjalan; // cegah dua permintaan izin bersamaan

  void _beri() {
    if (!_selesai) notifyListeners();
  }

  void _pesan(String judul, String isi) {
    if (_selesai) return;
    try {
      Get.snackbar(judul, isi,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.all(12));
    } catch (_) {}
  }

  void _terima(Position p) {
    if (_selesai) return;
    posisi = LatLng(p.latitude, p.longitude);
    akurasi = p.accuracy;
    final pertama = _pertama;
    _pertama = false;
    mencari = false;
    _beri();
    try {
      onPosisi?.call(posisi!, pertama);
    } catch (_) {}
  }

  /// Penjelasan galat yang bisa dipahami, termasuk penyebab umum.
  String _jelaskan(Object e) {
    final t = e.toString();
    if (t.contains('PermissionDefinitionsNotFound') || t.contains('permission definitions')) {
      return 'Izin lokasi belum terdaftar di AndroidManifest.xml. Pasang file AndroidManifest.xml terbaru dari update, lalu build ulang aplikasi.';
    }
    if (t.contains('LocationServiceDisabled')) {
      return 'GPS/Lokasi di HP belum menyala.';
    }
    if (t.contains('PermissionRequestInProgress')) {
      return 'Permintaan izin sedang berjalan. Tekan tombol lokasi sekali lagi.';
    }
    if (t.contains('MissingPluginException')) {
      return 'Plugin lokasi belum terpasang. Hentikan aplikasi, jalankan flutter clean, lalu flutter run lagi.';
    }
    return 'Detail: ${t.length > 120 ? t.substring(0, 120) : t}';
  }

  Future<bool> _pastikanIzin() async {
    // satu permintaan izin pada satu waktu
    while (_izinBerjalan != null) {
      try {
        await _izinBerjalan;
      } catch (_) {}
    }
    final c = Completer<void>();
    _izinBerjalan = c.future;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _pesan('GPS belum menyala',
            'Nyalakan Lokasi/GPS di HP, lalu tekan tombol lokasi lagi.');
        try {
          await Geolocator.openLocationSettings();
        } catch (_) {}
        return false;
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.deniedForever) {
        _pesan('Izin lokasi diblokir',
            'Buka Pengaturan aplikasi > Izin > Lokasi, pilih "Izinkan".');
        try {
          await Geolocator.openAppSettings();
        } catch (_) {}
        return false;
      }
      if (izin == LocationPermission.denied) {
        _pesan('Izin lokasi ditolak', 'Izinkan lokasi agar posisi Anda bisa ditandai.');
        return false;
      }
      return true;
    } catch (e) {
      _pesan('Lokasi belum bisa dipakai', _jelaskan(e));
      return false;
    } finally {
      _izinBerjalan = null;
      c.complete();
    }
  }

  /// Mulai (atau pusatkan ulang) pelacakan lokasi realtime. Tidak pernah melempar galat.
  Future<void> mulai() async {
    if (_selesai) return;
    if (aktif) {
      if (posisi != null) {
        try {
          onPosisi?.call(posisi!, true);
        } catch (_) {}
      }
      return;
    }
    mencari = true;
    _beri();
    try {
      if (!await _pastikanIzin()) {
        mencari = false;
        _beri();
        return;
      }
      // 1) titik tercepat: posisi terakhir yang MASIH BARU (maks 2 menit)
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp).inMinutes < 2) {
          _terima(last);
        }
      } catch (_) {}
      // 2) titik segar dari GPS
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        _terima(p);
      } catch (_) {}
      if (_selesai) return;
      aktif = true;
      _beri();
      _mulaiStream();
      if (posisi == null) {
        Future.delayed(const Duration(seconds: 12), () {
          if (!_selesai && aktif && posisi == null) {
            _pesan('Sinyal GPS lemah', 'Masih mencari lokasi. Pindah ke tempat terbuka.');
          }
        });
      }
    } catch (e) {
      _pesan('Lokasi gagal', _jelaskan(e));
      mencari = false;
      aktif = false;
    }
    _beri();
  }

  void _mulaiStream() {
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 3),
      ).listen(_terima, onError: (_) => _alihKePolling(), cancelOnError: false);
    } catch (_) {
      _alihKePolling();
    }
  }

  void _alihKePolling() {
    _sub?.cancel();
    _sub = null;
    _polling?.cancel();
    _polling = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        _terima(p);
      } catch (_) {}
    });
  }

  void berhenti() {
    _sub?.cancel();
    _sub = null;
    _polling?.cancel();
    _polling = null;
    aktif = false;
    mencari = false;
    _pertama = true;
    _beri();
  }

  @override
  void dispose() {
    _selesai = true;
    _sub?.cancel();
    _polling?.cancel();
    super.dispose();
  }
}

/// Tombol bulat "Lokasi saya" (tekan = mulai/pusatkan, tekan lama = berhenti).
class TombolLokasiSaya extends StatelessWidget {
  final LokasiLangsung lokasi;
  const TombolLokasiSaya({super.key, required this.lokasi});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lokasi,
      builder: (_, __) => Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: lokasi.mulai,
          onLongPress: lokasi.aktif ? lokasi.berhenti : null,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Tooltip(
              message: 'Lokasi saya (tekan lama untuk berhenti)',
              child: lokasi.mencari
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(lokasi.aktif ? Icons.my_location : Icons.location_searching,
                      size: 20, color: lokasi.aktif ? Colors.blue.shade700 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

/// Titik biru posisi pengguna (lapisan peta).
class LokasiSayaLayer extends StatelessWidget {
  final LokasiLangsung lokasi;
  const LokasiSayaLayer({super.key, required this.lokasi});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lokasi,
      builder: (_, __) => MarkerLayer(markers: [
        if (lokasi.posisi != null)
          Marker(
            point: lokasi.posisi!,
            width: 22,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
          ),
      ]),
    );
  }
}

/// Peta pandang (tanpa memilih titik) lengkap dengan tombol "Lokasi saya" realtime.
class PetaDenganLokasi extends StatefulWidget {
  final LatLng pusat;
  final double zoom;
  final double tinggi;
  final List<Marker> penanda;
  final bool geser;
  final VoidCallback? onTap;
  final bool ikutiPusat; // peta ikut bergerak bila titik pusat berubah (mis. SOS live)
  const PetaDenganLokasi({
    super.key,
    required this.pusat,
    required this.penanda,
    this.zoom = 15,
    this.tinggi = 150,
    this.geser = true,
    this.onTap,
    this.ikutiPusat = false,
  });

  @override
  State<PetaDenganLokasi> createState() => _PetaDenganLokasiState();
}

class _PetaDenganLokasiState extends State<PetaDenganLokasi> {
  final MapController _map = MapController();
  bool _siap = false;
  late final LokasiLangsung _gps = LokasiLangsung(
      onPosisi: (p, pertama) {
        if (pertama && _siap && mounted) {
          try {
            _map.move(p, 16);
          } catch (_) {}
        }
      });

  @override
  void didUpdateWidget(covariant PetaDenganLokasi old) {
    super.didUpdateWidget(old);
    if (widget.ikutiPusat &&
        _siap &&
        (old.pusat.latitude != widget.pusat.latitude ||
            old.pusat.longitude != widget.pusat.longitude)) {
      try {
        _map.move(widget.pusat, _map.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _gps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.tinggi,
      child: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.pusat,
            initialZoom: widget.zoom,
            onMapReady: () => _siap = true,
            interactionOptions: InteractionOptions(
                flags: widget.geser
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.pinchZoom | InteractiveFlag.drag),
            onTap: widget.onTap == null ? null : (_, __) => widget.onTap!(),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.talagasari_hub',
            ),
            MarkerLayer(markers: widget.penanda),
            LokasiSayaLayer(lokasi: _gps),
          ],
        ),
        Positioned(right: 8, top: 8, child: TombolLokasiSaya(lokasi: _gps)),
      ]),
    );
  }
}

/// Pemilih titik (pin) bersama: pengaduan, jasa, pesanan.
/// Tombol "Lokasi saya" = pin mengikuti GPS secara realtime; ketuk peta atau
/// "Cari alamat" untuk memilih titik sendiri.
class PemilihPeta extends StatefulWidget {
  final LatLng titik;
  final ValueChanged<LatLng> onChanged;
  final ValueChanged<String>? onAlamat;
  final double tinggi;
  final Color warna;
  const PemilihPeta({
    super.key,
    required this.titik,
    required this.onChanged,
    this.onAlamat,
    this.tinggi = 210,
    this.warna = Colors.red,
  });

  @override
  State<PemilihPeta> createState() => _PemilihPetaState();
}

class _PemilihPetaState extends State<PemilihPeta> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _map = MapController();
  late LatLng _titik = widget.titik;
  bool _ikuti = false;
  bool _siap = false;
  bool _alamatDiminta = false;
  late final LokasiLangsung _gps = LokasiLangsung(onPosisi: (p, pertama) {
    if (!_ikuti) return;
    _set(p, pindah: true);
    if (pertama && !_alamatDiminta && widget.onAlamat != null) {
      _alamatDiminta = true;
      _alamatDari(p);
    }
  });

  @override
  void dispose() {
    _gps.dispose();
    super.dispose();
  }

  void _set(LatLng p, {bool pindah = false}) {
    if (!mounted) return;
    setState(() => _titik = p);
    if (pindah && _siap) {
      try {
        _map.move(p, 17);
      } catch (_) {}
    }
    widget.onChanged(p);
  }

  Future<void> _mulaiIkuti() async {
    setState(() => _ikuti = true);
    await _gps.mulai();
    if (!_gps.aktif && mounted) setState(() => _ikuti = false);
  }

  void _berhentiIkuti() {
    _gps.berhenti();
    setState(() => _ikuti = false);
  }

  Future<String?> _http(Uri uri) async {
    final c = HttpClient()..userAgent = 'TalagasariHub/1.0 (aplikasi desa)';
    try {
      final req = await c.getUrl(uri).timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      return await res.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  Future<void> _alamatDari(LatLng p) async {
    final body = await _http(Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${p.latitude}',
      'lon': '${p.longitude}',
      'format': 'json',
      'zoom': '18',
    }));
    if (body == null) return;
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final nama = '${m['display_name'] ?? ''}';
      if (nama.isNotEmpty) widget.onAlamat?.call(nama);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _cari(String q) async {
    final body = await _http(Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '6',
      'countrycodes': 'id',
    }));
    if (body == null) return [];
    try {
      return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _dialogCari() async {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> hasil = [];
    bool loading = false, sudah = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> jalan() async {
            final q = ctrl.text.trim();
            if (q.isEmpty) return;
            setD(() => loading = true);
            final r = await _cari(q);
            setD(() {
              hasil = r;
              loading = false;
              sudah = true;
            });
          }

          return AlertDialog(
            title: const Text('Cari alamat'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Talagasari Cikupa',
                    suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: jalan),
                  ),
                  onSubmitted: (_) => jalan(),
                ),
                const SizedBox(height: 8),
                if (loading) const LinearProgressIndicator(),
                if (sudah && hasil.isEmpty && !loading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Tidak ditemukan. Coba kata lain atau ketuk peta.'),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: hasil
                        .map((h) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text('${h['display_name']}',
                                  maxLines: 3, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                final p = LatLng(double.parse('${h['lat']}'),
                                    double.parse('${h['lon']}'));
                                Navigator.pop(ctx);
                                if (_ikuti) _berhentiIkuti();
                                _set(p, pindah: true);
                                widget.onAlamat?.call('${h['display_name']}');
                              },
                            ))
                        .toList(),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.tinggi,
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _titik,
                  initialZoom: 16,
                  onMapReady: () => _siap = true,
                  onTap: (_, p) {
                    if (_ikuti) _berhentiIkuti();
                    _set(p);
                  },
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.talagasari_hub',
                  ),
                  LokasiSayaLayer(lokasi: _gps),
                  MarkerLayer(markers: [
                    Marker(
                      point: _titik,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 44, color: widget.warna),
                    ),
                  ]),
                  const RichAttributionWidget(attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ]),
                ],
              ),
              Positioned(
                right: 8,
                top: 8,
                child: ListenableBuilder(
                  listenable: _gps,
                  builder: (_, __) => Material(
                    color: _ikuti ? Colors.blue.shade700 : Colors.white,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _ikuti ? _berhentiIkuti : _mulaiIkuti,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: _gps.mencari
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.my_location,
                                size: 20, color: _ikuti ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _ikuti ? _berhentiIkuti : _mulaiIkuti,
              icon: Icon(_ikuti ? Icons.gps_fixed : Icons.my_location, size: 18, color: Colors.white),
              label: Text(_ikuti ? 'Mengikuti lokasi (ketuk: berhenti)' : 'Lokasi saya (realtime)',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: _ikuti ? Colors.blue.shade700 : Colors.green.shade700),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _dialogCari,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Cari alamat'),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
            _ikuti
                ? 'Pin mengikuti posisi GPS Anda. Ketuk peta untuk mengunci titik lain.'
                : 'Ketuk peta untuk memindahkan pin. ${_titik.latitude.toStringAsFixed(5)}, ${_titik.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

/// Alamat lengkap dalam batas Desa Talagasari. Desa, kecamatan, kabupaten, dan
/// provinsi TERKUNCI (tidak bisa diubah); warga mengisi kampung, RT, RW, jalan/patokan.
class AlamatDesaCtrl {
  static const String tetap = 'Desa Talagasari, Kec. Cikupa, Kab. Tangerang, Banten';
  // WAJIB: blok + nomor rumah + RT + RW. OPSIONAL: nama jalan, kampung.
  final blok = TextEditingController();
  final nomor = TextEditingController();
  final rt = TextEditingController();
  final rw = TextEditingController();
  final kampung = TextEditingController();
  final jalan = TextEditingController();

  /// Membaca kembali alamat yang pernah disimpan (Blok.. No.. , Jl.., Kp.., RT/RW) ke kolom.
  void isiDari({String jalanTeks = '', String rtTeks = '', String rwTeks = ''}) {
    var j = jalanTeks.trim();
    if (j.endsWith(tetap)) j = j.substring(0, j.length - tetap.length).trim();
    if (j.endsWith(',')) j = j.substring(0, j.length - 1);
    String b = '', n = '', k = '', r1 = '', r2 = '';
    final sisa = <String>[];
    for (final part in j.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      final mb = RegExp(r'^Blok\s+(.*?)(?:\s+No\.?\s*(.*))?$', caseSensitive: false).firstMatch(part);
      final mr = RegExp(r'^RT\s*(\d+)\s*/\s*RW\s*(\d+)$', caseSensitive: false).firstMatch(part);
      if (mb != null && b.isEmpty) {
        b = (mb.group(1) ?? '').trim();
        n = (mb.group(2) ?? '').trim();
      } else if (mr != null) {
        r1 = mr.group(1)!;
        r2 = mr.group(2)!;
      } else if (RegExp(r'^Kp\.?\s', caseSensitive: false).hasMatch(part) && k.isEmpty) {
        k = part.replaceFirst(RegExp(r'^Kp\.?\s*', caseSensitive: false), '');
      } else {
        sisa.add(part);
      }
    }
    blok.text = b;
    nomor.text = n;
    kampung.text = k;
    jalan.text = sisa.join(', ');
    rt.text = (r1.isNotEmpty ? r1 : rtTeks).replaceAll(RegExp(r'[^0-9]'), '');
    rw.text = (r2.isNotEmpty ? r2 : rwTeks).replaceAll(RegExp(r'[^0-9]'), '');
  }

  String get teks {
    final k = kampung.text.trim();
    final b = blok.text.trim();
    final n = nomor.text.trim();
    return [
      if (b.isNotEmpty || n.isNotEmpty) 'Blok ${b.isEmpty ? '-' : b}${n.isEmpty ? '' : ' No. $n'}',
      if (jalan.text.trim().isNotEmpty) jalan.text.trim(),
      if (k.isNotEmpty) (k.toLowerCase().startsWith('kp') ? k : 'Kp. $k'),
      if (rt.text.trim().isNotEmpty || rw.text.trim().isNotEmpty)
        'RT ${rt.text.trim()}/RW ${rw.text.trim()}',
      tetap,
    ].join(', ');
  }

  String? galat() {
    if (blok.text.trim().isEmpty) {
      return 'Blok / gang wajib diisi. Contoh: A3, C, atau Gang Melati.';
    }
    if (nomor.text.trim().isEmpty) {
      return 'Nomor rumah wajib diisi. Contoh: 12.';
    }
    if (rt.text.trim().isEmpty || rw.text.trim().isEmpty) {
      return 'RT dan RW wajib diisi.';
    }
    return null;
  }

  void dispose() {
    blok.dispose();
    nomor.dispose();
    rt.dispose();
    rw.dispose();
    kampung.dispose();
    jalan.dispose();
  }
}

class BlokAlamatDesa extends StatelessWidget {
  final AlamatDesaCtrl c;
  /// false = semua kolom opsional (dipakai untuk lokasi info yang tidak wajib).
  final bool wajib;
  const BlokAlamatDesa({super.key, required this.c, this.wajib = true});

  @override
  Widget build(BuildContext context) {
    final w = wajib ? ' *' : ' (opsional)';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(AlamatDesaCtrl.tetap,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 8),
        child: Text(
            wajib
                ? 'Wilayah dikunci: Desa Talagasari. Yang wajib: Blok, Nomor, RT, RW. Nama jalan dan kampung boleh dikosongkan.'
                : 'Wilayah dikunci: Desa Talagasari. Semua kolom di bawah boleh dikosongkan.',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ),
      Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: c.blok,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
                labelText: 'Blok / Gang$w', hintText: 'Contoh: A3'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: c.nomor,
            decoration: InputDecoration(labelText: 'No. rumah$w', hintText: '12'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: c.rt,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: InputDecoration(labelText: 'RT$w', counterText: ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: c.rw,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            decoration: InputDecoration(labelText: 'RW$w', counterText: ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: c.kampung,
            decoration: const InputDecoration(
                labelText: 'Kampung (opsional)', hintText: 'Kp. Talagasari'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: c.jalan,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Nama jalan / patokan (opsional)',
          hintText: 'Contoh: Jl. Mawar, depan masjid Al-Ikhlas',
        ),
      ),
    ]);
  }
}

/// Dialog pemilik mengajukan penghapusan: pilih alasan + catatan wajib (min. 10 huruf).
/// Mengembalikan teks alasan, atau null bila dibatalkan.
Future<String?> dialogAlasanHapus({
  required String judul,
  required String penjelasan,
  required List<String> opsi,
}) async {
  String pilih = opsi.first;
  final cat = TextEditingController();
  String? galat;
  final hasil = await Get.dialog<String>(StatefulBuilder(
    builder: (ctx, setD) => AlertDialog(
      title: Text(judul),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(penjelasan, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            const Text('Alasan:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: pilih,
              isExpanded: true,
              items: [for (final a in opsi) DropdownMenuItem(value: a, child: Text(a))],
              onChanged: (v) => setD(() => pilih = v ?? pilih),
            ),
            TextField(
              controller: cat,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Jelaskan alasannya (wajib)',
                  hintText: 'Contoh: usaha sudah tutup sejak bulan lalu'),
            ),
            if (galat != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(galat!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        TextButton(
          onPressed: () {
            if (cat.text.trim().length < 10) {
              setD(() => galat = 'Jelaskan alasan minimal 10 huruf.');
              return;
            }
            Get.back(result: '$pilih — ${cat.text.trim()}');
          },
          child: Text('Ajukan', style: TextStyle(color: Colors.red.shade700)),
        ),
      ],
    ),
  ));
  return hasil;
}

/// Admin menyetujui penghapusan: boleh menulis keterangan (opsional).
Future<String?> dialogKeteranganSetuju(String judul) async {
  final cat = TextEditingController(text: 'Penghapusan disetujui.');
  final hasil = await Get.dialog<String>(AlertDialog(
    title: Text(judul),
    content: TextField(
      controller: cat,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Keterangan untuk pemilik'),
    ),
    actions: [
      TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
      ElevatedButton(
          onPressed: () => Get.back(
              result: cat.text.trim().isEmpty ? 'Penghapusan disetujui.' : cat.text.trim()),
          child: const Text('Setujui hapus', style: TextStyle(color: Colors.white))),
    ],
  ));
  return hasil;
}

// ─────────────────────────────────────────────────────────────
// PETA DAFTAR: banyak titik (lapak, lowongan, dst.). Hanya yang memasang
// lokasi (opsional) yang muncul. Ketuk pin → kartu ringkas → buka detail.
// ─────────────────────────────────────────────────────────────
class TitikPeta {
  final LatLng titik;
  final String judul;
  final String sub;
  final Color warna;
  final VoidCallback onBuka;
  const TitikPeta(this.titik, this.judul, this.sub, this.warna, this.onBuka);
}

class PetaDaftar extends StatefulWidget {
  final List<TitikPeta> titik;
  final int totalItem; // jumlah semua item (termasuk yang tanpa lokasi)
  final String namaItem; // 'lapak' | 'lowongan'
  const PetaDaftar({super.key, required this.titik, required this.totalItem, required this.namaItem});

  @override
  State<PetaDaftar> createState() => _PetaDaftarState();
}

class _PetaDaftarState extends State<PetaDaftar> {
  TitikPeta? _pilih;

  @override
  Widget build(BuildContext context) {
    final t = widget.titik;
    final pusat = t.isEmpty
        ? const LatLng(-6.239265, 106.530200)
        : LatLng(
            t.map((e) => e.titik.latitude).reduce((a, b) => a + b) / t.length,
            t.map((e) => e.titik.longitude).reduce((a, b) => a + b) / t.length);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Text(
            t.isEmpty
                ? 'Belum ada ${widget.namaItem} yang menandai lokasi di peta (lokasi bersifat opsional).'
                : '${t.length} dari ${widget.totalItem} ${widget.namaItem} menandai lokasi. Ketuk pin untuk melihat.',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      if (t.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PetaDenganLokasi(
              pusat: pusat,
              zoom: 14,
              tinggi: 340,
              penanda: [
                for (final e in t)
                  Marker(
                    point: e.titik,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => setState(() => _pilih = e),
                      child: Icon(Icons.location_on,
                          size: identical(_pilih, e) ? 46 : 38, color: e.warna),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (_pilih != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: Row(children: [
            Icon(Icons.location_on, color: _pilih!.warna),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pilih!.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(_pilih!.sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: _pilih!.onBuka,
              child: const Text('Buka'),
            ),
          ]),
        ),
    ]);
  }
}
