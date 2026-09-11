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

/// 홈 화면의 "현재 추천 코스" 패널에서 사용하는 장소별 코스 목록.
final coursesByLocationProvider = FutureProvider.family<List<TourCourse>, String>((ref, locationId) {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getCoursesByLocation(locationId);
});
