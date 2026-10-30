// ============================================================
// account_view.dart — Tab "Akun" (Pengaturan Akun) + halaman turunannya
//
//   Pengaturan Akun
//   ├─ Akun Saya
//   │   ├─ Akun        → ProfilSayaView (klik foto profil juga ke sini)
//   │   └─ Alamat Saya → AlamatSayaView
//   ├─ Jasa Saya       → DasborJasaView (khusus warga; dasbor penyedia jasa)
//   ├─ Pengaturan
//   │   └─ Bahasa      → BahasaView (Indonesia / English)
//   └─ Bantuan
//       └─ Pusat Bantuan → PusatBantuanView (WA / telepon Admin & Kades)
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/auth_controller.dart';
import '../controllers/complaint_controller.dart';
import '../controllers/data_controller.dart';
import '../core/app_contact.dart';
import '../core/core.dart';
import 'chat_view.dart' show ChatAction;
import '../core/models.dart';
import 'jasa_view.dart';
import 'stats_view.dart';
import 'verification_view.dart' show KtpVerifikasiView, VerifiedBadge;
import 'profile_view.dart' show TabMyRequestView;
import 'admin_tools_view.dart' show AuditLogView;
import 'feedback_view.dart';

// ─────────────────────────────────────────────────────────────
// Helper bersama
// ─────────────────────────────────────────────────────────────
void _snack(bool ok, String okMsg, String errMsg, {String? okTitle}) {
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

Widget _sheetContainer(BuildContext ctx, {required Widget child}) {
  return Container(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: SingleChildScrollView(child: child),
  );
}

Widget _actionTile(IconData icon, String title, String subtitle, Color primary,
    {required VoidCallback onTap, Widget? trailing}) {
  return Container(
    color: Colors.white,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: primary.withOpacity(0.1),
        child: Icon(icon, color: primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
    ),
  );
}

Widget _infoTile(IconData icon, String label, String value, Color primary) {
  return Container(
    color: Colors.white,
    child: ListTile(
      dense: true,
      leading: Icon(icon, color: primary, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500)),
    ),
  );
}

Widget _avatar(String fotoUrl, String nama, Color primary, double radius) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.white,
    backgroundImage: fotoUrl.isNotEmpty ? ImageUtil.provider(fotoUrl) : null,
    child: fotoUrl.isEmpty
        ? Text(AppUtils.inisial(nama),
            style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
                color: primary))
        : null,
  );
}

Widget _loadingChild() => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));

// ============================================================
// TAB AKUN — Pengaturan Akun
// ============================================================
class TabSettingsView extends StatelessWidget {
  const TabSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = Get.find<AuthController>();
    final ComplaintController cmpCtrl = Get.find<ComplaintController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => cmpCtrl.fetchMyKtp());

    return Obx(() {
      final user = authCtrl.currentUser.value;
      final ktp = cmpCtrl.myKtp.value;
      final bool verified = cmpCtrl.ktpOk;
      final String role = user?.role ?? 'warga';
      final Color primary = AppTheme.primaryColor(role);
      final bool english = Get.locale?.languageCode == 'en';

      return Scaffold(
        appBar: AppBar(
          title: Text('acc_settings_title'.tr),
          backgroundColor: primary,
          actions: const [ChatAction()],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              FadeSlideIn(
                child: _header(user?.nama ?? '-', user?.email ?? '-',
                    user?.fotoUrl ?? '', role, primary,
                    verified: verified),
              ),

              // ── AKUN SAYA ──
              SectionTitle('sec_my_account'.tr),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  children: [
                    _actionTile(Icons.person_outline, 'acc_account'.tr,
                        'acc_account_sub'.tr, primary,
                        onTap: () => Get.to(() => const ProfilSayaView())),
                    _actionTile(Icons.home_outlined, 'acc_address'.tr,
                        'acc_address_sub'.tr, primary,
                        onTap: () => Get.to(() => const AlamatSayaView())),
                    if (role == 'warga')
                      _actionTile(
                          Icons.verified_user_outlined,
                          'verify_title'.tr,
                          verified
                              ? 'verified'.tr
                              : (ktp.status == 'menunggu'
                                  ? 'ktp_wait_title'.tr
                                  : 'verify_sub'.tr),
                          verified ? Colors.green.shade700 : primary,
                          onTap: () => Get.to(() => const KtpVerifikasiView())
                              ?.then((_) => cmpCtrl.fetchMyKtp())),
                    if (role == 'warga')
                      _actionTile(Icons.assignment_outlined, 'acc_my_info'.tr,
                          'acc_my_info_sub'.tr, primary,
                          onTap: () => Get.to(() => const TabMyRequestView())),
                  ],
                ),
              ),

              // ── JASA SAYA (khusus warga) ──
              if (role == 'warga') ...[
                SectionTitle('sec_my_service'.tr),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: _actionTile(Icons.handyman_outlined,
                      'acc_my_service'.tr, 'acc_my_service_sub'.tr, primary,
                      onTap: () => Get.to(() => const DasborJasaView())),
                ),
              ],

              // ── STATISTIK (Admin & Kades) ──
              if (role != 'warga') ...[
                SectionTitle('sec_admin'.tr),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: _actionTile(Icons.bar_chart_outlined,
                      'stat_title'.tr, 'stat_sub'.tr, primary,
                      onTap: () => Get.to(() => const StatistikView())),
                ),
                _actionTile(Icons.history, 'hub_audit'.tr, 'audit_sub'.tr, primary,
                    onTap: () => Get.to(() => const AuditLogView())),
                _actionTile(Icons.rate_review_outlined, 'Umpan Balik Warga',
                    'Penilaian aplikasi & pelayanan dari warga', primary,
                    onTap: () => Get.to(() => const UmpanBalikStafView())),
              ],

              // ── PENGATURAN ──
              SectionTitle('sec_settings'.tr),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: Column(
                  children: [
                    _actionTile(Icons.language, 'acc_language'.tr,
                        english ? 'English' : 'Bahasa Indonesia', primary,
                        onTap: () => Get.to(() => const BahasaView())),
                    _actionTile(
                        Icons.text_fields,
                        'acc_font'.tr,
                        UkuranHurufView.labelSkala(AppSettings.fontScale.value),
                        primary,
                        onTap: () => Get.to(() => const UkuranHurufView())),
                    _switchTile(authCtrl, primary),
                  ],
                ),
              ),

              // ── BANTUAN ──
              SectionTitle('sec_help'.tr),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Column(children: [
                  _actionTile(Icons.support_agent_outlined,
                      'acc_help_center'.tr, 'acc_help_center_sub'.tr, primary,
                      onTap: () => Get.to(() => const PusatBantuanView())),
                  _actionTile(Icons.star_rate_rounded, 'Nilai & Beri Saran',
                      role == 'warga'
                          ? 'Nilai aplikasi, Admin, atau Kepala Desa'
                          : 'Nilai aplikasi dan kirim saran pengembangan',
                      primary,
                      onTap: () => Get.to(() => const BeriUmpanBalikView())),
                ]),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _konfirmasiLogout(authCtrl),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: Text('acc_logout'.tr,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    });
  }

  /// Header: klik foto profil → halaman Profil Saya
  Widget _header(
      String nama, String email, String fotoUrl, String role, Color primary,
      {bool verified = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(gradient: AppTheme.gradient(role)),
      child: Column(
        children: [
          BouncyTap(
            onTap: () => Get.to(() => const ProfilSayaView()),
            child: Stack(
              children: [
                _avatar(fotoUrl, nama, primary, 46),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2), blurRadius: 6),
                      ],
                    ),
                    child: Icon(Icons.edit, size: 16, color: primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(nama,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(email,
              style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppTheme.iconRole(role), size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(AppTheme.labelRole(role),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (verified)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: VerifiedBadge(onDark: true),
            ),
        ],
      ),
    );
  }

  Widget _switchTile(AuthController authCtrl, Color primary) {
    return Obx(() => Container(
          color: Colors.white,
          child: SwitchListTile(
            value: authCtrl.rememberMeEnabled.value,
            onChanged: (v) => authCtrl.toggleRememberMe(v),
            activeColor: primary,
            secondary: CircleAvatar(
              radius: 19,
              backgroundColor: primary.withOpacity(0.1),
              child: Icon(Icons.bolt, color: primary, size: 20),
            ),
            title: Text('acc_quick_login'.tr,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
            subtitle: Text('acc_quick_login_sub'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ));
  }

  void _konfirmasiLogout(AuthController authCtrl) {
    final bool loginCepat = authCtrl.rememberMeEnabled.value;
    Get.dialog(
      AlertDialog(
        title: Text('logout_title'.tr),
        content: Text(loginCepat ? 'logout_quick'.tr : 'logout_normal'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Get.back();
              authCtrl.logout();
            },
            child: Text('acc_logout'.tr,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFIL SAYA — ubah nama, bio, jenis kelamin, tanggal lahir,
// no. handphone, email, foto profil, dan ganti password
// ============================================================
class ProfilSayaView extends StatefulWidget {
  const ProfilSayaView({super.key});

  @override
  State<ProfilSayaView> createState() => _ProfilSayaViewState();
}

class _ProfilSayaViewState extends State<ProfilSayaView> {
  final AuthController _authCtrl = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _namaCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _telpCtrl;
  String? _gender;
  DateTime? _tglLahir;
  String _panggilan = '';

  List<String> get _kataNama => UserModel.kataDariNama(_namaCtrl.text);

  void _selaraskanPanggilan() {
    final kata = _kataNama;
    if (kata.isEmpty) {
      _panggilan = '';
    } else if (!kata.contains(_panggilan)) {
      _panggilan = kata.first;
    }
  }

  @override
  void initState() {
    super.initState();
    final u = _authCtrl.currentUser.value;
    _namaCtrl = TextEditingController(text: u?.nama ?? '');
    _panggilan = u?.panggilan ?? '';
    _selaraskanPanggilan();
    _namaCtrl.addListener(() => setState(_selaraskanPanggilan));
    _bioCtrl = TextEditingController(text: u?.bio ?? '');
    _telpCtrl = TextEditingController(text: u?.nomorTelepon ?? '');
    _gender = (u?.jenisKelamin.isNotEmpty ?? false) ? u!.jenisKelamin : null;
    _tglLahir = u?.tanggalLahir;
    // Sinkronkan email bila baru saja diverifikasi lewat tautan
    _authCtrl.segarkanProfil();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _bioCtrl.dispose();
    _telpCtrl.dispose();
    super.dispose();
  }

  Future<void> _gantiFoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 320);
    if (picked == null) return;
    final u = _authCtrl.currentUser.value;
    if (u == null) return;

    Get.snackbar('profile_uploading_title'.tr, 'profile_uploading'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2));

    final ok = await _authCtrl.updateProfil(
      nama: u.nama,
      nomorTelepon: u.nomorTelepon,
      fotoFile: File(picked.path),
    );
    _snack(ok, 'profile_photo_saved'.tr, _authCtrl.errorMessage.value);
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tglLahir ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _tglLahir = picked);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _authCtrl.updateProfil(
      nama: _namaCtrl.text,
      namaPanggilan: _panggilan,
      nomorTelepon: _telpCtrl.text,
      bio: _bioCtrl.text,
      jenisKelamin: _gender,
      tanggalLahir: _tglLahir,
    );
    _snack(ok, 'profile_saved'.tr, _authCtrl.errorMessage.value);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final u = _authCtrl.currentUser.value;
      final String role = u?.role ?? 'warga';
      final Color primary = AppTheme.primaryColor(role);

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('profile_title'.tr),
          backgroundColor: primary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // ── Foto profil ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(gradient: AppTheme.gradient(role)),
                child: Column(
                  children: [
                    BouncyTap(
                      onTap: _gantiFoto,
                      child: Stack(
                        children: [
                          _avatar(u?.fotoUrl ?? '', u?.nama ?? '-', primary, 52),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6),
                                ],
                              ),
                              child: Icon(Icons.camera_alt,
                                  size: 18, color: primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _gantiFoto,
                      child: Text('profile_change_photo'.tr,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),

              // ── Form profil ──
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _namaCtrl,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            AppUtils.validateRequired(v, label: 'Nama'),
                        decoration: InputDecoration(
                            labelText: 'profile_name'.tr,
                            prefixIcon: const Icon(Icons.person_outlined)),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey('panggilan_${_namaCtrl.text}'),
                        value: _kataNama.contains(_panggilan) ? _panggilan : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Nama panggilan (wajib)',
                          helperText: 'Pilih salah satu kata dari nama asli Anda',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _kataNama
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Pilih nama panggilan' : null,
                        onChanged: (v) => setState(() => _panggilan = v ?? _panggilan),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: 'profile_bio'.tr,
                          hintText: 'profile_bio_hint'.tr,
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                            labelText: 'profile_gender'.tr,
                            prefixIcon: const Icon(Icons.wc_outlined)),
                        items: [
                          DropdownMenuItem(
                              value: 'laki-laki',
                              child: Text('profile_male'.tr)),
                          DropdownMenuItem(
                              value: 'perempuan',
                              child: Text('profile_female'.tr)),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pilihTanggal,
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'profile_birth'.tr,
                              prefixIcon:
                                  const Icon(Icons.cake_outlined)),
                          child: Text(
                            _tglLahir == null
                                ? 'profile_birth_hint'.tr
                                : AppUtils.formatTanggal(_tglLahir!),
                            style: TextStyle(
                                color: _tglLahir == null
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _telpCtrl,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            AppUtils.validateRequired(v, label: 'Nomor telepon'),
                        decoration: InputDecoration(
                            labelText: 'profile_phone'.tr,
                            prefixIcon: const Icon(Icons.phone_outlined)),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: ValueKey('email_${u?.email}'),
                        initialValue: u?.email ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'profile_email'.tr,
                          prefixIcon: const Icon(Icons.email_outlined),
                          suffixIcon: TextButton(
                            onPressed: () => _showUbahEmail(primary),
                            child: Text('profile_change'.tr),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Obx(() => SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _authCtrl.isLoading.value ? null : _simpan,
                              child: _authCtrl.isLoading.value
                                  ? _loadingChild()
                                  : Text('save_changes'.tr),
                            ),
                          )),
                    ],
                  ),
                ),
              ),

              // ── Keamanan ──
              SectionTitle('sec_security'.tr),
              _actionTile(Icons.lock_reset_outlined, 'change_password'.tr,
                  'change_password_sub'.tr, primary,
                  onTap: () => _showUbahPassword(primary)),

              const SizedBox(height: 8),
              _infoTile(AppTheme.iconRole(role), 'profile_role'.tr,
                  AppTheme.labelRole(role), primary),
              _infoTile(
                  Icons.calendar_today_outlined,
                  'profile_joined'.tr,
                  u?.createdAt != null ? AppUtils.formatTanggal(u!.createdAt) : '-',
                  primary),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────
  // Sheet: Ubah Email
  // ─────────────────────────────────────────────────────────
  void _showUbahEmail(Color primary) {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final pwCtrl = TextEditingController();
    bool pwVis = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheet) => _sheetContainer(
          ctx,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('email_change_title'.tr,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('email_hint'.tr,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppUtils.validateEmail,
                  decoration: InputDecoration(
                      labelText: 'email_new'.tr,
                      prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: pwCtrl,
                  obscureText: !pwVis,
                  validator: AppUtils.validatePassword,
                  decoration: InputDecoration(
                    labelText: 'email_current_password'.tr,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(pwVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => pwVis = !pwVis),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _authCtrl.isLoading.value
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final ok = await _authCtrl.ubahEmail(
                                  emailBaru: emailCtrl.text,
                                  passwordSaatIni: pwCtrl.text,
                                );
                                if (ok) Get.back();
                                _snack(ok, 'email_sent'.tr,
                                    _authCtrl.errorMessage.value,
                                    okTitle: 'email_sent_title'.tr);
                              },
                        child: _authCtrl.isLoading.value
                            ? _loadingChild()
                            : Text('email_send_btn'.tr),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Sheet: Ganti Password (langsung aktif, tanpa email verifikasi)
  // ─────────────────────────────────────────────────────────
  void _showUbahPassword(Color primary) {
    final formKey = GlobalKey<FormState>();
    final lamaCtrl = TextEditingController();
    final baruCtrl = TextEditingController();
    final konfCtrl = TextEditingController();
    bool lamaVis = false, baruVis = false, konfVis = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheet) => _sheetContainer(
          ctx,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('change_password'.tr,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('password_hint'.tr,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lamaCtrl,
                  obscureText: !lamaVis,
                  validator: AppUtils.validatePassword,
                  decoration: InputDecoration(
                    labelText: 'password_old'.tr,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(lamaVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => lamaVis = !lamaVis),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: baruCtrl,
                  obscureText: !baruVis,
                  onChanged: (_) => setSheet(() {}),
                  validator: (v) => AppUtils.validatePasswordBaru(v),
                  decoration: InputDecoration(
                    labelText: 'password_new'.tr,
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(baruVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => baruVis = !baruVis),
                    ),
                  ),
                ),
                if (baruCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _kekuatanBar(baruCtrl.text),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: konfCtrl,
                  obscureText: !konfVis,
                  validator: (v) => AppUtils.validatePasswordBaru(v,
                      bandingkan: baruCtrl.text),
                  decoration: InputDecoration(
                    labelText: 'password_confirm'.tr,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(konfVis
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setSheet(() => konfVis = !konfVis),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _authCtrl.isLoading.value
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final ok = await _authCtrl.ubahPasswordLangsung(
                                  passwordLama: lamaCtrl.text,
                                  passwordBaru: baruCtrl.text,
                                );
                                if (ok) Get.back();
                                _snack(ok, 'password_done'.tr,
                                    _authCtrl.errorMessage.value,
                                    okTitle: 'password_done_title'.tr);
                              },
                        child: _authCtrl.isLoading.value
                            ? _loadingChild()
                            : Text('password_btn'.tr),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _kekuatanBar(String value) {
    final skor = AppUtils.kekuatanPassword(value);
    final Color warna =
        skor < 0.4 ? Colors.red : (skor < 0.75 ? Colors.orange : Colors.green);
    final String label = skor < 0.4 ? 'Lemah' : (skor < 0.75 ? 'Cukup' : 'Kuat');
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: skor),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(warna),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: warna, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================
// ALAMAT SAYA — data alamat tempat tinggal
// ============================================================
class AlamatSayaView extends StatefulWidget {
  const AlamatSayaView({super.key});

  @override
  State<AlamatSayaView> createState() => _AlamatSayaViewState();
}

class _AlamatSayaViewState extends State<AlamatSayaView> {
  final AuthController _authCtrl = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _alamatCtrl;
  late final TextEditingController _rtCtrl;
  late final TextEditingController _rwCtrl;
  late final TextEditingController _dusunCtrl;
  late final TextEditingController _patokanCtrl;

  @override
  void initState() {
    super.initState();
    final u = _authCtrl.currentUser.value;
    _alamatCtrl = TextEditingController(text: u?.alamatLengkap ?? '');
    _rtCtrl = TextEditingController(text: u?.alamatRt ?? '');
    _rwCtrl = TextEditingController(text: u?.alamatRw ?? '');
    _dusunCtrl = TextEditingController(text: u?.alamatDusun ?? '');
    _patokanCtrl = TextEditingController(text: u?.alamatPatokan ?? '');
  }

  @override
  void dispose() {
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    _dusunCtrl.dispose();
    _patokanCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _authCtrl.updateAlamat(
      alamatLengkap: _alamatCtrl.text,
      rt: _rtCtrl.text,
      rw: _rwCtrl.text,
      dusun: _dusunCtrl.text,
      patokan: _patokanCtrl.text,
    );
    _snack(ok, 'address_saved'.tr, _authCtrl.errorMessage.value);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(_authCtrl.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('address_title'.tr),
        backgroundColor: primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _alamatCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      AppUtils.validateRequired(v, label: 'Alamat'),
                  decoration: InputDecoration(
                    labelText: 'address_full'.tr,
                    hintText: 'address_full_hint'.tr,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rtCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            AppUtils.validateRequired(v, label: 'RT'),
                        decoration:
                            InputDecoration(labelText: 'address_rt'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rwCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            AppUtils.validateRequired(v, label: 'RW'),
                        decoration:
                            InputDecoration(labelText: 'address_rw'.tr),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dusunCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                      labelText: 'address_dusun'.tr,
                      prefixIcon: const Icon(Icons.holiday_village_outlined)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _patokanCtrl,
                  decoration: InputDecoration(
                      labelText: 'address_landmark'.tr,
                      hintText: 'address_landmark_hint'.tr,
                      prefixIcon: const Icon(Icons.flag_outlined)),
                ),
                const SizedBox(height: 14),
                _readOnlyField('address_village'.tr, 'Talagasari'),
                const SizedBox(height: 14),
                _readOnlyField('address_district'.tr, 'Cikupa'),
                const SizedBox(height: 14),
                _readOnlyField('address_regency'.tr, 'Tangerang'),
                const SizedBox(height: 20),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _authCtrl.isLoading.value ? null : _simpan,
                        child: _authCtrl.isLoading.value
                            ? _loadingChild()
                            : Text('save'.tr),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.location_on_outlined)),
    );
  }
}

// ============================================================
// BAHASA — Indonesia / English
// ============================================================
class BahasaView extends StatefulWidget {
  const BahasaView({super.key});

  @override
  State<BahasaView> createState() => _BahasaViewState();
}

class _BahasaViewState extends State<BahasaView> {
  Future<void> _pilih(String kode) async {
    await LocalStore.setBahasa(kode);
    Get.updateLocale(
        kode == 'en' ? const Locale('en', 'US') : const Locale('id', 'ID'));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);
    final String aktif = LocalStore.bahasa;

    Widget opsi(String kode, String label) => Container(
          color: Colors.white,
          child: ListTile(
            onTap: () => _pilih(kode),
            leading: CircleAvatar(
              radius: 19,
              backgroundColor: primary.withOpacity(0.1),
              child: Icon(Icons.language, color: primary, size: 20),
            ),
            title: Text(label,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
            trailing: aktif == kode
                ? Icon(Icons.check_circle, color: primary)
                : const Icon(Icons.radio_button_unchecked,
                    color: AppTheme.textSecondary),
          ),
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('language_title'.tr),
        backgroundColor: primary,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          opsi('id', 'language_id'.tr),
          const Divider(height: 1),
          opsi('en', 'language_en'.tr),
        ],
      ),
    );
  }
}

// ============================================================
// PUSAT BANTUAN — kontak Admin & Kepala Desa (WhatsApp / telepon)
// Nomor diatur di core/app_contact.dart
// ============================================================
class PusatBantuanView extends StatelessWidget {
  const PusatBantuanView({super.key});

  Future<void> _buka(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack(false, '', 'help_failed'.tr);
    } catch (_) {
      _snack(false, '', 'help_failed'.tr);
    }
  }

  Uri _wa(String nomor) => Uri.parse(
      'https://wa.me/$nomor?text=${Uri.encodeComponent('help_wa_greeting'.tr)}');

  Uri _telp(String nomor) => Uri(scheme: 'tel', path: '+$nomor');

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor(Get.find<AuthController>().role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('help_title'.tr),
        backgroundColor: primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('help_intro'.tr,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          _kartuKontak(Icons.admin_panel_settings_outlined, 'help_admin'.tr,
              AppContact.adminNama, AppContact.adminTelp, primary),
          const SizedBox(height: 12),
          _kartuKontak(Icons.account_balance_outlined, 'help_kades'.tr,
              AppContact.kadesNama, AppContact.kadesTelp, primary),
        ],
      ),
    );
  }

  Widget _kartuKontak(
      IconData icon, String peran, String nama, String nomor, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withOpacity(0.1),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peran,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(nama,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    Text('+$nomor',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _buka(_wa(nomor)),
                  icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                  label: Text('help_wa'.tr,
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _buka(_telp(nomor)),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text('help_call'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
