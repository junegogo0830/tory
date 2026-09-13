import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/highlight_card.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/kakao_restaurant.dart';
import '../../../data/models/nearby_place.dart';
import '../../../data/models/restaurant_category.dart';
import '../../../data/models/top_attraction.dart';
import '../../../data/models/weather_info.dart';
import '../../../data/repositories/repository_providers.dart';

final recentLocationsProvider = FutureProvider<List<HometownLocation>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getRecentLocations();
});

/// 홈 화면 상단 배너용 현재 날씨. 좌표는 위젯이 GPS로 구해서 넘겨준다.
final weatherProvider =
    FutureProvider.family<WeatherInfo?, ({double lat, double lng})>((ref, coords) {
  final repo = ref.watch(weatherRepositoryProvider);
  return repo.getCurrentWeather(lat: coords.lat, lng: coords.lng);
});

/// 홈 화면 카드 캐러셀용 TourAPI 기반 인기 장소 10장(랜덤).
final highlightCardsProvider = FutureProvider<List<HighlightCard>>((ref) {
  final repo = ref.watch(highlightRepositoryProvider);
  return repo.getHighlightCards();
});

/// 둘러보기 화면에서 사용하는 전체 장소 목록.
final allLocationsProvider = FutureProvider<List<HometownLocation>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getAllLocations();
});

/// 코스 상세 화면의 "주변 맛집" 섹션에서 사용.
final nearbyRestaurantsProvider = FutureProvider.family<List<NearbyPlace>, String>((ref, locationId) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getNearbyRestaurants(locationId);
});

/// 검색창 밑 "인기 관광지 TOP 10" 티커용. 하루 단위로 백엔드에서 캐싱된다.
final topAttractionsProvider = FutureProvider<List<TopAttraction>>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getTopAttractions();
});

/// 지역 뉴스/커뮤니티 사이 "카테고리별 맛집" 캐러셀용.
final restaurantCategoriesProvider = FutureProvider<List<RestaurantCategory>>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getRestaurantCategories();
});

/// 카카오맵 기반 맛집 카드 "전국" 모드용. 하루 단위로 백엔드에서 캐싱된다.
final kakaoRestaurantsNationwideProvider = FutureProvider<List<KakaoRestaurant>>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getKakaoRestaurantsNationwide();
});

/// 카카오맵 기반 맛집 카드 "내 주변" 모드용(반경 5km) — 좌표가 바뀌면 다시 조회한다.
final kakaoRestaurantsNearbyProvider =
    FutureProvider.family<List<KakaoRestaurant>, ({double lat, double lng})>((ref, coords) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getKakaoRestaurantsNearby(lat: coords.lat, lng: coords.lng);
});

/// 둘러보기 탭 "다른 사람들이 둘러본 골목" — 아직 아무도 안 찜했으면 빈 리스트.
final popularLocationsProvider = FutureProvider<List<HometownLocation>>((ref) {
  final repo = ref.watch(discoveryRepositoryProvider);
  return repo.getPopularLocations();
});

/// 둘러보기 탭이 실제로 그리는 목록 — 다른 사람들이 찜한 골목을 우선 보여주고,
/// 아직 아무도 안 찜한 콜드 스타트 상태(찜 데이터 0건)면 큐레이션 3곳으로 폴백한다.
final exploreLocationsProvider = FutureProvider<List<HometownLocation>>((ref) async {
  final popular = await ref.watch(popularLocationsProvider.future);
  if (popular.isNotEmpty) return popular;
  return ref.watch(allLocationsProvider.future);
});
