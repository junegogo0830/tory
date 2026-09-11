import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/nearby_place.dart';
import '../../../data/repositories/repository_providers.dart';

final recentLocationsProvider = FutureProvider<List<HometownLocation>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getRecentLocations();
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
