// ============================================================
// auth_controller.dart
// Logic: Login, Register, Logout, Reset Password, Role Detection
// Menggunakan GetX sebagai state management
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/app_models.dart';
import 'main_controller.dart';

class AuthController extends GetxController {
  // ─── Firebase Instances ──────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Reactive State ──────────────────────────────────────
  final Rx<User?> _firebaseUser = Rx<User?>(null);
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // ─── Getters ─────────────────────────────────────────────
  bool get isLoggedIn => _firebaseUser.value != null;
  String get role => currentUser.value?.role ?? 'warga';
  bool get isStaff => role == 'admin' || role == 'kades';

  // ─────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    // Pantau perubahan status autentikasi Firebase
    _firebaseUser.bindStream(_auth.authStateChanges());
    ever(_firebaseUser, _handleAuthChange);
  }

  /// Dipanggil setiap kali status auth berubah
  void _handleAuthChange(User? user) {
    if (user == null) {
      // User logout → bersihkan data dan arahkan ke login
      currentUser.value = null;
      Get.offAllNamed('/login');
    } else {
      // User login → load data profil dari Firestore
      _loadUserData(user.uid);
    }
  }

  /// Load data pengguna dari Firestore berdasarkan UID
  Future<void> _loadUserData(String uid) async {
    try {
      final DocumentSnapshot doc =
      await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        currentUser.value = UserModel.fromFirestore(doc);
        // Arahkan ke halaman utama sesuai role
        _navigateByRole(currentUser.value!.role);
      } else {
        // Dokumen user tidak ada di Firestore → kemungkinan bug, logout
        await logout();
      }
    } catch (e) {
      errorMessage.value = 'Gagal memuat data pengguna: $e';
    }
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
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Buat akun Firebase Auth
      final UserCredential credential =
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;

      // Buat dokumen user di Firestore
      final UserModel newUser = UserModel(
        uid: uid,
        nama: nama.trim(),
        email: email.trim(),
        role: 'warga', // Default: semua user baru adalah warga
        nomorTelepon: nomorTelepon.trim(),
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());

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
  // LOGIN
  // ─────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // _handleAuthChange akan otomatis dipanggil → load data → navigate
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
  // LOGOUT
  // ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      // Reset navbar index ke 0 sebelum logout
      try {
        Get.find<MainController>().resetToHome();
      } catch (_) {}

      await _auth.signOut();
      currentUser.value = null;
    } catch (e) {
      errorMessage.value = 'Gagal logout. Silakan coba lagi.';
    }
  }

  // ─────────────────────────────────────────────────────────
  // RESET PASSWORD
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
  // UPDATE PROFIL
  // ─────────────────────────────────────────────────────────
  Future<bool> updateProfil({
    required String nama,
    required String nomorTelepon,
    String? fotoUrl,
  }) async {
    try {
      isLoading.value = true;
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final Map<String, dynamic> updates = {
        'nama': nama.trim(),
        'nomor_telepon': nomorTelepon.trim(),
      };

      if (fotoUrl != null) {
        updates['foto_url'] = fotoUrl;
      }

      await _firestore.collection('users').doc(uid).update(updates);

      // Reload data lokal
      await _loadUserData(uid);
      return true;
    } catch (e) {
      errorMessage.value = 'Gagal memperbarui profil: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE LOKASI
  // ─────────────────────────────────────────────────────────
  Future<void> updateLokasi(double lat, double lng) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('users').doc(uid).update({
        'lokasi_lat': lat,
        'lokasi_lng': lng,
      });

      // Update state lokal juga
      if (currentUser.value != null) {
        currentUser.refresh();
      }
    } catch (e) {
      // Tidak perlu tampilkan error, ini background task
      print('Gagal update lokasi: $e');
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
      default:
        return 'Terjadi kesalahan ($code). Silakan coba lagi.';
    }
  }
}