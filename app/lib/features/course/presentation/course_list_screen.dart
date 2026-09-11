import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tour_course.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/course_providers.dart';

Widget _courseImage(TourCourse course, {required BoxFit fit}) {
  if (course.imageUrl == null) return const PhotoFallback(icon: Icons.route_outlined);
  return CachedNetworkImage(
    imageUrl: course.imageUrl!,
    fit: fit,
    errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
    placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
  );
}

const _categories = ['전체', '산책', '역사', '미식'];

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
                filtered.sort((a, b) => b.sentimentScore.compareTo(a.sentimentScore));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('추천 코스', style: AppTypography.largeTitle.copyWith(fontSize: 34)),
                              const SizedBox(height: 5),
                              Text('추억에서 오늘의 여행으로', style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.map_outlined, size: 35, color: AppColors.accentDeep),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => ChoiceChip(
                          label: Text(_categories[index]),
                          selected: selectedCategory == index,
                          onSelected: (_) => setState(() => selectedCategory = index),
                          showCheckmark: false,
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.hairline),
                          labelStyle: AppTypography.subhead.copyWith(
                            color: selectedCategory == index ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
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
                              for (final course in rest) _SmallCourse(course: course),
                            ];
                            if (constraints.maxWidth < 560) {
                              return Column(
                                children: [
                                  for (final card in cards) ...[card, const SizedBox(height: 14)],
                                ],
                              );
                            }
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final card in cards)
                                  SizedBox(width: (constraints.maxWidth - 14) / 2, child: card),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
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
    final scorePercent = (course.sentimentScore * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(aspectRatio: 16 / 7.5, child: _courseImage(course, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(course.title, style: AppTypography.title.copyWith(fontSize: 25)),
              _InfoPill(icon: Icons.favorite, label: '감성 $scorePercent%', accent: true),
              _InfoPill(icon: Icons.schedule, label: course.durationLabel),
            ],
          ),
          const SizedBox(height: 12),
          Text(course.description, style: AppTypography.subhead),
          const SizedBox(height: 18),
          for (var i = 0; i < course.stops.length; i++)
            _RouteStop(number: i + 1, title: course.stops[i].name, last: i == course.stops.length - 1),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/course/${course.id}'),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('코스 시작하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.number, required this.title, this.last = false});
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
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.accent,
                  child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                if (!last) Expanded(child: Container(width: 1, color: AppColors.hairline)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(title, style: AppTypography.headline),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentTint : AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent ? AppColors.accent : AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent ? AppColors.accent : AppColors.inkSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.footnote.copyWith(color: accent ? AppColors.accentDeep : AppColors.inkSecondary)),
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
    final scorePercent = (course.sentimentScore * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: AspectRatio(aspectRatio: 16 / 9, child: _courseImage(course, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 12),
            Text(course.title, style: AppTypography.headline),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                Text('♥ 감성 $scorePercent%', style: AppTypography.footnote.copyWith(color: AppColors.accentDeep)),
                Text('◷ ${course.durationLabel}', style: AppTypography.footnote),
              ],
            ),
            const SizedBox(height: 8),
            Text(course.description, style: AppTypography.subhead),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({required double radius}) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7)),
      ],
    );
