import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_colors.dart';
import '../../../data/models/tour_course.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/course_providers.dart';
import 'widgets/recent_course_card.dart';
import 'widgets/region_picker_sheet.dart';

Widget _courseImage(TourCourse course, {required BoxFit fit}) {
  if (course.imageUrl == null) {
    return const PhotoFallback(icon: Icons.route_outlined);
  }
  return AppNetworkImage(
    imageUrl: course.imageUrl!,
    fit: fit,
    errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
    placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
  );
}

const _categories = ['전체', '산책', '역사', '미식', '문화', '자연', '가족'];

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  int selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(allCoursesProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: coursesAsync.when(
              data: (courses) {
                final category = _categories[selectedCategory];
                final filtered = category == '전체'
                    ? [...courses]
                    : courses.where((c) => c.category == category).toList();
                filtered.sort(
                  (a, b) => b.sentimentScore.compareTo(a.sentimentScore),
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '추천 코스',
                                style: AppTypography.title.copyWith(
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '추억에서 오늘의 여행으로',
                                style: AppTypography.subhead,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.map_outlined,
                            size: 21,
                            color: AppColors.accentDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const RecentCourseCard(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showRegionPickerSheet(context, ref),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('지역 선택해서 코스 만들기'),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final selected = selectedCategory == index;
                          return ChoiceChip(
                            label: Text(_categories[index]),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => selectedCategory = index),
                            showCheckmark: false,
                            selectedColor: AppColors.accent,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.hairline,
                            ),
                            shape: const StadiumBorder(),
                            labelStyle: AppTypography.footnote.copyWith(
                              color: selected ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.route_outlined,
                        title: '아직 추천 코스가 없어요',
                        message: '데이터가 모이는 대로 코스를 추천해드릴게요.',
                      )
                    else ...[
                      _FeaturedCourse(course: filtered.first),
                      if (filtered.length > 1) ...[
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final rest = filtered.skip(1).toList();
                            final cards = [
                              for (final course in rest)
                                _SmallCourse(course: course),
                            ];
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  for (final card in cards) ...[
                                    card,
                                    const SizedBox(height: 14),
                                  ],
                                ],
                              );
                            }
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final card in cards)
                                  SizedBox(
                                    width: (constraints.maxWidth - 14) / 2,
                                    child: card,
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (_, _) => Center(
                child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCourse extends StatelessWidget {
  const _FeaturedCourse({required this.course});
  final TourCourse course;

  @override
  Widget build(BuildContext context) {
    // 예전엔 이 카드에만 "코스 시작하기" 버튼이 있어서 아래 _SmallCourse
    // 카드들(카드 전체를 눌러 들어가는 방식)과 진입 방법이 서로 달랐다 —
    // 버튼을 없애고 카드 전체를 누르는 방식으로 통일한다.
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7.5,
                child: _courseImage(course, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  course.title,
                  style: AppTypography.title.copyWith(
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                ),
                _InfoPill(
                  icon: Icons.category_outlined,
                  label: course.category,
                  pastelColor: pastelForCategory(course.category),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course.durationLabel,
              style: AppTypography.footnote.copyWith(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              course.description,
              style: AppTypography.subhead.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < course.stops.length; i++)
              _RouteStop(
                number: i + 1,
                title: course.stops[i].name,
                last: i == course.stops.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.number,
    required this.title,
    this.last = false,
  });
  final int number;
  final String title;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: AppColors.hairline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.pastelColor});
  final IconData icon;
  final String label;
  // 카테고리 배지용 파스텔 배경(docs/DESIGN_SYSTEM.md §1.3).
  final Color? pastelColor;

  @override
  Widget build(BuildContext context) {
    final background = pastelColor ?? AppColors.surface;
    final foreground = pastelColor != null
        ? AppColors.accentDeep
        : AppColors.inkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.tag),
        border: pastelColor != null
            ? null
            : Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallCourse extends StatelessWidget {
  const _SmallCourse({required this.course});
  final TourCourse course;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _courseImage(course, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pastelForCategory(course.category),
                borderRadius: BorderRadius.circular(AppRadius.tag),
              ),
              child: Text(
                course.category,
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentDeep,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              course.title,
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              course.durationLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              course.description,
              style: AppTypography.subhead.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({required double radius}) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: AppShadows.card,
);
