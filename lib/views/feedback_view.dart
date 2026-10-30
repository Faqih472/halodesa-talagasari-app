// ============================================================
// feedback_view.dart — Kritik, Saran & Rating
//   BeriUmpanBalikView : warga menilai Aplikasi / Admin / Kades
//   UmpanBalikStafView : Admin & Kades membaca umpan balik yang menjadi haknya
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/feedback_controller.dart';
import '../core/core.dart';
import '../core/models_extra.dart';
import '../core/ui_helpers.dart';

// ─────────────────────────────────────────────────────────────
// WARGA: beri penilaian
// ─────────────────────────────────────────────────────────────
class BeriUmpanBalikView extends StatefulWidget {
  const BeriUmpanBalikView({super.key});

  @override
  State<BeriUmpanBalikView> createState() => _BeriUmpanBalikViewState();
}

class _BeriUmpanBalikViewState extends State<BeriUmpanBalikView> {
  final FeedbackController _ctrl = Get.find<FeedbackController>();
  final AuthController _auth = Get.find<AuthController>();
  final _komentarCtrl = TextEditingController();

  String _target = 'aplikasi';
  int _rating = 0;
  final Set<String> _aspek = {};
  bool _anonim = false;

  @override
  void dispose() {
    _komentarCtrl.dispose();
    super.dispose();
  }

  List<String> get _targetBoleh =>
      _auth.isStaff ? ['aplikasi'] : ['aplikasi', 'admin', 'kades'];

  Future<void> _kirim() async {
    final ok = await _ctrl.kirim(
      target: _target,
      rating: _rating,
      aspek: _aspek.toList(),
      komentar: _komentarCtrl.text,
      anonim: _anonim,
    );
    if (ok) Get.back();
    showSnack(ok, 'Terima kasih! Penilaian Anda sudah terkirim.',
        _ctrl.errorMsg.value);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final aspekList = FeedbackModel.daftarAspek[_target] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
          title: const Text('Nilai & Beri Saran'), backgroundColor: primary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Apa yang ingin Anda nilai?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _targetBoleh
                .map((t) => ChoiceChip(
                      avatar: Icon(FeedbackModel.ikonTarget(t), size: 16),
                      label: Text(FeedbackModel.labelTarget(t)),
                      selected: _target == t,
                      onSelected: (_) => setState(() {
                        _target = t;
                        _aspek.clear();
                      }),
                    ))
                .toList(),
          ),
          if (_target != 'aplikasi')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  _target == 'admin'
                      ? 'Penilaian tentang Admin dibaca oleh Kepala Desa.'
                      : 'Penilaian tentang Kepala Desa dibaca oleh Admin. Hanya warga terverifikasi yang dapat menilai pelayanan.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4)),
            ),
          const SizedBox(height: 18),
          Center(
            child: RatingStars(
              rating: _rating.toDouble(),
              size: 40,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ),
          Center(
            child: Text(
                _rating == 0
                    ? 'Ketuk bintang untuk menilai'
                    : const ['', 'Sangat buruk', 'Buruk', 'Cukup', 'Baik', 'Sangat baik'][_rating],
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 18),
          const Text('Apa masalahnya / yang disukai? (boleh pilih beberapa)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: aspekList
                .map((a) => FilterChip(
                      label: Text(a, style: const TextStyle(fontSize: 12)),
                      selected: _aspek.contains(a),
                      onSelected: (v) => setState(
                          () => v ? _aspek.add(a) : _aspek.remove(a)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _komentarCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: _rating > 0 && _rating <= 2
                  ? 'Jelaskan masalahnya (wajib)'
                  : 'Komentar / saran (opsional)',
              alignLabelWithHint: true,
            ),
          ),
          if (!_auth.isStaff)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonim,
              onChanged: (v) => setState(() => _anonim = v),
              activeColor: primary,
              title: const Text('Kirim sebagai anonim',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Nama Anda tidak ditampilkan kepada petugas yang membaca.',
                  style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 12),
          Obx(() => SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                  child: _ctrl.isSubmitting.value
                      ? loadingChild()
                      : const Text('Kirim Penilaian'),
                ),
              )),
          const SizedBox(height: 10),
          const Text(
              'Penilaian dibatasi 1x per sasaran per 14 hari dan dihapus otomatis setelah 180 hari.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STAF: baca umpan balik
// ─────────────────────────────────────────────────────────────
class UmpanBalikStafView extends StatefulWidget {
  const UmpanBalikStafView({super.key});

  @override
  State<UmpanBalikStafView> createState() => _UmpanBalikStafViewState();
}

class _UmpanBalikStafViewState extends State<UmpanBalikStafView> {
  final FeedbackController _ctrl = Get.find<FeedbackController>();
  String _filter = 'semua'; // semua | target | belum

  @override
  void initState() {
    super.initState();
    _ctrl.muat();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final Color primary = AppTheme.primaryColor(auth.role);
    final targets = _ctrl.targetDibaca;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
          title: const Text('Umpan Balik Warga'), backgroundColor: primary),
      body: Obx(() {
        final semua = _ctrl.masuk.toList();
        final list = semua.where((f) {
          if (_filter == 'semua') return true;
          if (_filter == 'belum') return f.status == 'baru';
          return f.target == _filter;
        }).toList();

        return RefreshIndicator(
          color: primary,
          onRefresh: _ctrl.muat,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Ringkasan per sasaran
              ...targets.map((t) {
                final data = semua.where((f) => f.target == t).toList();
                final double avg = data.isEmpty
                    ? 0
                    : data.fold<int>(0, (a, f) => a + f.rating) / data.length;
                final dist = List<int>.generate(
                    5, (i) => data.where((f) => f.rating == 5 - i).length);
                return kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(FeedbackModel.ikonTarget(t), color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(FeedbackModel.labelTarget(t),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Text(avg == 0 ? '-' : avg.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFA726)),
                      ]),
                      Text('${data.length} penilaian',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      for (int i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            SizedBox(
                                width: 14,
                                child: Text('${5 - i}',
                                    style: const TextStyle(fontSize: 11))),
                            const SizedBox(width: 6),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: data.isEmpty ? 0 : dist[i] / data.length,
                                minHeight: 6,
                                color: primary,
                                backgroundColor: primary.withOpacity(0.1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                                width: 22,
                                child: Text('${dist[i]}',
                                    style: const TextStyle(fontSize: 11))),
                          ]),
                        ),
                    ],
                  ),
                );
              }),
              // Filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  for (final o in <MapEntry<String, String>>[
                    const MapEntry('semua', 'Semua'),
                    const MapEntry('belum', 'Belum ditinjau'),
                    ...targets.map((t) =>
                        MapEntry(t, FeedbackModel.labelTarget(t))),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(o.value,
                            style: const TextStyle(fontSize: 12)),
                        selected: _filter == o.key,
                        onSelected: (_) => setState(() => _filter = o.key),
                      ),
                    ),
                ]),
              ),
              if (_ctrl.isLoading.value && semua.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Belum ada umpan balik.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ...list.map((f) => kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          RatingStars(rating: f.rating.toDouble(), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(FeedbackModel.labelTarget(f.target),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ),
                          StatusBadge(
                              text: f.status == 'baru' ? 'Baru' : 'Ditinjau',
                              color: f.status == 'baru'
                                  ? Colors.orange.shade800
                                  : Colors.green.shade700),
                        ]),
                        if (f.aspek.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: f.aspek
                                .map((a) => StatusBadge(
                                    text: a, color: AppTheme.textSecondary))
                                .toList(),
                          ),
                        ],
                        if (f.komentar.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(f.komentar,
                              style: const TextStyle(height: 1.4)),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: Text(
                                '${f.nama} • ${AppUtils.formatRelatif(f.createdAt)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ),
                          if (f.status == 'baru')
                            TextButton(
                              onPressed: () => _ctrl.tandaiDitinjau(f),
                              child: const Text('Tandai ditinjau'),
                            ),
                        ]),
                      ],
                    ),
                  )),
            ],
          ),
        );
      }),
    );
  }
}
