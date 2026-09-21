import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/restaurant_candidate.dart';
import '../../../../data/models/tour_course.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import 'meal_preference_sheet.dart';

const Map<String, String> _mealTypeLabels = {'breakfast': '아침', 'lunch': '점심', 'dinner': '저녁'};

/// 식사 조건 선택 다음 단계 — 식사 시간대별 실제 식당 후보를 보여주고, 사용자가
/// 하나씩 고르면 "코스에 반영"으로 실제 코스에 삽입한다. 반영에 성공하면
/// 업데이트된 [TourCourse]를 반환하고, 취소/실패하면 null을 반환한다.
Future<TourCourse?> showMealCandidateSheet(
  BuildContext context, {
  required TourCourse course,
  required MealPreference preference,
}) {
  return showModalBottomSheet<TourCourse>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
    builder: (context) => _MealCandidateSheetBody(course: course, preference: preference),
  );
}

class _MealCandidateSheetBody extends ConsumerStatefulWidget {
  const _MealCandidateSheetBody({required this.course, required this.preference});

  final TourCourse course;
  final MealPreference preference;

  @override
  ConsumerState<_MealCandidateSheetBody> createState() => _MealCandidateSheetBodyState();
}

class _MealCandidateSheetBodyState extends ConsumerState<_MealCandidateSheetBody> {
  Map<String, List<RestaurantCandidate>>? _candidates;
  String? _error;
  bool _submitting = false;
  final Map<String, RestaurantCandidate> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final candidates = await ref.read(courseRepositoryProvider).getMealCandidates(
            widget.course,
            mealTypes: widget.preference.mealTypes,
            foodCategories: widget.preference.foodCategories,
            priceRange: widget.preference.priceRange,
            ageGroup: widget.preference.ageGroup,
          );
      if (mounted) setState(() => _candidates = candidates);
    } catch (_) {
      if (mounted) setState(() => _error = '식당을 찾지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 시간대마다 직접 하나씩 고르지 않고, 각 시간대의 1순위 추천으로 한 번에 채운다.
  void _fillWithTopPicks() {
    final candidates = _candidates;
    if (candidates == null) return;
    setState(() {
      for (final mealType in widget.preference.mealTypes) {
        final pool = candidates[mealType];
        if (pool != null && pool.isNotEmpty) _selected[mealType] = pool.first;
      }
    });
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      // 이번에 고르지 않은 식사 시간대(예: 점심만 바꾸는 중인데 이미 있던 아침)는
      // 기존 코스의 정류지에서 그대로 복원해 같이 보낸다 — insertMeals는 요청에
      // 실린 meals로 기존 식사를 통째로 교체하기 때문에, 빠뜨리면 사라진다.
      final untouched = widget.course.stops.where(
        (s) => s.isMeal && s.mealType != null && !widget.preference.mealTypes.contains(s.mealType),
      );
      final meals = [
        for (final stop in untouched) (mealType: stop.mealType!, restaurant: RestaurantCandidate.fromCourseStop(stop)),
        for (final entry in _selected.entries) (mealType: entry.key, restaurant: entry.value),
      ];
      final updated = await ref.read(courseRepositoryProvider).insertMeals(widget.course, meals);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('코스에 반영하지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('식당을 골라주세요', style: AppTypography.title),
                        const SizedBox(height: 4),
                        Text('식사 시간마다 하나씩 선택할 수 있어요', style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
                      ],
                    ),
                  ),
                  if (_candidates != null)
                    TextButton(
                      onPressed: _fillWithTopPicks,
                      child: const Text('한 번에 채우기'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(scrollController)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty || _submitting ? null : _confirm,
                      child: _submitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('코스에 반영'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_error != null) {
      return Center(child: Text(_error!, style: AppTypography.subhead));
    }
    final candidates = _candidates;
    if (candidates == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return ListView(
      controller: scrollController,
      children: [
        for (final mealType in widget.preference.mealTypes) ...[
          Text(
            '${_mealTypeLabels[mealType] ?? mealType} 식당 추천',
            style: AppTypography.headline,
          ),
          const SizedBox(height: 10),
          if ((candidates[mealType] ?? const []).isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('이 코스 주변에서 추천할 만한 식당을 찾지 못했어요.', style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary)),
            )
          else ...[
            for (final candidate in candidates[mealType]!)
              _RestaurantCard(
                candidate: candidate,
                selected: identical(_selected[mealType], candidate),
                onTap: () => setState(() {
                  if (identical(_selected[mealType], candidate)) {
                    _selected.remove(mealType);
                  } else {
                    _selected[mealType] = candidate;
                  }
                }),
              ),
            const SizedBox(height: 20),
          ],
        ],
      ],
    );
  }
}

/// 식당 후보 카드 — 사진을 크게 보여줘서 실제로 어떤 곳인지 한눈에 알아볼 수
/// 있게 한다(기존엔 52x52 작은 썸네일이라 거의 안 보였다는 피드백을 반영).
class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.candidate, required this.selected, required this.onTap});

  final RestaurantCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      candidate.imageUrl == null
                          ? const PhotoFallback()
                          : AppNetworkImage(
                              imageUrl: candidate.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const PhotoFallback(),
                              errorWidget: (_, _, _) => const PhotoFallback(),
                            ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selected ? Icons.check : Icons.radio_button_unchecked,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.name, style: AppTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (candidate.reason != null) ...[
                      const SizedBox(height: 3),
                      Text(candidate.reason!, style: AppTypography.footnote.copyWith(color: AppColors.accentDeep), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ] else if (candidate.category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(candidate.category, style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
