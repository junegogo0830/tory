import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/my_memory.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/tour_course.dart';
import '../../../data/repositories/repository_providers.dart';

final profileProvider = FutureProvider<Profile>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile();
});

final myMemoriesProvider = FutureProvider<List<MyMemory>>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getMemories();
});

final myCoursesProvider = FutureProvider<List<TourCourse>>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getMyCourses();
});
