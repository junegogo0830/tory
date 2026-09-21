import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

const List<({String value, String label})> mealTimeOptions = [
  (value: 'breakfast', label: '아침'),
  (value: 'lunch', label: '점심'),
  (value: 'dinner', label: '저녁'),
];

// 카카오맵/TourAPI가 실제로 쓰는 음식점 카테고리에 맞춘 목록(홈 화면 "카카오맵
// 맛집 추천" 카테고리 토글과 동일한 분류) — 백엔드 meal_planner.py의 키워드
// 매칭도 이 라벨을 그대로 쓴다.
const List<String> foodCategoryOptions = ['한식', '중식', '일식', '양식', '분식', '카페/디저트', '상관없음'];

const List<String> priceRangeOptions = ['가성비', '보통', '여유롭게', '상관없음'];

const List<String> mealAgeGroupOptions = ['10대', '20대', '30대', '40대', '50대', '60대 이상', '상관없음'];

typedef MealPreference = ({
  List<String> mealTypes,
  List<String> foodCategories,
  String? priceRange,
  String? ageGroup,
});

/// "식사를 추가하시겠어요?" 바텀시트 — 언제/무엇을/가격대/연령대를 칩으로
/// 고른다. "식당 찾아보기"를 누르면 선택값을 반환하고, 실제 후보 조회는
/// 호출부(course_detail_screen.dart)가 이어서 처리한다.
Future<MealPreference?> showMealPreferenceSheet(BuildContext context) {
  return showModalBottomSheet<MealPreference>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
    builder: (context) => const _MealPreferenceSheetBody(),
  );
}

class _MealPreferenceSheetBody extends StatefulWidget {
  const _MealPreferenceSheetBody();

  @override
  State<_MealPreferenceSheetBody> createState() => _MealPreferenceSheetBodyState();
}

class _MealPreferenceSheetBodyState extends State<_MealPreferenceSheetBody> {
  final Set<String> _mealTypes = {};
  final Set<String> _foodCategories = {};
  String? _priceRange;
  String? _ageGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('식사를 추가해볼까요?', style: AppTypography.title),
            const SizedBox(height: 4),
            Text('여행 중 먹고 싶은 식사를 골라주세요', style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
            const SizedBox(height: 20),
            Text('언제 식사하시나요?', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in mealTimeOptions)
                  _Chip(
                    label: option.label,
                    selected: _mealTypes.contains(option.value),
                    onTap: () => setState(() {
                      if (!_mealTypes.remove(option.value)) _mealTypes.add(option.value);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('어떤 음식이 좋으세요?', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('여러 개 선택해도 좋아요', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in foodCategoryOptions)
                  _Chip(
                    label: option,
                    selected: _foodCategories.contains(option),
                    onTap: () => setState(() {
                      if (!_foodCategories.remove(option)) _foodCategories.add(option);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('가격대', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in priceRangeOptions)
                  _Chip(
                    label: option,
                    selected: _priceRange == option,
                    onTap: () => setState(() => _priceRange = _priceRange == option ? null : option),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('연령대', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in mealAgeGroupOptions)
                  _Chip(
                    label: option,
                    selected: _ageGroup == option,
                    onTap: () => setState(() => _ageGroup = _ageGroup == option ? null : option),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _mealTypes.isEmpty
                    ? null
                    : () => Navigator.of(context).pop((
                          mealTypes: _mealTypes.toList(),
                          foodCategories: _foodCategories.toList(),
                          priceRange: _priceRange,
                          ageGroup: _ageGroup,
                        )),
                child: const Text('식당 찾아보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.fieldBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
