import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/recent_course.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../data/recent_course_providers.dart';

/// 코스 탭 상단 "이어보기" — GPS 기반 "내 주변 코스"를 대체한다. 마지막으로
/// 열어본 코스(생성 코스든 직접 만든 코스든)를 바로 이어서 볼 수 있게 한다.
/// 볼 게 없으면(비로그인, 아직 본 코스 없음, 캐시 만료 등) 조용히 숨는다.
class RecentCourseCard extends ConsumerWidget {
  const RecentCourseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentCourseProvider);
    return recentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (course) => course == null ? const SizedBox.shrink() : _RecentCourseContent(course: course),
    );
  }
}

class _RecentCourseContent extends StatelessWidget {
  const _RecentCourseContent({required this.course});

  final RecentCourse course;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: AppColors.accentDeep, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text('최근 본 코스 이어보기', style: AppTypography.headline)),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(12),
          onTap: () => context.push(course.isCustom ? '/custom-courses/${course.courseId}' : '/course/${course.courseId}'),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: SizedBox(
                  width: 72,
                  height: 72,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.headline),
                    const SizedBox(height: 4),
                    Text(
                      '${course.category ?? '코스'} · 장소 ${course.placeCount}곳',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ],
    );
  }
}
