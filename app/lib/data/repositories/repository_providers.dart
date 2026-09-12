import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'archive_repository.dart';
import 'community_repository.dart';
import 'course_repository.dart';
import 'discovery_repository.dart';
import 'highlight_repository.dart';
import 'location_repository.dart';
import 'profile_repository.dart';
import 'weather_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(apiClientProvider));
});

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository(ref.watch(apiClientProvider));
});

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(apiClientProvider));
});

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(apiClientProvider));
});

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository(ref.watch(apiClientProvider));
});

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(apiClientProvider));
});
