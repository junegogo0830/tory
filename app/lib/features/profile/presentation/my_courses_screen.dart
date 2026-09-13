import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tour_course.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/profile_providers.dart';

/// 프로필 "내가 만든 코스" — 로그인 상태로 생성한 맞춤 코스가 자동으로 쌓인다.
class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCoursesProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('내가 만든 코스')),
      body: SafeArea(
        child: coursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.map_outlined,
                    title: '아직 만든 코스가 없어요',
                    message: '코스 탭에서 맞춤 코스를 만들어보세요.',
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _MyCourseCard(course: courses[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}

class _MyCourseCard extends StatelessWidget {
  const _MyCourseCard({required this.course});

  final TourCourse course;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: course.imageUrl != null
                  ? AppNetworkImage(
                      imageUrl: course.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
                      placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
                    )
                  : const PhotoFallback(icon: Icons.route_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTypography.headline),
                const SizedBox(height: 4),
                Text(
                  course.description,
                  style: AppTypography.footnote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${course.category} · ${course.durationLabel} · ${course.stops.length}곳',
                  style: AppTypography.caption.copyWith(color: AppColors.accentDeep),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
