import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/data_controller.dart';
import 'core/core.dart';
import 'firebase_options.dart';
import 'views/auth_view.dart';
import 'views/home_view.dart';

/// Wajib berupa fungsi top-level (bukan method kelas) sesuai ketentuan
/// firebase_messaging untuk menangani notifikasi saat aplikasi tertutup.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id', null);
  await GetStorage.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const TalagasariHubApp());
}

class TalagasariHubApp extends StatelessWidget {
  const TalagasariHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Talagasari Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme('warga'),
      locale: const Locale('id', 'ID'),
      fallbackLocale: const Locale('id', 'ID'),
      initialBinding: BindingsBuilder(() {
        // Urutan penting: controller yang memakai Get.find() controller
        // lain harus didaftarkan belakangan.
        Get.put<AuthController>(AuthController(), permanent: true);
        Get.put<MainController>(MainController(), permanent: true);
        Get.put<NotificationController>(NotificationController(), permanent: true);
        Get.put<ServiceController>(ServiceController(), permanent: true);
        Get.put<ChatController>(ChatController(), permanent: true);
      }),
      initialRoute: '/login',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const AuthView(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/home',
          page: () => const MainLayoutView(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/lock',
          page: () => const LockView(),
          transition: Transition.fadeIn,
        ),
      ],
    );
  }
}
