p='views/letter_view.dart'
s=open(p).read()

# 1) PDF: pakai kalimatUtama
a=s.index("  String isiUtama() {")
b=s.index("  doc.addPage(")
s=s[:a]+"  String isiUtama() => LetterModel.kalimatUtama(l.jenis);\n\n"+s[b:]

# 2) FAB + body beranda
fa=s.index("      floatingActionButton: staf")
fb=s.index("// ─────────────────────────────────────────────────────────────\n// Form pengajuan")
beranda = r'''      floatingActionButton: staf
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: () => _ajukan(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('letter_request'.tr,
                  style: const TextStyle(color: Colors.white)),
            ),
      body: Obx(() {
        final list = staf ? _ctrl.antrian : _ctrl.mine;
        if (_ctrl.isLoading.value && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _muat,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            children: [
              if (!staf) _PanduanBeranda(onPilih: _ajukan, warna: primary),
              if (!staf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Surat saya',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                ),
              if (list.isEmpty && staf) ...[
                const SizedBox(height: 80),
                EmptyState(
                    icon: Icons.description_outlined,
                    title: 'letter_empty'.tr,
                    subtitle: 'letter_empty_staff'.tr),
              ],
              if (list.isEmpty && !staf)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                      'Belum ada surat. Pilih jenis surat di atas lalu tekan "Ajukan Surat".',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.textSecondary)),
                ),
              ...list.map((l) => _kartuSurat(l, staf)),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _ajukan([String jenis = 'domisili']) async {
    if (!await wajibVerifikasi()) return;
    await Get.to(() => AjukanSuratView(jenisAwal: jenis));
    _muat();
  }

  Widget _kartuSurat(LetterModel l, bool staf) {
    final bool kad = l.kadaluarsa;
    final Color w =
        kad ? Colors.red.shade700 : LetterModel.warnaStatus(l.status);
    return InkWell(
      onTap: () async {
        await Get.to(() => LetterDetailView(letter: l));
        _muat();
      },
      child: kartu(
        child: Row(
          children: [
            Icon(LetterModel.panduan(l.jenis).ikon, color: w),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(LetterModel.labelJenis(l.jenis),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      '${staf ? '${l.nama} • ' : ''}${AppUtils.formatRelatif(l.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            StatusBadge(
                text: kad ? 'letter_expired'.tr : LetterModel.labelStatus(l.status),
                color: w),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Panduan di beranda surat: apa itu surat online, cara kerja,
// dan pilihan surat lengkap dengan kegunaannya.
// ─────────────────────────────────────────────────────────────
class _PanduanBeranda extends StatelessWidget {
  final void Function(String jenis) onPilih;
  final Color warna;
  const _PanduanBeranda({required this.onPilih, required this.warna});

  @override
  Widget build(BuildContext context) {
    const langkah = [
      'Pilih surat & isi keperluan',
      'Admin desa memeriksa data',
      'Kepala Desa menyetujui',
      'Cetak PDF, tanda tangan di kantor desa',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline, color: warna),
                const SizedBox(width: 8),
                const Text('Apa itu Surat Online?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Anda bisa mengajukan surat keterangan dari desa lewat HP, tanpa antre di kantor. '
                  'Surat dicetak sendiri lalu cukup ditandatangani Kepala Desa di kantor desa.',
                  style: TextStyle(fontSize: 13, height: 1.45)),
              const SizedBox(height: 12),
              for (int i = 0; i < langkah.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 11,
                        backgroundColor: warna,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(langkah[i],
                            style: const TextStyle(fontSize: 12.5))),
                  ]),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Pilih surat yang Anda butuhkan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        for (final j in LetterModel.daftarJenis)
          InkWell(
            onTap: () => onPilih(j['value']!),
            child: kartu(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: warna.withOpacity(0.12),
                    child: Icon(LetterModel.panduan(j['value']!).ikon, color: warna),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j['label']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(LetterModel.panduan(j['value']!).singkat,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text(
                            'Contoh: ${LetterModel.panduan(j['value']!).untuk.first}',
                            style: const TextStyle(fontSize: 12, height: 1.35)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

'''
s=s[:fa]+beranda+s[fb:]

# 3) AjukanSuratView baru
ga=s.index("// ─────────────────────────────────────────────────────────────\n// Form pengajuan")
gb=s.index("// ─────────────────────────────────────────────────────────────\n// Detail surat + aksi")
form = r'''// ─────────────────────────────────────────────────────────────
// Form pengajuan berpanduan: pilih surat → baca kegunaannya →
// isi keperluan (ada contoh) → cek data → lihat pratinjau → kirim.
// ─────────────────────────────────────────────────────────────
class AjukanSuratView extends StatefulWidget {
  final String jenisAwal;
  const AjukanSuratView({super.key, this.jenisAwal = 'domisili'});

  @override
  State<AjukanSuratView> createState() => _AjukanSuratViewState();
}

class _AjukanSuratViewState extends State<AjukanSuratView> {
  final LetterController _ctrl = Get.find<LetterController>();
  final AuthController _auth = Get.find<AuthController>();
  final _keperluanCtrl = TextEditingController();
  late String _jenis;

  @override
  void initState() {
    super.initState();
    _jenis = widget.jenisAwal;
    _keperluanCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _keperluanCtrl.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (_keperluanCtrl.text.trim().length < 10) {
      showSnack(false, '',
          'Keperluan terlalu singkat. Tulis tujuan dan tempat surat dipakai (minimal 10 huruf). Lihat contoh di atas kolom.');
      return;
    }
    final ok = await _ctrl.ajukan(
        jenis: _jenis, keperluan: _keperluanCtrl.text.trim());
    if (ok) Get.back();
    showSnack(ok, 'letter_sent'.tr, _ctrl.errorMsg.value);
  }

  void _isiContoh(String teks) {
    _keperluanCtrl.text = teks;
    _keperluanCtrl.selection = TextSelection.collapsed(offset: teks.length);
  }

  Future<void> _lihatContoh(PanduanSurat g) async {
    final pakai = await Get.dialog<bool>(AlertDialog(
      title: const Text('Contoh isian lengkap'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200)),
            child: Text(g.contohIsian, style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 10),
          Text('Tips: ${g.tips}',
              style: const TextStyle(fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 6),
          const Text('Ini hanya contoh. Ganti dengan keperluan Anda yang sebenarnya.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Tutup')),
        ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Pakai contoh ini')),
      ],
    ));
    if (pakai == true) _isiContoh(g.contohIsian);
  }

  Widget _judul(String no, String teks, Color warna) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Row(children: [
          CircleAvatar(
              radius: 12,
              backgroundColor: warna,
              child: Text(no,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(teks,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _butir(List<String> isi, IconData ikon, Color warna) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in isi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ikon, size: 16, color: warna),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(t,
                          style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_auth.role);
    final u = _auth.currentUser.value;
    final ktp = Get.find<ComplaintController>().myKtp.value;
    final PanduanSurat g = LetterModel.panduan(_jenis);
    final int masa = LetterModel.masaBulan(_jenis);
    final String keperluan = _keperluanCtrl.text.trim();
    final bool dataKurang = ktp.nik.isEmpty || (u?.alamatLengkap ?? '').isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('letter_request'.tr), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judul('1', 'Pilih surat yang Anda butuhkan', primary),
            for (final j in LetterModel.daftarJenis)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _jenis = j['value']!),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _jenis == j['value']
                          ? primary.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _jenis == j['value']
                              ? primary
                              : Colors.grey.shade300,
                          width: _jenis == j['value'] ? 1.8 : 1),
                    ),
                    child: Row(children: [
                      Icon(LetterModel.panduan(j['value']!).ikon,
                          color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(j['label']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(LetterModel.panduan(j['value']!).singkat,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (_jenis == j['value'])
                        Icon(Icons.check_circle, color: primary),
                    ]),
                  ),
                ),
              ),

            kartu(
              margin: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Surat ini cocok untuk:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _butir(g.untuk, Icons.check, primary),
                  const SizedBox(height: 12),
                  const Text('Yang perlu disiapkan:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _butir(g.siapkan, Icons.arrow_right, primary),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'Setelah ditandatangani, surat berlaku $masa bulan.',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary))),
                  ]),
                ],
              ),
            ),

            _judul('2', 'Tulis keperluan Anda', primary),
            const Text('Ketuk salah satu contoh untuk mengisi otomatis, lalu ubah sesuai kebutuhan:',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final c in g.contohKeperluan)
                  ActionChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _isiContoh(c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keperluanCtrl,
              maxLines: 3,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: 'letter_purpose'.tr,
                hintText: 'Contoh: ${g.contohIsian}',
                hintMaxLines: 3,
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _lihatContoh(g),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Lihat contoh isian lengkap'),
              ),
            ),

            _judul('3', 'Cek data Anda', primary),
            Text('letter_auto'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            kartu(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info('profile_name'.tr, u?.nama ?? '-'),
                  _info('NIK', ktp.nik.isEmpty ? '-' : ktp.nik),
                  _info('addr_full'.tr,
                      (u?.alamatLengkap ?? '').isEmpty ? '-' : u!.alamatLengkap),
                ],
              ),
            ),
            if (dataKurang)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Ada data yang masih kosong ("-"). Lengkapi lewat Akun → Verifikasi Identitas / Alamat agar surat tidak ditolak.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
              ),

            _judul('4', 'Begini bunyi surat Anda nanti', primary),
            kartu(
              child: Text(
                'Yang bertanda tangan di bawah ini, Kepala Desa Talagasari, menerangkan bahwa '
                '${u?.nama ?? '(nama Anda)'} ${LetterModel.kalimatUtama(_jenis)}\n\n'
                'Keperluan: ${keperluan.isEmpty ? '(belum diisi)' : keperluan}',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const Text('Surat ini baru sah setelah ditandatangani Kepala Desa di kantor desa.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),

            const SizedBox(height: 20),
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _ctrl.isSubmitting.value ? null : _kirim,
                    child: _ctrl.isSubmitting.value
                        ? loadingChild()
                        : Text('cmp_send'.tr),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}

'''
s=s[:ga]+form+s[gb:]
open(p,'w').write(s)
print('ok')
