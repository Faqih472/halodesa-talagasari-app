// ============================================================
// info_form_view.dart — Form Informasi Desa (satu form untuk 3 keadaan)
//   • Warga          : ajukan informasi  → menunggu Admin / Kades
//   • Admin / Kades  : buat informasi baru (di Beranda, tombol +)
//   • Admin / Kades  : ubah informasi yang sudah ada
// Aturan: masa berlaku WAJIB, foto opsional (1 foto, gratis).
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/data_controller.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/ui_helpers.dart';

Future<void> showFormInformasi({NewsModel? edit}) async {
  final auth = Get.find<AuthController>();
  final DataController dataCtrl = Get.find<DataController>();
  final String role = auth.role;
  final bool staf = auth.isStaff;
  final Color primary = AppTheme.primaryColor(role);
  final bool modeEdit = edit != null;

  final formKey = GlobalKey<FormState>();
  final judulCtrl = TextEditingController(text: edit?.judul ?? '');
  final isiCtrl = TextEditingController(text: edit?.isi ?? '');
  final bool awalKustom = (edit?.kategori ?? '').startsWith('custom:');
  String kategori = awalKustom ? 'lainnya' : (edit?.kategori ?? 'pengumuman');
  final kategoriKustomCtrl = TextEditingController(
      text: awalKustom ? edit!.kategori.substring(7) : '');
  String kategoriFinal() => kategori == 'lainnya'
      ? AppUtils.kategoriKustom(kategoriKustomCtrl.text)
      : kategori;
  DateTime? berlaku = edit?.berlakuSampai;
  bool simpanDraft = false;
  List<File> fotoBaru = [];
  List<String> fotoLama = edit != null && edit.fotoUrl.isNotEmpty ? [edit.fotoUrl] : [];

  await Get.bottomSheet(
    StatefulBuilder(
      builder: (ctx, setSheet) {
        final bool sensitif = AppUtils.isKategoriSensitif(kategori);
        final bool kirimKades = role == 'admin' && sensitif;

        String judulForm;
        String tombol;
        if (modeEdit) {
          judulForm = 'Ubah Informasi';
          tombol = 'Simpan Perubahan';
        } else if (!staf) {
          judulForm = 'Ajukan Informasi Desa';
          tombol = 'Kirim Pengajuan';
        } else {
          judulForm = 'Buat Informasi Baru';
          tombol = simpanDraft
              ? 'Simpan sebagai Draf'
              : (kirimKades ? 'Kirim ke Kades' : 'Publikasikan Sekarang');
        }

        return Container(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(judulForm,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                  const SizedBox(height: 4),
                  Text(
                    !staf
                        ? 'Informasi Anda akan diperiksa aparatur desa sebelum tayang.'
                        : (role == 'kades'
                            ? 'Sebagai Kepala Desa, informasi dapat langsung dipublikasikan.'
                            : 'Kategori biasa langsung tayang. Kategori sensitif dikirim ke Kepala Desa.'),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: kategori,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    isExpanded: true,
                    items: AppUtils.daftarKategoriInfo
                        .map((k) => DropdownMenuItem(
                            value: k['value'],
                            child: Text(
                                AppUtils.labelKategoriForm(
                                    k['value']!, k['label']!, staf),
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => kategori = v);
                    },
                  ),
                  if (kategori == 'lainnya') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: kategoriKustomCtrl,
                      maxLength: 30,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Tulis nama kategori minimal 3 huruf'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Nama kategori sendiri',
                        hintText: 'Contoh: Pemasangan Wifi',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
                  if (staf && sensitif && role != 'kades') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kategori ini memerlukan persetujuan Kepala Desa.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: judulCtrl,
                    validator: (v) =>
                        AppUtils.validateRequired(v, label: 'Judul'),
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      hintText: 'Contoh: Jadwal Kerja Bakti RT 03',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: isiCtrl,
                    maxLines: 5,
                    validator: (v) {
                      if (v == null || v.trim().length < 15) {
                        return 'Isi informasi minimal 15 huruf agar jelas.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Isi Informasi',
                      hintText: 'Tuliskan detail informasi di sini...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FotoPicker(
                    maks: 1,
                    label: 'Foto / gambar pendukung (opsional)',
                    bantuan:
                        'Gambar dikecilkan otomatis dan disimpan gratis. Dihapus bersama informasinya saat masa berlaku habis.',
                    fotoLama: fotoLama,
                    onChanged: (baru, lama) {
                      fotoBaru = baru;
                      fotoLama = lama;
                    },
                  ),
                  const SizedBox(height: 14),
                  ExpiryPicker(
                    key: ValueKey('exp_$kategori'),
                    initial: berlaku,
                    onChanged: (d) => berlaku = d,
                  ),
                  if (staf && !modeEdit && !kirimKades) ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      value: simpanDraft,
                      onChanged: (v) => setSheet(() => simpanDraft = v),
                      title: const Text('Simpan sebagai draf dulu',
                          style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                          'Draf bisa diedit dan dipublikasikan nanti dari tab Tertunda.',
                          style: TextStyle(fontSize: 12)),
                      activeColor: primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  if (modeEdit && role == 'admin' && sensitif && edit!.status == 'published')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Catatan: perubahan pada kategori sensitif oleh Admin perlu disetujui ulang Kepala Desa, sehingga informasi sementara tidak tampil di beranda.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.orange.shade800,
                            height: 1.4),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Obx(() => SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: dataCtrl.isSubmitting.value
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (berlaku == null) {
                                    showSnack(false, '', 'expiry_required'.tr);
                                    return;
                                  }
                                  final File? foto =
                                      fotoBaru.isNotEmpty ? fotoBaru.first : null;
                                  bool ok;
                                  String pesan = 'Berhasil disimpan.';
                                  if (modeEdit) {
                                    ok = await dataCtrl.editInformasi(
                                      edit!,
                                      judul: judulCtrl.text,
                                      isi: isiCtrl.text,
                                      kategori: kategoriFinal(),
                                      berlakuSampai: berlaku!,
                                      fotoLama: fotoLama,
                                      fotoBaru: foto,
                                    );
                                    if (ok && dataCtrl.perluAccUlang) {
                                      pesan =
                                          'Perubahan disimpan dan dikirim ke Kepala Desa untuk ACC ulang.';
                                    } else {
                                      pesan = 'Informasi berhasil diperbarui.';
                                    }
                                  } else if (!staf) {
                                    ok = await dataCtrl.submitInformasi(
                                      judul: judulCtrl.text,
                                      isi: isiCtrl.text,
                                      kategori: kategoriFinal(),
                                      berlakuSampai: berlaku,
                                      foto: foto,
                                    );
                                    pesan = sensitif
                                        ? 'Pengajuan dikirim ke Kepala Desa.'
                                        : 'Pengajuan dikirim ke Admin.';
                                  } else {
                                    ok = await dataCtrl.buatKontenStaff(
                                      judul: judulCtrl.text,
                                      isi: isiCtrl.text,
                                      kategori: kategoriFinal(),
                                      role: role,
                                      simpanDraft: simpanDraft,
                                      berlakuSampai: berlaku,
                                      foto: foto,
                                    );
                                    pesan = simpanDraft
                                        ? 'Disimpan sebagai draf (lihat tab Tertunda).'
                                        : (kirimKades
                                            ? 'Dikirim ke Kepala Desa.'
                                            : 'Informasi dipublikasikan.');
                                  }
                                  if (ok) Get.back();
                                  showSnack(ok, pesan, dataCtrl.errorMsg.value);
                                },
                          icon: dataCtrl.isSubmitting.value
                              ? loadingChild()
                              : const Icon(Icons.send, color: Colors.white),
                          label: Text(
                              dataCtrl.isSubmitting.value
                                  ? 'Menyimpan...'
                                  : tombol,
                              style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primary),
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

/// Dialog konfirmasi hapus informasi (Admin & Kades)
Future<void> konfirmasiHapusInformasi(NewsModel n) async {
  final dataCtrl = Get.find<DataController>();
  final ya = await Get.dialog<bool>(AlertDialog(
    title: const Text('Hapus informasi?'),
    content: Text(
        '"${n.judul}" akan dihapus permanen dan hilang dari beranda warga. Tindakan ini tidak bisa dibatalkan.'),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
        onPressed: () => Get.back(result: true),
        child: const Text('Hapus', style: TextStyle(color: Colors.white)),
      ),
    ],
  ));
  if (ya != true) return;
  final ok = await dataCtrl.hapusInformasi(n);
  showSnack(ok, 'Informasi dihapus.', dataCtrl.errorMsg.value);
}


/// Dialog "Perpanjang masa berlaku" (Admin & Kades).
/// Sisa masa berlaku ditambah bulan pilihan, total sisa maksimal 12 bulan.
Future<void> dialogPerpanjang(NewsModel n) async {
  final DataController dataCtrl = Get.find<DataController>();
  final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
  int bulan = 1;
  DateTime? kustom;

  await Get.dialog(StatefulBuilder(builder: (ctx, setD) {
    final DateTime hasil = kustom ?? hitungPerpanjang(n.berlakuSampai, bulan);
    final bool penuh = n.berlakuSampai != null &&
        !hasil.isAfter(n.berlakuSampai!);
    Widget chip(int b) {
      final aktif = kustom == null && bulan == b;
      return ChoiceChip(
        label: Text('+$b bulan',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: aktif ? Colors.white : Colors.black87)),
        selected: aktif,
        showCheckmark: false,
        selectedColor: primary,
        backgroundColor: Colors.grey.shade200,
        onSelected: (_) => setD(() {
          bulan = b;
          kustom = null;
        }),
      );
    }

    return AlertDialog(
      title: const Text('Perpanjang masa berlaku'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.judul,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
                n.berlakuSampai == null
                    ? 'Belum ada masa berlaku.'
                    : 'Sekarang: sampai ${AppUtils.formatTanggal(n.berlakuSampai!)} (${labelSisaWaktu(n.berlakuSampai!)}${n.kadaluarsa ? '' : ' lagi'})',
                style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final b in [1, 2, 3, 6, 9, 12]) chip(b),
              ChoiceChip(
                label: Text('Kustom...',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kustom != null ? Colors.white : Colors.black87)),
                selected: kustom != null,
                showCheckmark: false,
                selectedColor: primary,
                backgroundColor: Colors.grey.shade200,
                onSelected: (_) async {
                  final now = DateTime.now();
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: hasil.isBefore(now) ? now : hasil,
                    firstDate: now,
                    lastDate: batasMaksBerlaku(),
                  );
                  if (p != null) {
                    setD(() => kustom = DateTime(p.year, p.month, p.day, 23, 59));
                  }
                },
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (penuh ? Colors.red : primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                penuh
                    ? 'Sudah maksimal. Masa berlaku tidak bisa lebih dari 12 bulan dari hari ini.'
                    : 'Menjadi: sampai ${AppUtils.formatTanggal(hasil)} (${labelSisaWaktu(hasil)} lagi).\nSisa lama ditambah bulan baru, total maksimal 12 bulan.',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: penuh
              ? null
              : () async {
                  final ok = await dataCtrl.perpanjangInformasi(n,
                      bulan: bulan, sampai: kustom);
                  Get.back();
                  showSnack(ok, 'Masa berlaku diperpanjang.', dataCtrl.errorMsg.value);
                },
          child: const Text('Perpanjang', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }));
}
