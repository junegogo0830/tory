import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'archive_repository.dart';
import 'course_repository.dart';
import 'location_repository.dart';

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
