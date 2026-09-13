import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brightness_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KakaoSdk.init(nativeAppKey: AppConstants.kakaoNativeAppKey);
  runApp(const ProviderScope(child: YetgilApp()));
}

class YetgilApp extends StatelessWidget {
  const YetgilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BrightnessScope(
      builder: (context) => MaterialApp.router(
        title: '옛길',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: AppColors.darkModeNotifier.value ? ThemeMode.dark : ThemeMode.light,
        routerConfig: appRouter,
      ),
    );
  }
}
