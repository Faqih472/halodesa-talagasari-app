// ============================================================
// camera_view.dart — Kamera verifikasi identitas (gratis, tanpa Storage)
//   • Foto 1 (selfie)  : KAMERA DEPAN, pakai garis panduan kepala + badan
//                        + kotak tempat KTP yang dipegang di tangan
//   • Foto 2 (KTP)     : KTP saja, pakai bingkai persegi panjang
// Hasil dikecilkan otomatis lalu dikembalikan sebagai teks base64
// ("data:image/jpeg;base64,...") yang disimpan di Firestore.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Buka kamera. Mengembalikan data URL base64, atau null bila dibatalkan.
Future<String?> ambilFotoVerifikasi({required bool selfie}) async {
  final hasil = await Get.to<String>(() => KameraVerifikasiView(selfie: selfie));
  return hasil;
}

/// Dikecilkan di isolate terpisah supaya layar tidak macet.
Uint8List _kecilkanJpeg(Map<String, dynamic> a) {
  final Uint8List bytes = a['bytes'];
  final int lebar = a['lebar'];
  final int maks = a['maks'];
  var gambar = img.decodeImage(bytes)!;
  gambar = img.bakeOrientation(gambar);
  if (gambar.width > lebar) gambar = img.copyResize(gambar, width: lebar);
  int mutu = 80;
  var out = img.encodeJpg(gambar, quality: mutu);
  while (out.length > maks && mutu > 35) {
    mutu -= 10;
    out = img.encodeJpg(gambar, quality: mutu);
  }
  if (out.length > maks) {
    gambar = img.copyResize(gambar, width: (gambar.width * 0.8).round());
    out = img.encodeJpg(gambar, quality: 50);
  }
  return Uint8List.fromList(out);
}

class KameraVerifikasiView extends StatefulWidget {
  final bool selfie;
  const KameraVerifikasiView({super.key, required this.selfie});

  @override
  State<KameraVerifikasiView> createState() => _KameraVerifikasiViewState();
}

class _KameraVerifikasiViewState extends State<KameraVerifikasiView> {
  CameraController? _cam;
  String? _error;
  Uint8List? _hasil; // foto mentah hasil jepretan (untuk pratinjau)
  bool _proses = false;

  // selfie: kecil (kepala + KTP di tangan); KTP: besar supaya tulisan terbaca
  int get _lebar => widget.selfie ? 720 : 1280;
  int get _maks => widget.selfie ? 150 * 1024 : 300 * 1024;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    try {
      final daftar = await availableCameras();
      if (daftar.isEmpty) throw 'Kamera tidak ditemukan';
      final arah =
          widget.selfie ? CameraLensDirection.front : CameraLensDirection.back;
      final desc =
          daftar.firstWhere((c) => c.lensDirection == arah, orElse: () => daftar.first);
      final c = CameraController(desc, ResolutionPreset.high,
          enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _jepret() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      setState(() => _hasil = bytes);
    } catch (e) {
      setState(() => _error = 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _pakai(Uint8List mentah) async {
    setState(() => _proses = true);
    try {
      final kecil = await compute(_kecilkanJpeg,
          {'bytes': mentah, 'lebar': _lebar, 'maks': _maks});
      Get.back(result: 'data:image/jpeg;base64,${base64Encode(kecil)}');
    } catch (e) {
      setState(() {
        _proses = false;
        _error = 'Gagal memproses foto: $e';
      });
    }
  }

  /// Cadangan bila kamera in-app gagal: kamera bawaan HP
  Future<void> _kameraBawaan() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice:
            widget.selfie ? CameraDevice.front : CameraDevice.rear,
      );
      if (x == null) return;
      await _pakai(await x.readAsBytes());
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.selfie
        ? 'Foto 1: Selfie memegang KTP'
        : 'Foto 2: Foto KTP saja';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(judul, style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(child: _isi()),
    );
  }

  Widget _isi() {
    if (_proses) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 14),
          Text('Memproses foto...', style: TextStyle(color: Colors.white)),
        ],
      ));
    }
    if (_hasil != null) return _pratinjau(_hasil!);
    if (_error != null && _cam == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 56),
              const SizedBox(height: 12),
              Text('Kamera tidak bisa dibuka.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _kameraBawaan,
                  child: const Text('Pakai kamera bawaan HP')),
            ],
          ),
        ),
      );
    }
    final c = _cam;
    if (c == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / c.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(c),
                  CustomPaint(painter: _PanduPainter(selfie: widget.selfie)),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.selfie
                            ? 'Posisikan wajah di bulatan, bahu di garis badan, dan pegang KTP di kotak (wajah dan KTP harus jelas, jangan menutupi wajah).'
                            : 'Letakkan KTP di dalam bingkai. Pastikan semua tulisan terbaca, tidak silau, dan tidak terpotong.',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: GestureDetector(
            onTap: _jepret,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white54, width: 6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pratinjau(Uint8List bytes) {
    return Column(
      children: [
        Expanded(child: Center(child: Image.memory(bytes, fit: BoxFit.contain))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _hasil = null),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54)),
                  child: const Text('Ulangi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pakai(bytes),
                  child: const Text('Pakai foto ini',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Garis panduan di atas pratinjau kamera
class _PanduPainter extends CustomPainter {
  final bool selfie;
  _PanduPainter({required this.selfie});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final garis = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final isi = Paint()..color = Colors.black.withOpacity(0.35);

    void teks(String t, Offset pusat) {
      final tp = TextPainter(
        text: TextSpan(
            text: t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pusat - Offset(tp.width / 2, tp.height / 2));
    }

    if (selfie) {
      // kepala (oval)
      final kepala = Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.27), width: w * 0.40, height: h * 0.25);
      canvas.drawOval(kepala, garis);
      teks('WAJAH', Offset(w * 0.5, h * 0.27));
      // badan / bahu
      final badan = Path()
        ..moveTo(w * 0.05, h * 0.62)
        ..quadraticBezierTo(w * 0.05, h * 0.44, w * 0.34, h * 0.42)
        ..lineTo(w * 0.66, h * 0.42)
        ..quadraticBezierTo(w * 0.95, h * 0.44, w * 0.95, h * 0.62);
      canvas.drawPath(badan, garis);
      // KTP yang dipegang (rasio 1.586)
      final lebarKtp = w * 0.56;
      final ktp = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.60),
              width: lebarKtp,
              height: lebarKtp / 1.586),
          const Radius.circular(8));
      canvas.drawRRect(ktp, garis);
      teks('KTP DIPEGANG DI SINI', ktp.center);
    } else {
      final lebarKtp = w * 0.92;
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.5),
              width: lebarKtp,
              height: lebarKtp / 1.586),
          const Radius.circular(12));
      // gelapkan area di luar bingkai
      final luar = Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, w, h)),
        Path()..addRRect(rect),
      );
      canvas.drawPath(luar, isi);
      canvas.drawRRect(rect, garis);
      teks('BINGKAI KTP', Offset(w * 0.5, h * 0.5 - lebarKtp / 1.586 / 2 - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _PanduPainter old) => old.selfie != selfie;
}
