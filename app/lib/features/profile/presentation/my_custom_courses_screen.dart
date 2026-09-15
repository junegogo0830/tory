import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/custom_course.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../custom_course/data/custom_course_providers.dart';

/// 프로필 "등록한 코스" — 내가 만든 코스 커스텀(코스 공유) 목록. "코스 커스텀에서
/// 가져오기" 시트가 쓰는 것과 같은 목록(myCustomCoursesProvider)이라 그대로 재사용한다.
class MyCustomCoursesScreen extends ConsumerWidget {
  const MyCustomCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myCustomCoursesProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('등록한 코스')),
      body: SafeArea(
        child: coursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.route_outlined,
                    title: '아직 등록한 코스가 없어요',
                    message: '코스 커스텀에서 나만의 코스를 만들어 공유해보세요.',
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _CourseCard(course: courses[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final CustomCourseSummary course;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/custom-courses/${course.id}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.card)),
            child: SizedBox(
              width: 88,
              height: 88,
              child: course.thumbnailUrl != null
                  ? AppNetworkImage(
                      imageUrl: course.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
                      errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
                    )
                  : const PhotoFallback(icon: Icons.route_outlined),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title, style: AppTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(
                    '${course.category} · 장소 ${course.placeCount}곳',
                    style: AppTypography.caption.copyWith(color: AppColors.accentDeep),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
