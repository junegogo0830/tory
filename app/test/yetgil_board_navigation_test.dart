import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/models/profile.dart';
import 'package:yetgil_app/data/models/community_post.dart';
import 'package:yetgil_app/data/models/region_stats.dart';
import 'package:yetgil_app/features/auth/data/auth_providers.dart';
import 'package:yetgil_app/features/community/data/community_providers.dart';
import 'package:yetgil_app/features/community/presentation/community_screen.dart';
import 'package:yetgil_app/features/custom_course/presentation/custom_course_create_screen.dart';
import 'package:yetgil_app/features/profile/data/profile_providers.dart';

class LoggedInAuth extends AuthNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  testWidgets('커뮤니티 → 옛길 게시판 → 코스 공유를 누르면 실제로 코스 공유 만들기 화면으로 간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/community',
      routes: [
        GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
        GoRoute(path: '/custom-courses/create', builder: (_, _) => const CustomCourseCreateScreen()),
        GoRoute(path: '/custom-courses', builder: (_, _) => const Scaffold(body: Text('코스 둘러보기 화면'))),
        GoRoute(path: '/profile', builder: (_, _) => const Scaffold(body: Text('프로필 화면'))),
      ],
    );

    const profile = Profile(
      userId: 1,
      displayName: '테스터',
      tagline: '',
      registeredCourseCount: 0,
      savedCourseCount: 0,
      postCount: 0,
      savedLocations: [],
      homeRegion: '경상북도 구미시',
      onboardingCompleted: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(LoggedInAuth.new),
          profileProvider.overrideWith((ref) async => profile),
          myRegionsProvider.overrideWith((ref) async => ['경상북도 구미시']),
          regionStatsProvider.overrideWith(
            (ref, region) async => const RegionStats(region: '경상북도 구미시', memberCount: 1, postCount: 0),
          ),
          communityFeedProvider.overrideWith((ref, arg) async => <CommunityPost>[]),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 옛길 게시판 카드 탭 → 팝업.
    await tester.tap(find.text('옛길 게시판'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 항목으로 이동하시겠어요?'), findsOneWidget);

    // "코스 공유" 버튼 탭.
    await tester.tap(find.text('코스 공유'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/custom-courses/create');
    expect(find.text('코스 공유 만들기', skipOffstage: false), findsOneWidget);
    expect(find.text('장소 추가', skipOffstage: false), findsOneWidget);
    expect(find.text('코스 등록하기', skipOffstage: false), findsOneWidget);

    // 회귀 방지: bottomNavigationBar 안 Center가 세로로 가득 확장해서 body가
    // 통째로 안 보였던 버그(navigation을 실제로 타고 들어왔을 때도 재현됨을 확인).
    final listViewSize = tester.getSize(find.byType(ListView));
    expect(listViewSize.height, greaterThan(400));
  });
}
