import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/models/profile.dart';
import 'package:yetgil_app/features/auth/data/auth_providers.dart';
import 'package:yetgil_app/features/community/presentation/community_screen.dart';
import 'package:yetgil_app/features/home/presentation/widgets/hero_highlight_banner.dart';
import 'package:yetgil_app/features/profile/data/profile_providers.dart';

class _Guest extends AuthNotifier {
  @override
  Future<bool> build() async => false;
}

class _Member extends AuthNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  for (final loggedIn in [false, true]) {
    testWidgets('지역 미선택, 로그인=$loggedIn: 옛길 전체 코스와 내 코스의 입구 분리', (tester) async {
      final router = GoRouter(initialLocation: '/community', routes: [
        GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
        GoRoute(path: '/custom-courses', builder: (_, _) => const Scaffold(body: Text('전체 공개 코스'))),
        GoRoute(path: '/my-custom-courses', builder: (_, _) => const Scaffold(body: Text('내 코스'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        authStateProvider.overrideWith(loggedIn ? _Member.new : _Guest.new),
        profileProvider.overrideWith((ref) async => const Profile(
          userId: 1, displayName: '회원', tagline: '', registeredCourseCount: 0,
          savedCourseCount: 0, postCount: 0, savedLocations: [], onboardingCompleted: true,
        )),
      ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('옛길 게시판'), findsOneWidget);
      await tester.tap(find.text('옛길 게시판'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('코스 둘러보기'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/custom-courses');
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('코스 커스텀'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my-custom-courses');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('배너 자세히 보기는 검색 호출 없이 고정 장소로 이동한다', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: HeroHighlightBanner())),
      GoRoute(path: '/compare/:id', builder: (_, state) => Scaffold(body: Text(state.pathParameters['id']!))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자세히 보기').first);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/compare/hero-gangneung-namsan');
    await tester.pumpWidget(const SizedBox());
  });
}
