import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tour_course.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/course_providers.dart';

class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(allCoursesProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('추천 코스')),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return const EmptyState(
              icon: Icons.route_outlined,
              title: '아직 추천 코스가 없어요',
              message: '데이터가 모이는 대로 코스를 추천해드릴게요.',
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _CourseCard(course: courses[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final TourCourse course;

  @override
  Widget build(BuildContext context) {
    final scorePercent = (course.sentimentScore * 100).round();

    return AppCard(
      onTap: () => context.push('/course/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(course.title, style: AppTypography.headline)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '감성 $scorePercent%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(course.description, style: AppTypography.subhead),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.inkTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  course.stops.join(' · '),
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(course.durationLabel, style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}
