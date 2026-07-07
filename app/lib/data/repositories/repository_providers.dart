import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'archive_repository.dart';
import 'course_repository.dart';
import 'location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository();
});

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository();
});
