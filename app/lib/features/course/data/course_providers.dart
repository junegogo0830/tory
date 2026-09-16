import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/tour_course.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/data/auth_providers.dart';

final allCoursesProvider = FutureProvider<List<TourCourse>>((ref) {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getAllCourses();
});

/// 이 코스 상세 화면이 열릴 때마다(딱 courseId 하나에 딱 한 번) 홈 "이어보기"용
/// 기록을 남긴다 — 비로그인 상태면 조용히 건너뛴다(로그인 없이도 코스 상세는
/// 볼 수 있어서 401로 실패시키면 안 된다).
final courseDetailProvider = FutureProvider.family<TourCourse?, String>((
  ref,
  courseId,
) async {
  final repo = ref.watch(courseRepositoryProvider);
  final course = await repo.getCourseById(courseId);
  if (course != null && (ref.read(authStateProvider).value ?? false)) {
    unawaited(ref.read(profileRepositoryProvider).recordCourseView(courseType: 'generated', courseId: courseId));
  }
  return course;
});

/// 홈 화면의 "현재 추천 코스" 패널에서 사용하는 장소별 코스 목록.
final coursesByLocationProvider =
    FutureProvider.family<List<TourCourse>, String>((ref, locationId) {
      final repo = ref.watch(courseRepositoryProvider);
      return repo.getCoursesByLocation(locationId);
    });
