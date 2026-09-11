import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  KakaoSdk.init(nativeAppKey: AppConstants.kakaoNativeAppKey);
  runApp(const ProviderScope(child: YetgilApp()));
}

class YetgilApp extends StatelessWidget {
  const YetgilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '옛길',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
