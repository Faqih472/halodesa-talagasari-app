// ============================================================
// motif.dart — Identitas visual "Talagasari"
// Tema: SAWAH & TELAGA
//   • Kawung   : pola batik klasik (ornamen latar)
//   • Matahari : matahari terbit di atas sawah
//   • Bukit    : perbukitan berlapis
//   • Padi     : bulir padi (lambang "sari" = inti/hasil bumi)
//   • Telaga   : gelombang air (lambang "talaga")
// Semua digambar dengan kode (CustomPainter) — tanpa file gambar.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core.dart';

// ─────────────────────────────────────────────────────────────
// Salam khas Sunda sesuai waktu
// ─────────────────────────────────────────────────────────────
String salamSunda([DateTime? waktu]) {
  final int jam = (waktu ?? DateTime.now()).hour;
  if (jam < 11) return 'Wilujeng enjing';
  if (jam < 15) return 'Wilujeng siang';
  if (jam < 18) return 'Wilujeng sonten';
  return 'Wilujeng wengi';
}

// ─────────────────────────────────────────────────────────────
// Pola Kawung
// ─────────────────────────────────────────────────────────────
class KawungPainter extends CustomPainter {
  final Color warna;
  final double sel;

  const KawungPainter({required this.warna, this.sel = 34});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint garis = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final Paint titik = Paint()
      ..color = warna
      ..style = PaintingStyle.fill;

    int baris = 0;
    for (double y = 0; y < size.height + sel; y += sel / 2) {
      final double geser = baris.isEven ? 0 : sel / 2;
      for (double x = -sel + geser; x < size.width + sel; x += sel) {
        canvas.save();
        canvas.translate(x, y);
        for (int i = 0; i < 2; i++) {
          canvas.save();
          canvas.rotate(i * math.pi / 2);
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: sel * 0.92, height: sel * 0.40),
            garis,
          );
          canvas.restore();
        }
        canvas.drawCircle(Offset.zero, 1.6, titik);
        canvas.restore();
      }
      baris++;
    }
  }

  @override
  bool shouldRepaint(covariant KawungPainter old) =>
      old.warna != warna || old.sel != sel;
}

// ─────────────────────────────────────────────────────────────
// Pemandangan header: langit gradasi + kawung + matahari +
// bukit + padi + gelombang telaga di tepi bawah
// ─────────────────────────────────────────────────────────────
class HeaderScenePainter extends CustomPainter {
  final Color warna;
  final Color gelap;
  final Color latar;
  final bool gelombang;

  const HeaderScenePainter({
    required this.warna,
    required this.gelap,
    required this.latar,
    this.gelombang = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect kotak = Offset.zero & size;

    // 1. Langit (gradasi vertikal — atas = warna utama agar menyatu AppBar)
    canvas.drawRect(
      kotak,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [warna, gelap],
        ).createShader(kotak),
    );

    // 2. Pola kawung halus
    KawungPainter(warna: Colors.white.withOpacity(0.07)).paint(canvas, size);

    // 3. Matahari terbit (emas, berlapis)
    final Offset matahari = Offset(size.width * 0.80, size.height * 0.34);
    canvas.drawCircle(
        matahari, 58, Paint()..color = AppTheme.emas.withOpacity(0.10));
    canvas.drawCircle(
        matahari, 40, Paint()..color = AppTheme.emas.withOpacity(0.20));
    canvas.drawCircle(
        matahari, 24, Paint()..color = AppTheme.emas.withOpacity(0.55));

    // 4. Bukit berlapis
    _bukit(canvas, size, 0.58, 0, Colors.white.withOpacity(0.06));
    _bukit(canvas, size, 0.70, 10, Colors.black.withOpacity(0.10));
    _bukit(canvas, size, 0.80, -6, Colors.black.withOpacity(0.12));

    // 5. Bulir padi di kanan bawah
    for (int i = 0; i < 4; i++) {
      _padi(
        canvas,
        Offset(size.width - 20 - i * 17.0, size.height - 14),
        tinggi: 54.0 + (i % 2) * 14.0 + i * 3.0,
        miring: -0.20 - i * 0.05,
      );
    }

    // 6. Gelombang telaga di tepi bawah (warna latar halaman)
    if (gelombang) {
      _ombak(canvas, size, 20, 9, 0.2, latar.withOpacity(0.45));
      _ombak(canvas, size, 13, 7, 1.4, latar);
    }
  }

  void _bukit(Canvas c, Size s, double tinggi, double fase, Color warna) {
    final double dasar = s.height * tinggi;
    final Path p = Path()
      ..moveTo(0, s.height)
      ..lineTo(0, dasar)
      ..cubicTo(s.width * 0.25, dasar - 30 + fase, s.width * 0.45, dasar + 14,
          s.width * 0.65, dasar - 16 + fase)
      ..cubicTo(s.width * 0.82, dasar - 34, s.width * 0.92, dasar - 6,
          s.width, dasar - 22)
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(p, Paint()..color = warna);
  }

  void _ombak(Canvas c, Size s, double naik, double amplitudo, double fase,
      Color warna) {
    final Path p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x += 4) {
      final double y = s.height -
          naik -
          amplitudo * math.sin(x / s.width * 2 * math.pi * 2 + fase);
      p.lineTo(x, y);
    }
    p.lineTo(s.width, s.height);
    p.close();
    c.drawPath(p, Paint()..color = warna);
  }

  void _padi(Canvas c, Offset dasar, {required double tinggi, required double miring}) {
    final Offset puncak = Offset(dasar.dx + tinggi * miring, dasar.dy - tinggi);
    final Offset kendali = Offset(dasar.dx + tinggi * miring * 0.2, dasar.dy - tinggi * 0.6);

    final Path batang = Path()
      ..moveTo(dasar.dx, dasar.dy)
      ..quadraticBezierTo(kendali.dx, kendali.dy, puncak.dx, puncak.dy);
    c.drawPath(
      batang,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    final Paint bulir = Paint()..color = AppTheme.emas.withOpacity(0.70);
    for (int k = 0; k < 7; k++) {
      final double t = 0.40 + k * 0.09;
      final double u = 1 - t;
      final double x = u * u * dasar.dx + 2 * u * t * kendali.dx + t * t * puncak.dx;
      final double y = u * u * dasar.dy + 2 * u * t * kendali.dy + t * t * puncak.dy;
      final int sisi = k.isEven ? 1 : -1;
      c.save();
      c.translate(x, y);
      c.rotate(sisi * 0.75);
      c.drawOval(
          Rect.fromCenter(center: Offset(sisi * 4.5, -1), width: 10, height: 4.2),
          bulir);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant HeaderScenePainter old) =>
      old.warna != warna ||
      old.gelap != gelap ||
      old.latar != latar ||
      old.gelombang != gelombang;
}

// ─────────────────────────────────────────────────────────────
// Header bermotif (dipakai Beranda & Login)
// ─────────────────────────────────────────────────────────────
class MotifHeader extends StatelessWidget {
  final String role;
  final Widget child;
  final EdgeInsets padding;
  final bool gelombang;

  const MotifHeader({
    super.key,
    required this.child,
    this.role = 'warga',
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 46),
    this.gelombang = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HeaderScenePainter(
                warna: AppTheme.primaryColor(role),
                gelap: AppTheme.primaryColorDark(role),
                latar: AppTheme.background,
                gelombang: gelombang,
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: SizedBox(width: double.infinity, child: child),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Logo Talagasari: telaga + matahari + bukit
// ─────────────────────────────────────────────────────────────
class LogoPainter extends CustomPainter {
  final Color warna;
  const LogoPainter({required this.warna});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;

    // cincin emas + dasar putih
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        r - 1.5,
        Paint()
          ..color = AppTheme.emas
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 4)));

    // langit
    final Rect kotak = Rect.fromCircle(center: c, radius: r);
    canvas.drawRect(
      kotak,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [warna.withOpacity(0.85), warna],
        ).createShader(kotak),
    );

    // matahari
    canvas.drawCircle(Offset(c.dx + r * 0.22, c.dy - r * 0.22), r * 0.26,
        Paint()..color = AppTheme.emas);

    // bukit
    final Path bukit = Path()
      ..moveTo(c.dx - r, c.dy + r * 0.12)
      ..quadraticBezierTo(c.dx - r * 0.45, c.dy - r * 0.32, c.dx + r * 0.05,
          c.dy + r * 0.10)
      ..quadraticBezierTo(c.dx + r * 0.50, c.dy - r * 0.12, c.dx + r,
          c.dy + r * 0.12)
      ..lineTo(c.dx + r, c.dy + r)
      ..lineTo(c.dx - r, c.dy + r)
      ..close();
    canvas.drawPath(bukit, Paint()..color = Colors.black.withOpacity(0.22));

    // gelombang telaga
    final Paint ombak = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.075
      ..strokeCap = StrokeCap.round;
    for (int j = 0; j < 3; j++) {
      final double y = c.dy + r * 0.30 + j * r * 0.20;
      final Path p = Path()..moveTo(c.dx - r * 0.62, y);
      for (double x = -r * 0.62; x <= r * 0.62; x += 2) {
        p.lineTo(c.dx + x,
            y + r * 0.055 * math.sin((x / (r * 0.62)) * math.pi * 2 + j));
      }
      canvas.drawPath(p, ombak);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LogoPainter old) => old.warna != warna;
}

class LogoTalagasari extends StatelessWidget {
  final double ukuran;
  final Color warna;

  const LogoTalagasari({
    super.key,
    this.ukuran = 40,
    this.warna = AppTheme.warnaWarga,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: CustomPaint(painter: LogoPainter(warna: warna)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pita batik (deretan belah ketupat emas & terakota)
// ─────────────────────────────────────────────────────────────
class PitaBatikPainter extends CustomPainter {
  const PitaBatikPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double lebar = 14;
    final double t = size.height;
    int i = 0;
    for (double x = 0; x < size.width; x += lebar) {
      final Path p = Path()
        ..moveTo(x + lebar / 2, 0.5)
        ..lineTo(x + lebar - 1, t / 2)
        ..lineTo(x + lebar / 2, t - 0.5)
        ..lineTo(x + 1, t / 2)
        ..close();
      canvas.drawPath(
        p,
        Paint()..color = i.isEven ? AppTheme.emas : AppTheme.terakota,
      );
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant PitaBatikPainter old) => false;
}

class PitaBatik extends StatelessWidget {
  final double tinggi;
  const PitaBatik({super.key, this.tinggi = 8});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: tinggi,
      child: const CustomPaint(painter: PitaBatikPainter()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Judul bagian bergaya Talagasari (belah ketupat emas + huruf serif)
// ─────────────────────────────────────────────────────────────
class JudulBagian extends StatelessWidget {
  final String judul;
  final String? subjudul;
  final Widget? trailing;
  final EdgeInsets padding;

  const JudulBagian(
    this.judul, {
    super.key,
    this.subjudul,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppTheme.emas,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontJudul,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subjudul != null)
                  Text(subjudul!,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dekorasi kartu khas: sudut besar, tepi krem, bayangan hangat
// ─────────────────────────────────────────────────────────────
BoxDecoration kartuTalagasari({double radius = 20, Color? warna}) {
  return BoxDecoration(
    color: warna ?? Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppTheme.kremTua, width: 1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF8A7A4A).withOpacity(0.10),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}


// ─────────────────────────────────────────────────────────────
// Ilustrasi "kosong": sawah, matahari, telaga (untuk EmptyState)
// ─────────────────────────────────────────────────────────────
class IlustrasiKosongPainter extends CustomPainter {
  final Color warna;
  const IlustrasiKosongPainter({required this.warna});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // lingkaran latar lembut
    canvas.drawCircle(Offset(w / 2, h * 0.52), h * 0.46,
        Paint()..color = AppTheme.emas.withOpacity(0.13));

    // matahari
    canvas.drawCircle(Offset(w * 0.64, h * 0.30), h * 0.13,
        Paint()..color = AppTheme.emas.withOpacity(0.85));

    // bukit
    final Path bukit = Path()
      ..moveTo(w * 0.08, h * 0.74)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.52, h * 0.66)
      ..quadraticBezierTo(w * 0.70, h * 0.44, w * 0.92, h * 0.74)
      ..close();
    canvas.drawPath(bukit, Paint()..color = warna.withOpacity(0.28));

    // petak sawah / telaga
    final Path telaga = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.08, h * 0.72, w * 0.84, h * 0.22),
          const Radius.circular(14)));
    canvas.drawPath(telaga, Paint()..color = warna.withOpacity(0.16));

    final Paint ombak = Paint()
      ..color = warna.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (int j = 0; j < 2; j++) {
      final double y = h * (0.80 + j * 0.08);
      final Path p = Path()..moveTo(w * 0.18, y);
      for (double x = w * 0.18; x <= w * 0.82; x += 3) {
        p.lineTo(x, y + 2.6 * math.sin((x / w) * math.pi * 7 + j));
      }
      canvas.drawPath(p, ombak);
    }

    // dua bulir padi
    for (int i = 0; i < 2; i++) {
      final double bx = w * (0.20 + i * 0.07);
      final double by = h * 0.74;
      final double tinggi = h * (0.34 + i * 0.08);
      final Path batang = Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx - 4, by - tinggi * 0.6, bx - 10, by - tinggi);
      canvas.drawPath(
          batang,
          Paint()
            ..color = warna.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
      for (int k = 0; k < 5; k++) {
        final double t = 0.45 + k * 0.12;
        final double x = bx - 10 * t * t - 4 * t * (1 - t);
        final double y = by - tinggi * t;
        final int sisi = k.isEven ? 1 : -1;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(sisi * 0.75);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(sisi * 4.5, -1), width: 9, height: 4),
            Paint()..color = AppTheme.emas);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant IlustrasiKosongPainter old) => old.warna != warna;
}

// ─────────────────────────────────────────────────────────────
// Angka yang menghitung naik (statistik)
// ─────────────────────────────────────────────────────────────
class AngkaHitung extends StatelessWidget {
  final int nilai;
  final TextStyle? gaya;
  const AngkaHitung(this.nilai, {super.key, this.gaya});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: nilai),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v', style: gaya),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cincin berdenyut (tombol SOS)
// ─────────────────────────────────────────────────────────────
class DenyutRing extends StatefulWidget {
  final Color warna;
  final double ukuran;
  const DenyutRing({super.key, required this.warna, this.ukuran = 180});

  @override
  State<DenyutRing> createState() => _DenyutRingState();
}

class _DenyutRingState extends State<DenyutRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final List<Widget> ring = [];
          for (final double fase in [0.0, 0.5]) {
            final double t = (_c.value + fase) % 1.0;
            final double u = widget.ukuran * (1 + 0.38 * t);
            ring.add(Container(
              width: u,
              height: u,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: widget.warna.withOpacity((1 - t) * 0.40), width: 3),
              ),
            ));
          }
          return Stack(alignment: Alignment.center, children: ring);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Splash: logo + telaga bergelombang
// ─────────────────────────────────────────────────────────────
class OmbakBergerakPainter extends CustomPainter {
  final double fase;
  final Color warna;
  const OmbakBergerakPainter({required this.fase, required this.warna});

  @override
  void paint(Canvas canvas, Size size) {
    void lapis(double naik, double amp, double geser, double kecepatan, Color c) {
      final Path p = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        p.lineTo(
            x,
            size.height -
                naik -
                amp * math.sin(x / size.width * 2 * math.pi * 1.6 + fase * kecepatan + geser));
      }
      p.lineTo(size.width, size.height);
      p.close();
      canvas.drawPath(p, Paint()..color = c);
    }

    lapis(70, 12, 0.0, 1.0, warna.withOpacity(0.35));
    lapis(48, 10, 1.7, -1.0, warna.withOpacity(0.65));
    lapis(26, 8, 3.1, 1.0, warna);
  }

  @override
  bool shouldRepaint(covariant OmbakBergerakPainter old) => old.fase != fase;
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _masuk;
  late final AnimationController _ombak;

  @override
  void initState() {
    super.initState();
    _masuk = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _ombak = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    Future.delayed(const Duration(milliseconds: 2400), () {
      // Jangan menimpa bila AuthController sudah mengarahkan ke /home atau /lock.
      if (mounted && Get.currentRoute == '/splash') Get.offNamed('/login');
    });
  }

  @override
  void dispose() {
    _masuk.dispose();
    _ombak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logo SAMA & di posisi SAMA dengan splash native Android (tanpa animasi
    // masuk), supaya terlihat satu splash saja. Yang bergerak hanya
    // pemandangan (matahari, bukit, padi), gelombang telaga, dan judul.
    final Animation<double> muncul = CurvedAnimation(
        parent: _masuk, curve: const Interval(0.15, 0.85, curve: Curves.easeOut));

    return Scaffold(
      backgroundColor: AppTheme.warnaWarga,
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: muncul,
              child: CustomPaint(
                painter: HeaderScenePainter(
                  warna: AppTheme.warnaWarga,
                  gelap: AppTheme.warnaWarga,
                  latar: AppTheme.background,
                  gelombang: false,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 130,
            child: FadeTransition(
              opacity: muncul,
              child: AnimatedBuilder(
                animation: _ombak,
                builder: (context, _) => CustomPaint(
                  painter: OmbakBergerakPainter(
                      fase: _ombak.value * 2 * math.pi,
                      warna: AppTheme.background),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const LogoTalagasari(ukuran: 150),
                  Positioned(
                    top: 150 + 20,
                    left: -100,
                    right: -100,
                    child: FadeTransition(
                      opacity: muncul,
                      child: Column(
                        children: [
                          const Text('Talagasari',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontJudul,
                                  fontSize: 38,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('H U B   D E S A',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.emas.withOpacity(0.95))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PitaBatik(tinggi: 8),
          ),
        ],
      ),
    );
  }

}
