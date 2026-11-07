// ============================================================
// info_jenis.dart — JENIS INFO WARGA + tampilan khusus di Beranda
//   Jenis: Info Biasa, Kehilangan, Ditemukan, Dijual, Dicari, Sumbangan,
//   Pinjam/Barter, Kabar Duka, Syukuran, Sebelum-Sesudah, Galeri, Polling Mini.
//   Tiap jenis punya contoh judul/isi, kolom tambahan, dan tampilan kartu sendiri.
//   Semua data di Firestore (gratis). Foto base64.
// ============================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';

class EkstraField {
  final String key;
  final String label;
  final String hint;
  final IconData ikon;
  final int baris;
  const EkstraField(this.key, this.label, this.hint, this.ikon, {this.baris = 1});
}

class JenisInfo {
  final String id;
  final String label;
  final IconData ikon;
  final Color warna;
  final String ringkas;
  final String kategori; // kategori Beranda yang dipakai
  final int hari; // lama tayang awal
  final String contohJudul;
  final String contohIsi;
  final List<EkstraField> ekstra;
  final String? fotoBantu;
  final int fotoMin;
  const JenisInfo(this.id, this.label, this.ikon, this.warna, this.ringkas, this.kategori, this.hari,
      this.contohJudul, this.contohIsi,
      {this.ekstra = const [], this.fotoBantu, this.fotoMin = 0});
}

const List<JenisInfo> jenisInfo = [
  JenisInfo('biasa', 'Info Biasa', Icons.article_outlined, Color(0xFF2E7D32),
      'Pengumuman atau kabar umum untuk warga.', 'pengumuman', 14,
      'Jadwal Kerja Bakti RT 03',
      'Kerja bakti membersihkan selokan hari Minggu pukul 07.00. Mohon warga membawa sapu dan cangkul.'),
  JenisInfo('kehilangan', 'Kehilangan', Icons.search, Color(0xFFE65100),
      'Barang atau hewan Anda hilang.', 'kehilangan', 7,
      'Kucing oren hilang di sekitar Blok C',
      'Kucing oren bernama Mimi, ekor pendek, memakai kalung biru. Terakhir terlihat Selasa sore. Mohon info jika melihatnya.',
      ekstra: [
        EkstraField('terakhir', 'Terakhir terlihat di', 'Contoh: Dekat warung Bu Ani, Blok C', Icons.place_outlined),
        EkstraField('kontak', 'Hubungi (WhatsApp)', 'Contoh: 0812xxxxxxx', Icons.phone_outlined),
      ],
      fotoBantu: 'Foto jelas barang atau hewan sangat membantu.'),
  JenisInfo('ditemukan', 'Ditemukan', Icons.volunteer_activism_outlined, Color(0xFF00897B),
      'Anda menemukan barang milik orang lain.', 'kehilangan', 7,
      'Ditemukan dompet cokelat di dekat masjid',
      'Ditemukan dompet cokelat berisi kartu identitas. Pemilik silakan menghubungi dan menyebutkan ciri isinya.',
      ekstra: [
        EkstraField('terakhir', 'Ditemukan di', 'Contoh: Depan Masjid Al-Ikhlas', Icons.place_outlined),
        EkstraField('kontak', 'Hubungi (WhatsApp)', 'Contoh: 0812xxxxxxx', Icons.phone_outlined),
      ]),
  JenisInfo('dijual', 'Dijual', Icons.sell_outlined, Color(0xFFAD1457),
      'Jual barang atau hasil kebun ke tetangga.', 'jual_beli', 14,
      'Dijual sepeda anak masih bagus',
      'Sepeda anak usia 6 sampai 9 tahun, kondisi baik, ban baru diganti. Bisa dilihat langsung di rumah.',
      ekstra: [
        EkstraField('harga', 'Harga', 'Contoh: Rp 350.000 (bisa nego)', Icons.payments_outlined),
        EkstraField('kontak', 'Hubungi (WhatsApp)', 'Contoh: 0812xxxxxxx', Icons.phone_outlined),
      ],
      fotoBantu: 'Tambahkan foto barang dari beberapa sisi.'),
  JenisInfo('sumbangan', 'Sumbangan & Bantuan', Icons.favorite_border, Color(0xFFD81B60),
      'Menggalang atau membagikan bantuan.', 'galang_bantuan', 14,
      'Galang bantuan untuk warga yang sakit',
      'Bapak Ahmad (RT 02) sedang dirawat. Mari bantu meringankan biaya sesuai kemampuan. Penyaluran dilaporkan di sini.',
      ekstra: [
        EkstraField('rekening', 'Cara menyalurkan', 'Contoh: Diserahkan ke Ketua RT 02, atau transfer ke rekening ...', Icons.account_balance_wallet_outlined, baris: 2),
        EkstraField('kontak', 'Penanggung jawab', 'Contoh: Pak RT 02 (0812xxxxxxx)', Icons.phone_outlined),
      ]),
  JenisInfo('duka', 'Kabar Duka', Icons.spa_outlined, Color(0xFF455A64),
      'Berita lelayu warga. Tampil khusus dan tenang di Beranda.', 'kabar_duka', 3,
      'Innalillahi wa inna ilaihi raji\'un',
      'Telah berpulang Bapak/Ibu ... warga RT 02/RW 05, pada hari ... Mohon dimaafkan segala kesalahannya dan doa terbaik untuk almarhum/almarhumah.',
      ekstra: [
        EkstraField('waktu', 'Waktu pemakaman', 'Contoh: Kamis, 13.00 WIB', Icons.schedule),
        EkstraField('tempat', 'Rumah duka / tempat pemakaman', 'Contoh: Blok B3 No. 7 / TPU Talagasari', Icons.place_outlined),
      ]),
  JenisInfo('syukuran', 'Syukuran & Undangan', Icons.celebration_outlined, Color(0xFFF9A825),
      'Kabar bahagia, hajatan, atau undangan acara.', 'kabar_bahagia', 7,
      'Undangan syukuran khitanan',
      'Dengan penuh syukur kami mengundang Bapak/Ibu/Saudara untuk hadir pada acara syukuran khitanan putra kami.',
      ekstra: [
        EkstraField('waktu', 'Hari dan jam', 'Contoh: Minggu, 10.00 WIB', Icons.schedule),
        EkstraField('tempat', 'Tempat', 'Contoh: Blok A3 No. 12', Icons.place_outlined),
      ]),
  JenisInfo('sebelum_sesudah', 'Sebelum & Sesudah', Icons.compare_outlined, Color(0xFF00838F),
      'Tunjukkan hasil kerja bakti atau perbaikan dengan geser foto.', 'kerja_bakti', 30,
      'Selokan RW 05 kini bersih dan lancar',
      'Berkat kerja bakti warga RW 05, selokan yang tersumbat sudah dibersihkan dan air kembali mengalir. Terima kasih semua!',
      fotoBantu: 'Pilih TEPAT 2 foto: yang pertama SEBELUM, yang kedua SESUDAH.',
      fotoMin: 2),
  JenisInfo('galeri', 'Galeri Kegiatan', Icons.photo_library_outlined, Color(0xFF7B1FA2),
      'Foto-foto acara seperti 17 Agustus atau pengajian.', 'kegiatan', 30,
      'Foto seru lomba 17 Agustus di RW 03',
      'Dokumentasi lomba balap karung, tarik tambang, dan makan kerupuk. Terima kasih kepada panitia dan semua warga yang hadir!',
      fotoBantu: 'Pilih 2 sampai 3 foto terbaik.',
      fotoMin: 2),
  JenisInfo('polling_mini', 'Tanya Cepat', Icons.poll_outlined, Color(0xFF3949AB),
      'Satu pertanyaan cepat, warga langsung memilih.', 'pengumuman', 7,
      'Kerja bakti enaknya hari apa?',
      'Mari tentukan hari kerja bakti bulan ini supaya sebanyak mungkin warga bisa ikut.',
      ekstra: [
        EkstraField('opsi', 'Pilihan jawaban (satu baris satu, 2 sampai 4)', 'Sabtu pagi\nMinggu pagi\nMinggu sore', Icons.list_alt, baris: 4),
      ]),
];

JenisInfo jenisDari(String id) => jenisInfo.firstWhere((j) => j.id == id, orElse: () => jenisInfo.first);

const Map<String, Color> temaWarna = {
  'hijau': Color(0xFF2E7D32),
  'biru': Color(0xFF1565C0),
  'kuning': Color(0xFFF9A825),
  'oranye': Color(0xFFEF6C00),
  'ungu': Color(0xFF6A1B9A),
  'merah': Color(0xFFC62828),
};

/// Warna aksen kartu: tema pilihan > warna jenis > null (pakai warna kategori)
Color? warnaAksen(NewsModel n) {
  if (n.tema.isNotEmpty && temaWarna.containsKey(n.tema)) return temaWarna[n.tema];
  if (n.jenis != 'biasa') return jenisDari(n.jenis).warna;
  return null;
}

// ─────────────────────────────────────────────────────────────
// PEMILIH JENIS (di formulir)
// ─────────────────────────────────────────────────────────────
class PilihJenisInfo extends StatelessWidget {
  final String terpilih;
  final void Function(JenisInfo) onPilih;
  const PilihJenisInfo({super.key, required this.terpilih, required this.onPilih});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.05,
        children: [
          for (final j in jenisInfo)
            InkWell(
              onTap: () => onPilih(j),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: terpilih == j.id ? j.warna : j.warna.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: terpilih == j.id ? j.warna : j.warna.withOpacity(0.25), width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(j.ikon, size: 26, color: terpilih == j.id ? Colors.white : j.warna),
                  const SizedBox(height: 5),
                  Text(j.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: terpilih == j.id ? Colors.white : j.warna)),
                ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: jenisDari(terpilih).warna.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Text(jenisDari(terpilih).ringkas,
            style: TextStyle(fontSize: 12.5, color: jenisDari(terpilih).warna, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class PilihTemaInfo extends StatelessWidget {
  final String tema;
  final ValueChanged<String> onPilih;
  const PilihTemaInfo({super.key, required this.tema, required this.onPilih});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 6, children: [
      InkWell(
        onTap: () => onPilih(''),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tema.isEmpty ? Colors.black87 : Colors.grey.shade400, width: tema.isEmpty ? 2.5 : 1)),
          child: const Icon(Icons.auto_awesome, size: 18, color: Colors.grey),
        ),
      ),
      for (final e in temaWarna.entries)
        InkWell(
          onTap: () => onPilih(e.key),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: e.value,
                shape: BoxShape.circle,
                border: Border.all(color: tema == e.key ? Colors.black87 : Colors.transparent, width: 2.5)),
            child: tema == e.key ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// LABEL JENIS + KOLOM TAMBAHAN (di kartu)
// ─────────────────────────────────────────────────────────────
class LabelJenisInfo extends StatelessWidget {
  final NewsModel n;
  const LabelJenisInfo({super.key, required this.n});

  @override
  Widget build(BuildContext context) {
    if (n.jenis == 'biasa') return const SizedBox.shrink();
    final j = jenisDari(n.jenis);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: j.warna, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(j.ikon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(j.label.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
      ]),
    );
  }
}

class EkstraInfo extends StatelessWidget {
  final NewsModel n;
  const EkstraInfo({super.key, required this.n});

  @override
  Widget build(BuildContext context) {
    final j = jenisDari(n.jenis);
    final rows = <Widget>[];
    for (final f in j.ekstra) {
      final v = n.ekstra[f.key];
      if (v is String && v.trim().isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(f.ikon, size: 15, color: j.warna),
            const SizedBox(width: 6),
            Expanded(
                child: Text.rich(TextSpan(children: [
              TextSpan(text: '${f.label.split('(').first.trim()}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: v),
            ]), style: const TextStyle(fontSize: 12.5, height: 1.35))),
          ]),
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(color: j.warna.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOTO KHUSUS: sebelum-sesudah (geser) dan galeri (mosaik)
// ─────────────────────────────────────────────────────────────
class SebelumSesudah extends StatefulWidget {
  final String sebelum;
  final String sesudah;
  final double radius;
  const SebelumSesudah({super.key, required this.sebelum, required this.sesudah, this.radius = 14});

  @override
  State<SebelumSesudah> createState() => _SebelumSesudahState();
}

class _SebelumSesudahState extends State<SebelumSesudah> {
  double _pos = 0.5;

  Widget _label(String t, Alignment a, Color c) => Align(
        alignment: a,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
          child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: 230,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => _pos = (_pos + d.delta.dx / w).clamp(0.02, 0.98)),
            onTapDown: (d) => setState(() => _pos = (d.localPosition.dx / w).clamp(0.02, 0.98)),
            child: Stack(children: [
              Positioned.fill(child: ImageUtil.image(widget.sesudah, fit: BoxFit.cover)),
              Positioned.fill(
                child: ClipRect(
                  clipper: _PotongKiri(_pos),
                  child: ImageUtil.image(widget.sebelum, fit: BoxFit.cover),
                ),
              ),
              _label('SEBELUM', Alignment.topLeft, Colors.red.shade700),
              _label('SESUDAH', Alignment.topRight, Colors.green.shade700),
              Positioned(
                left: w * _pos - 1.5,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: Colors.white),
              ),
              Positioned(
                left: w * _pos - 17,
                top: 230 / 2 - 17,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                  child: const Icon(Icons.compare_arrows, size: 20),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class _PotongKiri extends CustomClipper<Rect> {
  final double p;
  _PotongKiri(this.p);
  @override
  Rect getClip(Size s) => Rect.fromLTWH(0, 0, s.width * p, s.height);
  @override
  bool shouldReclip(_PotongKiri o) => o.p != p;
}

class GaleriMosaik extends StatelessWidget {
  final List<String> foto;
  final double radius;
  const GaleriMosaik({super.key, required this.foto, this.radius = 14});

  Widget _img(String f) => GestureDetector(
        onTap: () => tampilkanFoto(f),
        child: ImageUtil.image(f, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    if (foto.length < 2) return foto.isEmpty ? const SizedBox.shrink() : fotoFull(foto.first, radius: 14);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: 240,
        child: foto.length == 2
            ? Row(children: [
                Expanded(child: SizedBox.expand(child: _img(foto[0]))),
                const SizedBox(width: 3),
                Expanded(child: SizedBox.expand(child: _img(foto[1]))),
              ])
            : Row(children: [
                Expanded(flex: 3, child: SizedBox.expand(child: _img(foto[0]))),
                const SizedBox(width: 3),
                Expanded(
                    flex: 2,
                    child: Column(children: [
                      Expanded(child: SizedBox.expand(child: _img(foto[1]))),
                      const SizedBox(height: 3),
                      Expanded(child: SizedBox.expand(child: _img(foto[2]))),
                    ])),
              ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TANYA CEPAT (polling mini di dalam info)
// ─────────────────────────────────────────────────────────────
class PollingMini extends StatelessWidget {
  final NewsModel n;
  const PollingMini({super.key, required this.n});

  @override
  Widget build(BuildContext context) {
    final opsi = n.ekstra['opsi'] is List ? (n.ekstra['opsi'] as List).map((e) => '$e').toList() : <String>[];
    if (opsi.length < 2) return const SizedBox.shrink();
    final uid = Get.find<AuthController>().currentUser.value?.uid ?? '';
    final col = FirebaseFirestore.instance.collection('announcements').doc(n.id).collection('pilih');
    final warna = warnaAksen(n) ?? const Color(0xFF3949AB);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.limit(500).snapshots(),
      builder: (context, snap) {
        final hitung = List<int>.filled(opsi.length, 0);
        int milik = -1;
        for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final i = (d.data()['i'] as num?)?.toInt() ?? -1;
          if (i >= 0 && i < opsi.length) hitung[i]++;
          if (d.id == uid) milik = i;
        }
        final total = hitung.fold<int>(0, (a, b) => a + b);
        final sudah = milik >= 0;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: warna.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.poll_outlined, size: 16, color: warna),
              const SizedBox(width: 6),
              Text(sudah ? 'Terima kasih, suara Anda tercatat' : 'Ketuk satu pilihan untuk menjawab',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: warna)),
            ]),
            for (var i = 0; i < opsi.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: uid.isEmpty
                      ? null
                      : () async {
                          try {
                            await col.doc(uid).set({'i': i, 'at': Timestamp.now()});
                          } catch (_) {
                            showSnack(false, '', 'Gagal menyimpan suara. Coba lagi.');
                          }
                        },
                  child: Stack(children: [
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: milik == i ? warna : Colors.grey.shade300, width: milik == i ? 2 : 1)),
                    ),
                    if (sudah && total > 0)
                      FractionallySizedBox(
                        widthFactor: (hitung[i] / total).clamp(0.02, 1.0),
                        child: Container(
                            height: 38,
                            decoration: BoxDecoration(color: warna.withOpacity(0.22), borderRadius: BorderRadius.circular(10))),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Expanded(child: Text(opsi[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          if (sudah) Text('${(hitung[i] * 100 / (total == 0 ? 1 : total)).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('$total suara', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BANNER GESER DI BERANDA (info pilihan Admin)
// ─────────────────────────────────────────────────────────────
class BannerBeranda extends StatefulWidget {
  final List<NewsModel> daftar;
  final void Function(NewsModel) onTap;
  const BannerBeranda({super.key, required this.daftar, required this.onTap});

  @override
  State<BannerBeranda> createState() => _BannerBerandaState();
}

class _BannerBerandaState extends State<BannerBeranda> {
  final _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.daftar.length < 2 || !_pc.hasClients) return;
      _pc.animateToPage((_i + 1) % widget.daftar.length,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.daftar;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      const SizedBox(height: 10),
      SizedBox(
        height: 150,
        child: PageView.builder(
          controller: _pc,
          itemCount: list.length,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, k) {
            final n = list[k];
            final warna = warnaAksen(n) ?? const Color(0xFF2E7D32);
            final foto = n.semuaFoto.isNotEmpty ? n.semuaFoto.first : '';
            return GestureDetector(
              onTap: () => widget.onTap(n),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [warna, warna.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: warna.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(children: [
                    if (foto.isNotEmpty) Positioned.fill(child: ImageUtil.image(foto, fit: BoxFit.cover)),
                    if (foto.isNotEmpty)
                      Positioned.fill(
                          child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.75)])))),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(n.jenis == 'biasa' ? Icons.push_pin : jenisDari(n.jenis).ikon, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(n.jenis == 'biasa' ? 'SOROTAN DESA' : jenisDari(n.jenis).label.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Text(n.judul,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
                        const SizedBox(height: 2),
                        const Text('Ketuk untuk membaca', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (list.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < list.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _i == k ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                    color: _i == k ? const Color(0xFF2E7D32) : Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// KABAR DUKA: strip tenang di atas Beranda selama beberapa hari
// ─────────────────────────────────────────────────────────────
class StripDuka extends StatelessWidget {
  final List<NewsModel> daftar;
  final void Function(NewsModel) onTap;
  const StripDuka({super.key, required this.daftar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (daftar.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final n in daftar.take(2))
        GestureDetector(
          onTap: () => onTap(n),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF37474F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('🕊️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('KABAR DUKA', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(n.judul, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  if ('${n.ekstra['waktu'] ?? ''}'.isNotEmpty)
                    Text('Pemakaman: ${n.ekstra['waktu']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ]),
          ),
        ),
    ]);
  }
}
