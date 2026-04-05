import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/main_controller.dart';
import 'core/app_theme.dart';
import 'views/auth_view.dart';
import 'views/main_layout_view.dart';
import 'controllers/data_controller.dart';  // ← TAMBAH INI
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        Get.put<AuthController>(AuthController(), permanent: true);
        Get.put<MainController>(MainController(), permanent: true);
        Get.put<DataController>(DataController(), permanent: true);  // ← TAMBAH INI
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
      ],
    );
  }
}