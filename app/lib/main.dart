import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KakaoSdk.init(
    nativeAppKey: AppConstants.kakaoNativeAppKey,
    javaScriptAppKey: AppConstants.kakaoJavaScriptAppKey,
  );
  runApp(const ProviderScope(child: _StartupSplash(child: YetgilApp())));
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash({required this.child});
  final Widget child;
  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  // 웹은 web/index.html의 정적 HTML 스플래시(#app-loading)가 이미 이 역할을
  // 한다 — 거기 더해 여기서 또 다른 배경색/크기로 스플래시를 얹으면 로고가
  // 두 번 다른 모습으로 바뀌는 것처럼 보인다. 네이티브(APK/iOS)는 그런
  // 정적 웹 스플래시가 없어서 이 위젯이 대신 그 gap을 메운다.
  bool _ready = kIsWeb;
  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _ready = true);
    });
  }
  @override
  Widget build(BuildContext context) => _ready ? widget.child : const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFFF2EFEA),
      body: SizedBox.expand(
        child: Image(image: AssetImage('assets/logo/splash.png'), fit: BoxFit.cover),
      ),
    ),
  );
}

class YetgilApp extends ConsumerStatefulWidget {
  const YetgilApp({super.key});

  @override
  ConsumerState<YetgilApp> createState() => _YetgilAppState();
}

class _YetgilAppState extends ConsumerState<YetgilApp> {
  @override
  void initState() {
    super.initState();
    // 웹 카카오 로그인은 카카오 인증 서버로 전체 페이지 리다이렉트했다가 돌아오는
    // 방식이라(AuthRepository.loginWithKakao 참고), 로그인 완료는 여기 앱이 다시
    // 뜰 때 주소창의 ?code=...를 읽어서 마무리한다. Uri.base는 go_router의 해시
    // 라우팅과 무관하게 브라우저 주소창 자체를 그대로 반영해 항상 이 code를 볼 수 있다.
    if (kIsWeb) {
      final code = Uri.base.queryParameters['code'];
      if (code != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(authStateProvider.notifier).completeKakaoWebLogin(code);
        });
      }
    }
  }

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
