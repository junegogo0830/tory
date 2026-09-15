import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/models/custom_course.dart';
import 'package:yetgil_app/features/auth/data/auth_providers.dart';
import 'package:yetgil_app/features/custom_course/data/custom_course_providers.dart';
import 'package:yetgil_app/features/custom_course/presentation/custom_course_detail_screen.dart';

class _GuestAuth extends AuthNotifier {
  @override
  Future<bool> build() async => false;
}

CustomCourse _course({bool isMine = true}) => CustomCourse(
      id: 1,
      authorId: 1,
      authorNickname: '테스터',
      title: '경복궁-북촌-인사동 하루 코스',
      category: '역사',
      description: '조선시대 정취를 느낄 수 있는 하루 코스예요',
      places: const [
        CustomCoursePlace(source: 'tour', placeId: 't1', name: '경복궁', address: '서울 종로구 사직로 161', note: '조선의 역사가 살아 숨 쉬는 대표 궁궐이에요'),
        CustomCoursePlace(source: 'tour', placeId: 't2', name: '북촌한옥마을', address: '서울 종로구 계동길 일대'),
        CustomCoursePlace(source: 'tour', placeId: 't3', name: '인사동', address: '서울 종로구 인사동길 일대'),
      ],
      likeCount: 3,
      dislikeCount: 0,
      commentCount: 0,
      isMine: isMine,
      createdAt: DateTime(2026, 9, 14),
    );

void main() {
  testWidgets('코스 둘러보기 화면이 예외 없이 렌더링되고 새 구조(타임라인/액션/CTA)를 갖춘다', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final course = _course();
    final router = GoRouter(
      initialLocation: '/custom-courses/1',
      routes: [
        GoRoute(path: '/custom-courses/:id', builder: (_, _) => const CustomCourseDetailScreen(courseId: 1)),
        GoRoute(path: '/custom-courses/:id/edit', builder: (_, _) => const Scaffold(body: Text('edit'))),
        GoRoute(path: '/custom-courses/:id/map', builder: (_, _) => const Scaffold(body: Text('map'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_GuestAuth.new),
          customCourseDetailProvider(1).overrideWith((ref) async => course),
          customCourseCommentsProvider(1).overrideWith((ref) async => <CustomCourseComment>[]),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('코스 둘러보기'), findsOneWidget);
    expect(find.text('코스 수정'), findsOneWidget); // isMine=true
    expect(find.text('경복궁'), findsOneWidget);
    expect(find.text('북촌한옥마을'), findsOneWidget);
    expect(find.text('인사동'), findsOneWidget);
    expect(find.text('지도 보기'), findsOneWidget);
    expect(find.text('일정표 보기'), findsOneWidget);
    expect(find.text('코스 공유하기'), findsOneWidget);
    expect(find.text('이 코스 선택하기'), findsOneWidget);

    // "일정표 보기"를 누르면 바텀시트가 열리고 장소 목록이 다시 나온다.
    await tester.tap(find.text('일정표 보기'));
    await tester.pumpAndSettle();
    expect(find.text('일정표'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('내 코스가 아니면 코스 수정 버튼이 없다', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final course = _course(isMine: false);
    final router = GoRouter(
      initialLocation: '/custom-courses/1',
      routes: [
        GoRoute(path: '/custom-courses/:id', builder: (_, _) => const CustomCourseDetailScreen(courseId: 1)),
        GoRoute(path: '/custom-courses/:id/map', builder: (_, _) => const Scaffold(body: Text('map'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_GuestAuth.new),
          customCourseDetailProvider(1).overrideWith((ref) async => course),
          customCourseCommentsProvider(1).overrideWith((ref) async => <CustomCourseComment>[]),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('코스 수정'), findsNothing);
  });
}
