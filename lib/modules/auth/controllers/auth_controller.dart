import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../data/models/user_model.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  Rx<User?> firebaseUser = Rx<User?>(null);
  var isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();
    firebaseUser.bindStream(auth.authStateChanges());
    ever(firebaseUser, _setInitialScreen);
  }

  _setInitialScreen(User? user) async {
    if (user == null) {
      Get.offAllNamed(Routes.LOGIN);
    } else {
      try {
        DocumentSnapshot doc = await firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          UserModel userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
          if (userModel.role == 'warga') {
            Get.offAllNamed(Routes.DASHBOARD_WARGA);
          } else if (userModel.role == 'admin') {
            Get.offAllNamed(Routes.DASHBOARD_ADMIN);
          } else if (userModel.role == 'kades') {
            Get.offAllNamed(Routes.DASHBOARD_KADES);
          }
        } else {
          logout();
        }
      } catch (e) {
        logout();
      }
    }
  }

  Future<void> register(String email, String password, String namaLengkap, String noTelp) async {
    try {
      isLoading.value = true;

      // 1. Buat Auth
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      print("DEBUG: Auth Berhasil, UID: ${userCredential.user!.uid}");

      // 2. Simpan ke Firestore
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        namaLengkap: namaLengkap,
        email: email,
        noTelp: noTelp,
        role: 'warga',
      );

      await firestore.collection('users').doc(newUser.uid).set(newUser.toMap());

      print("DEBUG: Firestore Berhasil");
      isLoading.value = false;

    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      Get.snackbar('Auth Error', e.message ?? 'Terjadi kesalahan');
    } catch (e) {
      isLoading.value = false;
      print("DEBUG ERROR: $e"); // Ini akan menangkap error Pigeon jika masih ada
      Get.snackbar('System Error', 'Gagal memproses data: $e');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      await auth.signInWithEmailAndPassword(email: email, password: password);
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', 'Login Gagal. Cek email dan password.');
    }
  }

  void logout() async {
    await auth.signOut();
  }
}