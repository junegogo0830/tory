import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// 지역 맛집 카테고리 토글(전체/한식/중식/일식/양식/디저트) — 홈 카드와
/// "전체보기" 화면이 같이 쓴다. `selected == null`이면 "전체".
class RestaurantCuisineFilter extends StatelessWidget {
  const RestaurantCuisineFilter({super.key, required this.selected, required this.onSelect});

  static const List<String> cuisines = ['한식', '중식', '일식', '양식', '디저트'];

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cuisines.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final label = i == 0 ? '전체' : cuisines[i - 1];
          final value = i == 0 ? null : cuisines[i - 1];
          final isSelected = selected == value;
          return InkWell(
            onTap: () => onSelect(value),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? AppColors.surface : AppColors.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
