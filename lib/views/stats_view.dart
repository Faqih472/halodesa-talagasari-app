// ============================================================
// stats_view.dart — Statistik Desa (Admin & Kades) + Ukuran Huruf
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/models_extra.dart';

// ============================================================
// STATISTIK — hanya Admin & Kades
// ============================================================
class StatistikView extends StatefulWidget {
  const StatistikView({super.key});

  @override
  State<StatistikView> createState() => _StatistikViewState();
}

class _StatistikViewState extends State<StatistikView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String _error = '';

  int _warga = 0, _wargaKtp = 0;
  int _jasaAktif = 0, _jasaPending = 0;
  final Map<String, int> _jasaPerKategori = {};
  int _pesananTotal = 0;
  final Map<String, int> _pesananPerStatus = {};
  int _infoTerbit = 0, _infoMenunggu = 0;
  int _cmpTotal = 0;
  final Map<String, int> _cmpPerStatus = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<int> _hitung(Query q) async {
    final snap = await q.count().get();
    return snap.count ?? 0;
  }

  /// Versi toleran: bila aturan Firestore menolak (mis. Kades tidak boleh
  /// membaca verifikasi KTP), tampilkan 0 tanpa menggagalkan seluruh halaman.
  Future<int> _hitungAman(Query q) async {
    try {
      return await _hitung(q);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final users = _db.collection('users');
      final jasa = _db.collection('penyedia_jasa');
      final info = _db.collection('announcements');
      final cmp = _db.collection('pengaduan');

      _warga = await _hitung(users.where('role', isEqualTo: 'warga'));
      _wargaKtp = await _hitungAman(
          _db.collection('verifikasi_ktp').where('status', isEqualTo: 'terverifikasi'));

      _jasaAktif = await _hitung(jasa.where('status', isEqualTo: 'aktif'));
      _jasaPending = await _hitung(jasa.where('status', isEqualTo: 'pending'));
      for (final k in AppUtils.daftarKategoriJasa) {
        _jasaPerKategori[k['label']!] = await _hitung(jasa
            .where('status', isEqualTo: 'aktif')
            .where('kategori', isEqualTo: k['value']));
      }

      _pesananTotal = 0;
      for (final st in [
        'menunggu',
        'nego',
        'diterima',
        'dikerjakan',
        'menunggu_konfirmasi',
        'selesai',
        'ditolak',
        'dibatalkan'
      ]) {
        final n = await _hitungAman(
            _db.collection('pesanan_jasa').where('status', isEqualTo: st));
        _pesananPerStatus[st] = n;
        _pesananTotal += n;
      }

      _infoTerbit = await _hitung(info.where('status', isEqualTo: 'published'));
      _infoMenunggu =
          await _hitung(info.where('status', isEqualTo: 'menunggu_review_admin'));

      _cmpTotal = await _hitung(cmp);
      for (final s in [
        'menunggu_review',
        'pending_kades',
        'diproses',
        'selesai',
        'ditolak'
      ]) {
        _cmpPerStatus[s] = await _hitung(cmp.where('status', isEqualTo: s));
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('stat_title'.tr),
        backgroundColor: primary,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error,
                        style: TextStyle(color: Colors.red.shade700)),
                  ),
                )
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _muat,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _grid([
                        _angka(Icons.people_outline, 'stat_residents'.tr,
                            _warga, primary),
                        _angka(Icons.verified_user_outlined, 'stat_ktp'.tr,
                            _wargaKtp, primary),
                        _angka(Icons.handyman_outlined, 'stat_service_active'.tr,
                            _jasaAktif, primary),
                        _angka(Icons.pending_outlined, 'stat_service_pending'.tr,
                            _jasaPending, primary),
                        _angka(Icons.campaign_outlined, 'stat_info_published'.tr,
                            _infoTerbit, primary),
                        _angka(Icons.hourglass_top_outlined,
                            'stat_info_waiting'.tr, _infoMenunggu, primary),
                      ]),
                      _judul('stat_service_by_cat'.tr),
                      _batang(_jasaPerKategori, primary),
                      _judul('Pesanan Jasa ($_pesananTotal)'),
                      _batang(
                        {
                          for (final e in _pesananPerStatus.entries)
                            OrderModel.labelStatus(e.key): e.value
                        },
                        primary,
                        warna: {
                          for (final e in _pesananPerStatus.entries)
                            OrderModel.labelStatus(e.key):
                                OrderModel.warnaStatus(e.key)
                        },
                      ),
                      _judul('${'stat_complaints'.tr} ($_cmpTotal)'),
                      _batang(
                        {
                          for (final e in _cmpPerStatus.entries)
                            ComplaintModel.labelStatus(e.key): e.value
                        },
                        primary,
                        warna: {
                          for (final e in _cmpPerStatus.entries)
                            ComplaintModel.labelStatus(e.key):
                                ComplaintModel.warnaStatus(e.key)
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _grid(List<Widget> items) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: items,
      );

  Widget _angka(IconData icon, String label, int n, Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$n',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _judul(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );

  Widget _batang(Map<String, int> data, Color primary,
      {Map<String, Color>? warna}) {
    final int maks =
        data.values.fold<int>(0, (a, b) => b > a ? b : a).clamp(1, 1 << 30);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: data.entries.map((e) {
          final Color c = warna?[e.key] ?? primary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / maks,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(c),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${e.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// UKURAN HURUF — Kecil / Normal / Besar
// ============================================================
class UkuranHurufView extends StatelessWidget {
  const UkuranHurufView({super.key});

  static String labelSkala(double v) {
    if (v < 1.0) return 'font_small'.tr;
    if (v > 1.0) return 'font_large'.tr;
    return 'font_normal'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);

    Widget opsi(double nilai, String label) => Obx(() {
          final bool aktif = AppSettings.fontScale.value == nilai;
          return Container(
            color: Colors.white,
            child: ListTile(
              onTap: () => AppSettings.setFontScale(nilai),
              leading: CircleAvatar(
                radius: 19,
                backgroundColor: primary.withOpacity(0.1),
                child: Icon(Icons.text_fields, color: primary, size: 20),
              ),
              title: Text(label,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
              trailing: aktif
                  ? Icon(Icons.check_circle, color: primary)
                  : const Icon(Icons.radio_button_unchecked,
                      color: AppTheme.textSecondary),
            ),
          );
        });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('font_title'.tr),
        backgroundColor: primary,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          opsi(0.9, 'font_small'.tr),
          const Divider(height: 1),
          opsi(1.0, 'font_normal'.tr),
          const Divider(height: 1),
          opsi(1.2, 'font_large'.tr),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('font_preview'.tr,
                style: const TextStyle(fontSize: 15, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
