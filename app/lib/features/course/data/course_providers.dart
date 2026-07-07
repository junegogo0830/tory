import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/tour_course.dart';
import '../../../data/repositories/repository_providers.dart';

final allCoursesProvider = FutureProvider<List<TourCourse>>((ref) {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getAllCourses();
});

final courseDetailProvider = FutureProvider.family<TourCourse?, String>((ref, courseId) {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getCourseById(courseId);
});
