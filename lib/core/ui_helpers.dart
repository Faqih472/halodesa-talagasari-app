// ============================================================
// ui_helpers.dart — Fungsi tampilan kecil yang dipakai bersama
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
Widget kartu({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
  return Container(
    margin: margin ?? const EdgeInsets.fromLTRB(16, 6, 16, 6),
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
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

class _FotoPickerState extends State<FotoPicker> {
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
