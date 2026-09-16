import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/recent_course.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/data/auth_providers.dart';

/// 홈 "이어보기" 카드용 — 비로그인 상태면 조회할 것도 없으니 바로 null.
final recentCourseProvider = FutureProvider<RecentCourse?>((ref) async {
  if (!(ref.watch(authStateProvider).value ?? false)) return null;
  return ref.watch(profileRepositoryProvider).getRecentCourse();
});
