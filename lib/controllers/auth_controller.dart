// ============================================================
// auth_controller.dart — AuthController + MainController
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../core/models.dart';
import 'chat_controller.dart';

// ============================================================
// auth_controller.dart — REWRITE
// Logic: Login, Register, Logout, Role Detection,
//        Login Cepat (remember-me + lock screen ala Facebook),
//        Ubah Password langsung (tanpa email), Update Profil +
//        Foto, Update Lokasi Otomatis, Registrasi Token FCM.
// ============================================================

class AuthController extends GetxController {
  // ─── Firebase Instances ──────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Reactive State ──────────────────────────────────────
  final Rx<User?> _firebaseUser = Rx<User?>(null);
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// Preferensi "Login Cepat" (dicerminkan dari LocalStore agar UI reaktif)
  final RxBool rememberMeEnabled = false.obs;

  /// Menampung pilihan checkbox "Ingat saya" dari form login/registrasi
  /// sebelum profil selesai dimuat dari Firestore.
  bool? _pendingRememberMe;
  String? _pendingPassword;
  /// Data profil dari form registrasi (dipakai jika dokumen users/{uid} perlu
  /// dibuat ulang otomatis).
  Map<String, String>? _pendingProfil;

  // ─── Getters ─────────────────────────────────────────────
  bool get isLoggedIn => _firebaseUser.value != null;
  /// True jika sesi Firebase masih hidup (dipakai bubble di form login)
  bool get hasLiveSession => _auth.currentUser != null;
  String get role => currentUser.value?.role ?? 'warga';
  bool get isStaff => role == 'admin' || role == 'kades';

  // ─────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    rememberMeEnabled.value = LocalStore.rememberMe;
    // Pantau perubahan status autentikasi Firebase
    _firebaseUser.bindStream(_auth.authStateChanges());
    ever(_firebaseUser, _handleAuthChange);
  }

  /// Dipanggil setiap kali status auth Firebase berubah.
  void _handleAuthChange(User? user) {
    if (user == null) {
      // Sesi berakhir. Snapshot Login Cepat SENGAJA tidak dihapus supaya
      // bubble akun tetap tampil di form login (hanya dihapus lewat
      // "Gunakan akun lain" / mematikan Login Cepat).
      currentUser.value = null;
      LocalStore.clearSavedProfile(); // hanya akun aktif; daftar akun tetap
      rememberMeEnabled.value = false;
      Get.offAllNamed('/login');
      return;
    }

    if (LocalStore.appLocked) {
      // Sesi Firebase masih hidup tapi aplikasi sedang "dikunci" →
      // tampilkan layar Login Cepat, jangan langsung ke Home.
      Get.offAllNamed('/lock');
      return;
    }

    _loadUserData(user.uid);
  }

  /// Load data pengguna dari Firestore berdasarkan UID
  Future<void> _loadUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        // Akun Auth ada tapi profil Firestore belum terbentuk (mis. proses
        // registrasi terputus di tengah). Buat otomatis, jangan logout —
        // logout di sini membuat login selalu gagal untuk akun tsb.
        await _buatProfilJikaBelum(uid);
        doc = await _firestore.collection('users').doc(uid).get();
      }

      if (doc.exists) {
        currentUser.value = UserModel.fromFirestore(doc);

        // Simpan/hapus snapshot Login Cepat sesuai pilihan pengguna saat
        // login/registrasi (hanya dieksekusi tepat setelah aksi tsb).
        if (_pendingRememberMe == true) {
          await LocalStore.saveProfileSnapshot(
            uid: uid,
            nama: currentUser.value!.nama,
            email: currentUser.value!.email,
            foto: currentUser.value!.fotoUrl,
            role: currentUser.value!.role,
            password: _pendingPassword,
          );
          rememberMeEnabled.value = true;
        } else if (_pendingRememberMe == false) {
          await LocalStore.removeAccount(uid);
          await LocalStore.clearSavedProfile();
          rememberMeEnabled.value = false;
        } else if (LocalStore.savedUid != null && LocalStore.savedUid != uid) {
          // Penanda akun aktif basi (beda akun) → reset agar layar kunci
          // tidak menampilkan avatar akun yang salah.
          await LocalStore.clearSavedProfile();
          rememberMeEnabled.value = false;
        }
        _pendingRememberMe = null;
        _pendingPassword = null;
        _pendingProfil = null;

        await LocalStore.setAppLocked(false);
        _navigateByRole(currentUser.value!.role);
      } else {
        // Dokumen user tidak ada di Firestore → kemungkinan bug, logout
        await logout();
      }
    } catch (e) {
      errorMessage.value = 'Gagal memuat data pengguna: $e';
      Get.snackbar('Gagal', errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Buat dokumen users/{uid} dari akun Firebase Auth yang sedang aktif jika
  /// belum ada. Memakai data form registrasi bila tersedia; jika tidak
  /// (akun lama yang terlanjur tanpa profil), nama diambil dari email dan
  /// bisa diubah nanti di Pengaturan → Edit Profil.
  Future<void> _buatProfilJikaBelum(String uid) async {
    final u = _auth.currentUser;
    if (u == null || u.uid != uid) return;

    final ref = _firestore.collection('users').doc(uid);
    if ((await ref.get()).exists) return;

    final String email = (u.email ?? '').trim();
    final String nama = _pendingProfil?['nama'] ??
        (email.contains('@') ? email.split('@').first : 'Warga');
    final String telepon = _pendingProfil?['telepon'] ?? '';

    final UserModel baru = UserModel(
      uid: uid,
      nama: nama,
      email: email,
      role: 'warga',
      nomorTelepon: telepon,
      createdAt: DateTime.now(),
    );
    await ref.set(baru.toMap());
  }

  /// Navigasi ke halaman utama berdasarkan role
  void _navigateByRole(String role) {
    Get.offAllNamed('/home');
  }

  // ─────────────────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────────────────
  Future<bool> register({
    required String nama,
    required String email,
    required String password,
    required String nomorTelepon,
    bool rememberMe = true,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      // Set SEBELUM createUser: authStateChanges bisa menyala lebih dulu
      // daripada Future selesai, sehingga snapshot Login Cepat terlewat.
      _pendingRememberMe = rememberMe;
      _pendingPassword = password;
      _pendingProfil = {
        'nama': nama.trim(),
        'telepon': nomorTelepon.trim(),
      };

      // Bug decode plugin (lihat catatan di login()): akun BISA sudah
      // terbentuk di server tetapi createUser melempar exception biasa.
      // Dulu kasus ini langsung dianggap "berhasil" TANPA menulis profil ke
      // Firestore → akun Auth ada, dokumen users/{uid} tidak ada, dan login
      // berikutnya selalu gagal. Sekarang sesi diambil dari currentUser lalu
      // profil tetap ditulis.
      User? akunBaru;
      try {
        final UserCredential credential =
            await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        akunBaru = credential.user;
      } on FirebaseAuthException {
        rethrow;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
        akunBaru = _auth.currentUser;
        if (akunBaru == null ||
            akunBaru.email?.toLowerCase() != email.trim().toLowerCase()) {
          rethrow;
        }
      }

      final String? uidBaru = (akunBaru ?? _auth.currentUser)?.uid;
      if (uidBaru == null) {
        throw Exception('Sesi akun baru tidak terbentuk');
      }
      final String uid = uidBaru;

      final UserModel newUser = UserModel(
        uid: uid,
        nama: nama.trim(),
        email: email.trim(),
        role: 'warga', // Default: semua user baru adalah warga
        nomorTelepon: nomorTelepon.trim(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      _pendingRememberMe = rememberMe;
      // _handleAuthChange akan otomatis terpicu → load data → navigate
      return true;
    } on FirebaseAuthException catch (e) {
      // Sebagian versi plugin Firebase kadang melempar exception meski
      // akun sebenarnya sudah terbentuk di server. Cek ulang sebelum
      // memvonis gagal.
      if (_auth.currentUser != null) {
        _pendingRememberMe = rememberMe;
        return true;
      }
      _pendingRememberMe = null;
      _pendingPassword = null;
      _pendingProfil = null;
      errorMessage.value = _parseAuthError(e.code);
      return false;
    } catch (e) {
      if (_auth.currentUser != null) {
        // Akun sudah ada; profil akan dibuat otomatis oleh _loadUserData
        _pendingRememberMe = rememberMe;
        return true;
      }
      _pendingRememberMe = null;
      _pendingPassword = null;
      _pendingProfil = null;
      errorMessage.value = 'Terjadi kesalahan. Silakan coba lagi.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────
  //
  // CATATAN PERBAIKAN BUG "Terjadi kesalahan, coba lagi" padahal
  // login sebenarnya BERHASIL:
  //
  // Beberapa versi plugin firebase_auth di Flutter punya bug yang
  // cukup terkenal — proses sign-in di sisi server SUDAH berhasil
  // (sesi tercipta, authStateChanges() akan menyala), tapi saat hasil
  // dikembalikan ke Dart lewat method channel, terjadi error decoding
  // internal (mis. type-cast) yang terlempar sebagai exception biasa.
  // Kode lama langsung menganggap ini "gagal" padahal user sudah login.
  //
  // Perbaikannya: begitu ada exception di luar kode error resmi
  // Firebase yang memang valid, kita cek ulang `_auth.currentUser`.
  // Jika ternyata sesi SUDAH aktif dengan email yang sama, kita
  // anggap berhasil dan diamkan error tsb — user tidak akan melihat
  // pesan gagal palsu lagi.
  // ─────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final String emailBersih = email.trim().toLowerCase();
    try {
      isLoading.value = true;
      errorMessage.value = '';
      // Set SEBELUM signIn (lihat catatan di register): pada plugin yang
      // melempar exception palsu, sesi sudah aktif dan profil sudah
      // termuat sebelum baris di bawah sempat dijalankan.
      _pendingRememberMe = rememberMe;
      _pendingPassword = password;

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _pendingRememberMe = rememberMe;
      return true;
    } on FirebaseAuthException catch (e) {
      if (_sesiSudahAktifUntuk(emailBersih)) {
        _pendingRememberMe = rememberMe;
        return true;
      }
      _pendingRememberMe = null;
      _pendingPassword = null;
      errorMessage.value = _parseAuthError(e.code);
      return false;
    } catch (_) {
      // Beri sedikit jeda: authStateChanges() kadang butuh sepersekian
      // detik untuk mem-propagasi sesi yang baru saja tercipta.
      await Future.delayed(const Duration(milliseconds: 500));
      if (_sesiSudahAktifUntuk(emailBersih)) {
        _pendingRememberMe = rememberMe;
        return true;
      }
      _pendingRememberMe = null;
      _pendingPassword = null;
      errorMessage.value =
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  bool _sesiSudahAktifUntuk(String emailBersih) {
    final user = _auth.currentUser;
    return user != null && (user.email?.toLowerCase() == emailBersih);
  }

  // ─────────────────────────────────────────────────────────
  // LOGOUT — "Login Cepat" ala Facebook
  //
  // Jika pengguna mengaktifkan Login Cepat, logout TIDAK memutus sesi
  // Firebase. Aplikasi hanya dikunci (soft-lock) dan menampilkan layar
  // dengan avatar bergelombang: cukup diketuk untuk masuk lagi tanpa
  // password. Jika Login Cepat tidak aktif, logout dilakukan penuh
  // seperti biasa.
  // ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      try {
        Get.find<MainController>().resetToHome();
      } catch (_) {}

      if (LocalStore.hasSavedProfile) {
        await LocalStore.setAppLocked(true);
        currentUser.value = null;
        Get.offAllNamed('/lock');
      } else {
        await _auth.signOut();
        currentUser.value = null;
        await LocalStore.clearSavedProfile();
        // _handleAuthChange akan otomatis mengarahkan ke /login
      }
    } catch (e) {
      errorMessage.value = 'Gagal keluar. Silakan coba lagi.';
    }
  }

  /// Dipanggil dari layar kunci: "Bukan {nama}? Gunakan akun lain"
  /// Memutus sesi Firebase sepenuhnya, berbeda dari logout() biasa.
  /// Akun yang ditinggalkan TETAP tersimpan di daftar akun perangkat ini
  /// (bubble di form login); hanya sesi & penanda akun aktif yang direset.
  Future<void> switchAccount() async {
    try {
      await LocalStore.clearSavedProfile();
      rememberMeEnabled.value = false;
      currentUser.value = null;
      await _auth.signOut();
      // _handleAuthChange akan mengarahkan ke /login
    } catch (e) {
      errorMessage.value = 'Gagal beralih akun. Silakan coba lagi.';
    }
  }

  /// Dipanggil dari layar kunci saat avatar bergelombang diketuk.
  /// Tidak perlu password sama sekali karena sesi Firebase masih hidup.
  Future<bool> quickUnlock() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Sesi hilang: kembali ke form login (bubble tetap ada, email terisi)
      Get.offAllNamed('/login');
      return false;
    }
    await LocalStore.setAppLocked(false);
    await _loadUserData(user.uid);
    return true;
  }

  /// Masuk dari bubble akun tersimpan di form login.
  /// - Sesi Firebase akun itu masih hidup  → langsung buka (tanpa password).
  /// - Sesi sudah berakhir / akun lain      → login memakai password
  ///   tersimpan (terenkripsi). Jika password belum tersimpan atau sudah
  ///   berubah, kembalikan false + pesan agar pengguna memasukkannya sekali.
  Future<bool> loginAkunTersimpan(String uid) async {
    final akun = LocalStore.savedAccounts.firstWhere(
      (a) => a['uid'] == uid,
      orElse: () => <String, dynamic>{},
    );
    final String email = (akun['email'] ?? '').toString();
    if (email.isEmpty) {
      errorMessage.value = 'Data akun tersimpan tidak ditemukan.';
      return false;
    }

    final user = _auth.currentUser;
    if (user != null && user.uid == uid) {
      // Pulihkan penanda akun aktif lalu buka sesi yang masih hidup
      await LocalStore.saveProfileSnapshot(
        uid: uid,
        nama: (akun['nama'] ?? '').toString(),
        email: email,
        foto: (akun['foto'] ?? '').toString(),
        role: (akun['role'] ?? 'warga').toString(),
      );
      rememberMeEnabled.value = true;
      return quickUnlock();
    }

    final String? pw = await LocalStore.savedPassword(uid);
    if (pw == null || pw.isEmpty) {
      errorMessage.value =
          'Password akun ini belum tersimpan. Masukkan password sekali lagi.';
      return false;
    }
    final bool ok = await login(email: email, password: pw, rememberMe: true);
    if (!ok && errorMessage.value.isEmpty) {
      errorMessage.value = 'Gagal masuk. Masukkan password Anda.';
    }
    return ok;
  }

  /// Toggle switch "Login Cepat" di halaman Pengaturan
  Future<void> toggleRememberMe(bool value) async {
    if (value) {
      final u = currentUser.value;
      if (u != null) {
        await LocalStore.saveProfileSnapshot(
          uid: u.uid,
          nama: u.nama,
          email: u.email,
          foto: u.fotoUrl,
          role: u.role,
        );
      }
    } else {
      // Matikan Login Cepat = hapus AKUN INI dari daftar akun tersimpan
      final u = currentUser.value;
      if (u != null) {
        await LocalStore.removeAccount(u.uid);
      }
      await LocalStore.clearSavedProfile();
    }
    rememberMeEnabled.value = value;
  }

  // ─────────────────────────────────────────────────────────
  // RESET PASSWORD via EMAIL (jalur cadangan jika lupa total)
  // ─────────────────────────────────────────────────────────
  Future<bool> resetPassword({required String email}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _parseAuthError(e.code);
      return false;
    } catch (e) {
      errorMessage.value = 'Terjadi kesalahan. Silakan coba lagi.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // UBAH PASSWORD LANGSUNG — realtime, tanpa buka email sama sekali
  // Cukup verifikasi password lama, lalu password baru aktif seketika.
  // ─────────────────────────────────────────────────────────
  Future<bool> ubahPasswordLangsung({
    required String passwordLama,
    required String passwordBaru,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      errorMessage.value = 'Sesi tidak valid. Silakan login ulang.';
      return false;
    }
    final String email = user.email!;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Langkah 1 — verifikasi password lama.
      // Bug decode plugin (lihat catatan di login()): reauthenticate bisa
      // SUDAH berhasil di server tetapi terlempar sebagai exception biasa.
      // Password salah selalu datang sebagai FirebaseAuthException, jadi
      // exception jenis lain aman diabaikan.
      try {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: passwordLama),
        );
      } on FirebaseAuthException {
        rethrow;
      } catch (_) {}

      // Langkah 2 — ganti password.
      await user.updatePassword(passwordBaru);

      await _sinkronPasswordTersimpan(user.uid, passwordBaru);
      return true;
    } catch (e) {
      // Hasil TIDAK PASTI: plugin bisa melempar exception (mis. type-cast)
      // padahal password sudah berubah di server. Jangan percaya exception-
      // nya — cek langsung ke server apakah password BARU sudah berlaku.
      if (await _passwordBaruSudahAktif(user, email, passwordBaru)) {
        await _sinkronPasswordTersimpan(user.uid, passwordBaru);
        return true;
      }

      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          errorMessage.value = 'Password lama yang Anda masukkan salah.';
        } else {
          errorMessage.value = _parseAuthError(e.code);
        }
      } else {
        // Sertakan detail teknis agar penyebab bisa dilacak
        errorMessage.value = 'Gagal mengubah password. ($e)';
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// True jika [passwordBaru] sudah dikenali server sebagai password akun.
  /// Ditolak server (FirebaseAuthException) = belum berubah; lolos ATAU
  /// terlempar exception non-Firebase (bug decode plugin) = sudah berubah.
  Future<bool> _passwordBaruSudahAktif(
      User user, String email, String passwordBaru) async {
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: passwordBaru),
      );
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Sinkronkan password tersimpan (Login Cepat). Tidak boleh melempar.
  Future<void> _sinkronPasswordTersimpan(String uid, String password) async {
    try {
      if (LocalStore.savedAccounts.any((a) => a['uid'] == uid)) {
        await LocalStore.savePassword(uid, password);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE PROFIL (nama, telepon, foto profil ke Firebase Storage)
  // ─────────────────────────────────────────────────────────
  Future<bool> updateProfil({
    required String nama,
    required String nomorTelepon,
    String? namaPanggilan,
    File? fotoFile,
    String? bio,
    String? jenisKelamin,
    DateTime? tanggalLahir,
  }) async {
    try {
      isLoading.value = true;
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      // Nama panggilan WAJIB salah satu kata dari nama asli.
      final List<String> kata = UserModel.kataDariNama(nama);
      String pilih = (namaPanggilan ?? currentUser.value?.panggilan ?? '').trim();
      if (!kata.any((k) => k.toLowerCase() == pilih.toLowerCase())) {
        pilih = kata.isEmpty ? '' : kata.first;
      } else {
        pilih = kata.firstWhere((k) => k.toLowerCase() == pilih.toLowerCase());
      }

      final Map<String, dynamic> updates = {
        'nama': nama.trim(),
        'nama_panggilan': pilih,
        'nomor_telepon': nomorTelepon.trim(),
        if (bio != null) 'bio': bio.trim(),
        if (jenisKelamin != null) 'jenis_kelamin': jenisKelamin,
        if (tanggalLahir != null)
          'tanggal_lahir': Timestamp.fromDate(tanggalLahir),
      };

      // Foto profil tidak ditulis di sini: harus lewat persetujuan Admin (FotoProfilController).

      await _firestore.collection('users').doc(uid).update(updates);
      await _loadUserDataTanpaNavigasi(uid);
      await _perbaruiSnapshotLoginCepat(uid);
      return true;
    } catch (e) {
      errorMessage.value = 'Gagal memperbarui profil: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE ALAMAT TEMPAT TINGGAL
  // ─────────────────────────────────────────────────────────
  Future<bool> updateAlamat({
    required String alamatLengkap,
    required String rt,
    required String rw,
    String dusun = '',
    String patokan = '',
  }) async {
    try {
      isLoading.value = true;
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      await _firestore.collection('users').doc(uid).update({
        'alamat_lengkap': alamatLengkap.trim(),
        'alamat_rt': rt.trim(),
        'alamat_rw': rw.trim(),
        'alamat_dusun': dusun.trim(),
        'alamat_patokan': patokan.trim(),
      });
      await _loadUserDataTanpaNavigasi(uid);
      return true;
    } catch (e) {
      errorMessage.value = 'Gagal menyimpan alamat: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // UBAH EMAIL — verifikasi password, lalu Firebase mengirim tautan
  // konfirmasi ke email BARU. Email baru aktif setelah tautan diklik.
  // ─────────────────────────────────────────────────────────
  Future<bool> ubahEmail({
    required String emailBaru,
    required String passwordSaatIni,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      errorMessage.value = 'Sesi tidak valid. Silakan login ulang.';
      return false;
    }
    try {
      isLoading.value = true;
      errorMessage.value = '';
      try {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
              email: user.email!, password: passwordSaatIni),
        );
      } on FirebaseAuthException {
        rethrow;
      } catch (_) {}
      await user.verifyBeforeUpdateEmail(emailBaru.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage.value = 'Password yang Anda masukkan salah.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage.value = 'Email tersebut sudah dipakai akun lain.';
      } else {
        errorMessage.value = _parseAuthError(e.code);
      }
      return false;
    } catch (e) {
      errorMessage.value = 'Gagal mengubah email. ($e)';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Muat ulang profil + sinkronkan email Firestore bila email di Firebase
  /// Auth sudah berganti (setelah tautan verifikasi email baru diklik).
  Future<void> segarkanProfil() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      try {
        await user.reload();
      } catch (_) {}
      final String? emailAuth = _auth.currentUser?.email;
      if (emailAuth != null &&
          currentUser.value != null &&
          emailAuth != currentUser.value!.email) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'email': emailAuth});
      }
      await _loadUserDataTanpaNavigasi(user.uid);
      await _perbaruiSnapshotLoginCepat(user.uid);
    } catch (_) {}
  }

  /// Perbarui snapshot Login Cepat bila sedang aktif
  Future<void> _perbaruiSnapshotLoginCepat(String uid) async {
    if (LocalStore.rememberMe && currentUser.value != null) {
      await LocalStore.saveProfileSnapshot(
        uid: uid,
        nama: currentUser.value!.nama,
        email: currentUser.value!.email,
        foto: currentUser.value!.fotoUrl,
        role: currentUser.value!.role,
      );
    }
  }

  /// Reload dokumen user dari Firestore tanpa memicu navigasi/side effect
  /// (dipakai setelah update profil/lokasi, bukan setelah login).
  Future<void> _loadUserDataTanpaNavigasi(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        currentUser.value = UserModel.fromFirestore(doc);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE LOKASI (manual — dipertahankan agar kompatibel)
  // ─────────────────────────────────────────────────────────
  Future<void> updateLokasi(double lat, double lng) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('users').doc(uid).update({
        'lokasi_lat': lat,
        'lokasi_lng': lng,
      });

      if (currentUser.value != null) {
        currentUser.value = currentUser.value!.copyWith(
          lokasiLat: lat,
          lokasiLng: lng,
        );
      }
    } catch (_) {
      // Latar belakang saja, tidak perlu mengganggu pengguna dengan error.
    }
  }

  /// Elisitasi #29 — perbarui koordinat GPS otomatis setiap aplikasi dibuka.
  Future<void> updateLokasiOtomatis() async {
    try {
      final bool servisAktif = await Geolocator.isLocationServiceEnabled();
      if (!servisAktif) return;

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) return;
      }
      if (izin == LocationPermission.deniedForever) return;

      final posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await updateLokasi(posisi.latitude, posisi.longitude);
    } catch (_) {
      // Lokasi adalah fitur pendukung — kegagalan di sini tidak boleh
      // memblokir penggunaan aplikasi.
    }
  }

  // ─────────────────────────────────────────────────────────
  // HELPER: Parse Firebase Auth Error ke pesan Indonesia
  // ─────────────────────────────────────────────────────────
  String _parseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Gunakan email lain atau login.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-not-found':
        return 'Email tidak terdaftar di sistem.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
      case 'user-disabled':
        return 'Akun Anda telah dinonaktifkan.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'requires-recent-login':
        return 'Sesi Anda kedaluwarsa. Silakan login ulang lalu coba lagi.';
      default:
        return 'Terjadi kesalahan ($code). Silakan coba lagi.';
    }
  }
}


// ============================================================
// main_controller.dart
// Logic: Dynamic Navbar berdasarkan Role Pengguna
// Warga  → 5 tab (Beranda, Jasa, Pengaduan, Notifikasi, Akun)
// Admin  → 5 tab (Beranda, Kelola, Tertunda, Notifikasi, Akun)
// Kades  → 5 tab (Beranda, Kelola, Tertunda, Notifikasi, Akun)
// ============================================================

class MainController extends GetxController {
  // ─── Reactive State ──────────────────────────────────────
  final RxInt currentIndex = 0.obs;

  // ─── Dependency ──────────────────────────────────────────
  final AuthController _authController = Get.find<AuthController>();

  // ─── Getters ─────────────────────────────────────────────
  String get role => _authController.role;
  bool get isStaff => _authController.isStaff;

  // Indeks tab untuk warga
  static const int idxBerandaWarga = 0;
  static const int idxJasa = 1;
  static const int idxMyRequest = 2; // tab Pengaduan
  static const int idxNotifWarga = 3;
  static const int idxSettingsWarga = 4;

  // Indeks tab untuk staff (admin/kades)
  static const int idxBerandaStaff = 0;
  static const int idxManage = 1;
  static const int idxPending = 2;
  static const int idxNotifStaff = 3;
  static const int idxSettingsStaff = 4;

  int get idxNotif => isStaff ? idxNotifStaff : idxNotifWarga;

  // ─────────────────────────────────────────────────────────
  // Ganti tab aktif
  // ─────────────────────────────────────────────────────────
  void changeTab(int index) {
    currentIndex.value = index;
  }

  // ─────────────────────────────────────────────────────────
  // Reset ke tab pertama (Beranda)
  // ─────────────────────────────────────────────────────────
  void resetToHome() {
    currentIndex.value = 0;
  }

  // ─────────────────────────────────────────────────────────
  // KONFIGURASI NAVBAR WARGA (5 tab)
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get navItemsWarga => [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: 'nav_home'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.handyman_outlined),
          activeIcon: const Icon(Icons.handyman),
          label: 'nav_service'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          activeIcon: const Icon(Icons.report_gmailerrorred),
          label: 'nav_complaint'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.notifications_outlined),
          activeIcon: const Icon(Icons.notifications),
          label: 'nav_notif'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: 'nav_account'.tr,
        ),
      ];

  // ─────────────────────────────────────────────────────────
  // KONFIGURASI NAVBAR ADMIN & KADES (5 tab)
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get navItemsStaff => [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: 'nav_home'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.inbox_outlined),
          activeIcon: const Icon(Icons.inbox),
          label: 'nav_manage'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.pending_actions_outlined),
          activeIcon: const Icon(Icons.pending_actions),
          label: 'nav_pending'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.notifications_outlined),
          activeIcon: const Icon(Icons.notifications),
          label: 'nav_notif'.tr,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: 'nav_account'.tr,
        ),
      ];

  // ─────────────────────────────────────────────────────────
  // Pilih list navbar sesuai role
  // ─────────────────────────────────────────────────────────
  List<BottomNavigationBarItem> get currentNavItems =>
      isStaff ? navItemsStaff : navItemsWarga;

  // ─────────────────────────────────────────────────────────
  // Jumlah tab berdasarkan role
  // ─────────────────────────────────────────────────────────
  int get tabCount => 5;

  // ─────────────────────────────────────────────────────────
  // Label tab aktif (untuk AppBar title)
  // ─────────────────────────────────────────────────────────
  String get currentTabTitle {
    if (isStaff) {
      switch (currentIndex.value) {
        case idxBerandaStaff:
          return 'Talagasari Hub';
        case idxManage:
          return 'Kelola Pengajuan';
        case idxPending:
          return 'Draft & Tertunda';
        case idxNotifStaff:
          return 'notif_title'.tr;
        case idxSettingsStaff:
          return 'acc_settings_title'.tr;
        default:
          return 'Talagasari Hub';
      }
    } else {
      switch (currentIndex.value) {
        case idxBerandaWarga:
          return 'Talagasari Hub';
        case idxJasa:
          return 'Cari Jasa Lokal';
        case idxMyRequest:
          return 'cmp_title_tab'.tr;
        case idxNotifWarga:
          return 'notif_title'.tr;
        case idxSettingsWarga:
          return 'acc_settings_title'.tr;
        default:
          return 'Talagasari Hub';
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // Navigasi ke tab tertentu dari luar (misal dari notifikasi)
  // ─────────────────────────────────────────────────────────
  void goToManage() {
    if (isStaff) changeTab(idxManage);
  }

  void goToPending() {
    if (isStaff) changeTab(idxPending);
  }

  void goToSettings() {
    changeTab(isStaff ? idxSettingsStaff : idxSettingsWarga);
  }

  void goToNotif() {
    changeTab(idxNotif);
  }

  void goToMyRequest() {
    if (!isStaff) changeTab(idxMyRequest);
  }

  void goToJasa() {
    if (!isStaff) changeTab(idxJasa);
  }
}
