import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/custom_course.dart';
import '../../../data/models/memory_match.dart';
import '../../../data/repositories/repository_providers.dart';

typedef CustomCourseListQuery = ({String? category, String sort});

final customCourseListProvider =
    FutureProvider.family<List<CustomCourseSummary>, CustomCourseListQuery>((ref, query) {
  final repo = ref.watch(customCourseRepositoryProvider);
  return repo.list(category: query.category, sort: query.sort);
});

final customCourseDetailProvider = FutureProvider.family<CustomCourse, int>((ref, id) {
  final repo = ref.watch(customCourseRepositoryProvider);
  return repo.getById(id);
});

final customCourseCommentsProvider = FutureProvider.family<List<CustomCourseComment>, int>((ref, id) {
  final repo = ref.watch(customCourseRepositoryProvider);
  return repo.comments(id);
});

/// 로그인 필요 — "내 코스에서 가져오기" 시트가 쓴다.
final myCustomCoursesProvider = FutureProvider<List<CustomCourseSummary>>((ref) {
  final repo = ref.watch(customCourseRepositoryProvider);
  return repo.list(mine: true, limit: 50);
});

/// 이 코스와 추억이 겹치는 사람 목록 — 코스 상세의 "겹치는 사람 N명" 섹션이 쓴다.
final courseMemoryOverlapProvider = FutureProvider.family<List<MemoryMatch>, int>((ref, courseId) {
  final repo = ref.watch(customCourseRepositoryProvider);
  return repo.memoryOverlap(courseId);
});
