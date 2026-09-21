import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/models/tour_course.dart';
import 'package:yetgil_app/features/auth/data/auth_providers.dart';
import 'package:yetgil_app/features/course/data/course_providers.dart';
import 'package:yetgil_app/features/course/presentation/course_detail_screen.dart';

class _GuestAuth extends AuthNotifier {
  @override
  Future<bool> build() async => false;
}

TourCourse _tourismOnlyCourse() => const TourCourse(
      id: 'llm-test-summer',
      title: '테스트 산책 코스',
      description: '관광지로만 구성된 코스예요',
      sentimentScore: 0.8,
      stops: [
        CourseStop(name: '경복궁', category: '관광지', latitude: 37.58, longitude: 126.97),
        CourseStop(name: '북촌한옥마을', category: '관광지', latitude: 37.58, longitude: 126.98),
      ],
      durationLabel: '약 2시간',
      category: '산책',
    );

TourCourse _courseWithMeal() => const TourCourse(
      id: 'llm-test-summer',
      title: '테스트 산책 코스',
      description: '관광지로만 구성된 코스예요',
      sentimentScore: 0.8,
      stops: [
        CourseStop(name: '경복궁', category: '관광지', latitude: 37.58, longitude: 126.97),
        CourseStop(
          name: '광화문국밥',
          category: '음식점',
          latitude: 37.575,
          longitude: 126.975,
          isMeal: true,
          mealType: 'lunch',
        ),
        CourseStop(name: '북촌한옥마을', category: '관광지', latitude: 37.58, longitude: 126.98),
      ],
      durationLabel: '약 2시간',
      category: '산책',
    );

Widget _app(TourCourse course) {
  final router = GoRouter(
    initialLocation: '/course/${course.id}',
    routes: [
      GoRoute(path: '/course/:id', builder: (_, _) => CourseDetailScreen(courseId: course.id)),
    ],
  );
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_GuestAuth.new),
      courseDetailProvider(course.id).overrideWith((ref) async => course),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('관광지만 있는 코스는 "식사를 추가하시겠어요?" CTA를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_tourismOnlyCourse()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('경복궁'), findsOneWidget);
    expect(find.text('식사를 추가하시겠어요?'), findsOneWidget);
    expect(find.text('식사 추가'), findsOneWidget);
    expect(find.text('음식점'), findsNothing);
  });

  testWidgets('식사가 추가된 코스는 시간대/식당 이름과 변경·삭제 버튼을 보여준다', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_courseWithMeal()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('식사를 추가하시겠어요?'), findsNothing);
    expect(find.text('점심'), findsOneWidget);
    // "광화문국밥"은 방문 순서 타임라인과 식사 섹션 양쪽에 다 나온다(같은 정류지라 의도된 중복).
    expect(find.text('광화문국밥'), findsNWidgets(2));
    expect(find.text('변경'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(find.text('다른 식사 추가'), findsOneWidget);
  });
}
