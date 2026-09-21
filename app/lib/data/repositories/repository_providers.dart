import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'archive_repository.dart';
import 'chatbot_repository.dart';
import 'community_repository.dart';
import 'connection_repository.dart';
import 'course_repository.dart';
import 'custom_course_repository.dart';
import 'discovery_repository.dart';
import 'location_repository.dart';
import 'memory_repository.dart';
import 'notification_repository.dart';
import 'profile_repository.dart';
import 'saved_course_repository.dart';
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

final customCourseRepositoryProvider = Provider<CustomCourseRepository>((ref) {
  return CustomCourseRepository(ref.watch(apiClientProvider));
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

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.watch(apiClientProvider));
});

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepository(ref.watch(apiClientProvider));
});

final savedCourseRepositoryProvider = Provider<SavedCourseRepository>((ref) {
  return SavedCourseRepository(ref.watch(apiClientProvider));
});

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository(ref.watch(apiClientProvider));
});
