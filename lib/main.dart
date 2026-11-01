import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/complaint_controller.dart';
import 'controllers/data_controller.dart';
import 'controllers/feedback_controller.dart';
import 'controllers/village_controller.dart';
import 'core/core.dart';
import 'core/translations.dart';
import 'firebase_options.dart';
import 'views/auth_view.dart';
import 'views/home_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id', null);
  await GetStorage.init();

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
      // Ukuran huruf mengikuti pilihan di Pengaturan → Ukuran Huruf
      builder: (context, child) => Obx(() => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(AppSettings.fontScale.value)),
            child: child ?? const SizedBox.shrink(),
          )),
      theme: AppTheme.buildTheme('warga'),
      translations: AppTranslations(),
      locale: LocalStore.bahasa == 'en'
          ? const Locale('en', 'US')
          : const Locale('id', 'ID'),
      fallbackLocale: const Locale('id', 'ID'),
      initialBinding: BindingsBuilder(() {
        // Urutan penting: controller yang memakai Get.find() controller
        // lain harus didaftarkan belakangan.
        Get.put<AuthController>(AuthController(), permanent: true);
        Get.put<MainController>(MainController(), permanent: true);
        Get.put<NotificationController>(NotificationController(), permanent: true);
        Get.put<ServiceController>(ServiceController(), permanent: true);
        Get.put<ComplaintController>(ComplaintController(), permanent: true);
        Get.put<ChatController>(ChatController(), permanent: true);
        Get.put<OrderController>(OrderController(), permanent: true);
        Get.put<SosController>(SosController(), permanent: true);
        Get.put<PollController>(PollController(), permanent: true);
        Get.put<AgendaController>(AgendaController(), permanent: true);
        Get.put<LetterController>(LetterController(), permanent: true);
        Get.put<FeedbackController>(FeedbackController(), permanent: true);
        Get.put<FotoProfilController>(FotoProfilController(), permanent: true);
      }),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 320),
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
