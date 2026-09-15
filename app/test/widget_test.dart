import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/core/utils/image_proxy.dart';
import 'package:yetgil_app/core/constants/app_constants.dart';
import 'package:yetgil_app/data/api/api_client.dart';
import 'package:yetgil_app/data/models/hometown_location.dart';
import 'package:yetgil_app/data/models/tour_course.dart';
import 'package:yetgil_app/data/repositories/location_repository.dart';
import 'package:yetgil_app/data/repositories/repository_providers.dart';
import 'package:yetgil_app/features/auth/data/auth_providers.dart';
import 'package:yetgil_app/features/home/data/home_providers.dart';
import 'package:yetgil_app/features/home/presentation/home_screen.dart';
import 'package:yetgil_app/features/home/presentation/widgets/hero_highlight_banner.dart';

class GuestAuth extends AuthNotifier {
  @override
  Future<bool> build() async => false;
}

class FakeLocations extends LocationRepository {
  FakeLocations() : super(ApiClient());
  static const station = HometownLocation(
    id: 'station',
    name: '청명역',
    region: '경기 수원시 영통구',
    description: '',
    pastYear: 2000,
    currentYear: 2026,
  );
  @override
  Future<List<HometownLocation>> searchLocations(
    String query, {
    int limit = 5,
  }) async => [station];
  @override
  Future<HometownLocation> resolveFromQuery(String query) async => station;
}

void main() {
  test('TourAPI만 프록시를 거치며 업로드·다른 호스트는 올바르게 유지된다', () {
    const url = 'https://tong.visitkorea.or.kr/cms/photo.jpg';
    expect(
      resolveImageUrl(url),
      '${AppConstants.apiBaseUrl}/api/image/proxy?url=${Uri.encodeComponent(url)}',
    );
    expect(
      resolveImageUrl('https://example.com/photo.jpg'),
      'https://example.com/photo.jpg',
    );
    expect(
      resolveImageUrl('/uploads/community/photo.jpg'),
      '${AppConstants.apiBaseUrl}/uploads/community/photo.jpg',
    );
    expect(resolveImageUrl(resolveImageUrl(url)), resolveImageUrl(url));
  });
  test('코스의 날씨·거리·정류지 정보를 보존한다', () {
    final course = TourCourse.fromJson({
      'id': 'plan-1',
      'title': '코스',
      'description': '소개',
      'sentiment_score': 0,
      'stops': [
        {
          'name': '박물관',
          'latitude': 37.5,
          'longitude': 127.0,
          'stay_minutes': 45,
          'address': '수원',
          'category': '문화',
        },
      ],
      'duration_label': '약 90분',
      'category': '문화',
      'weather_label': '비',
      'estimated_distance_km': 1.2,
      'notes': ['실내 우선'],
    });
    expect(course.stops.single.stayMinutes, 45);
    expect(course.weatherLabel, '비');
    expect(course.distanceKm, 1.2);
    expect(course.notes, ['실내 우선']);
  });
  testWidgets('모바일 홈에서 청명역 검색 후 복귀해도 캐러셀 상태가 보존된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/compare/:id',
          builder: (_, _) => const Scaffold(body: Text('검색한 장소')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentLocationsProvider.overrideWith((ref) async => []),
          restaurantCategoriesProvider.overrideWith((ref) async => []),
          topAttractionsProvider.overrideWith((ref) async => []),
          kakaoRestaurantsNationwideProvider.overrideWith((ref) async => []),
          authStateProvider.overrideWith(GuestAuth.new),
          locationRepositoryProvider.overrideWithValue(FakeLocations()),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TextField), findsOneWidget);
    final initial = tester.state(find.byType(HeroHighlightBanner));
    await tester.enterText(find.byType(TextField), '청명역');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(
      identical(initial, tester.state(find.byType(HeroHighlightBanner))),
      isTrue,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('검색한 장소'), findsOneWidget);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      identical(initial, tester.state(find.byType(HeroHighlightBanner))),
      isTrue,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
