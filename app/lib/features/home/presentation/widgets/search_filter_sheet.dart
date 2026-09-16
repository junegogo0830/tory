import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// 홈 검색창 필터 — TourAPI contentTypeId 기준 카테고리. null이면 필터 없음
/// (주소/학교/아파트까지 포함하는 기존 통합 검색을 그대로 쓴다). 값이 있으면
/// 등록 관광지 중 그 카테고리만 검색한다(백엔드 `/api/location/tour-search`).
class SearchCategoryOption {
  const SearchCategoryOption(this.id, this.label, this.icon);
  final String? id;
  final String label;
  final IconData icon;
}

const List<SearchCategoryOption> searchCategoryOptions = [
  SearchCategoryOption(null, '전체', Icons.search),
  SearchCategoryOption('12', '관광지', Icons.landscape_outlined),
  SearchCategoryOption('14', '문화시설', Icons.museum_outlined),
  SearchCategoryOption('39', '음식점', Icons.restaurant_outlined),
  SearchCategoryOption('28', '레포츠', Icons.hiking_outlined),
  SearchCategoryOption('32', '숙박', Icons.hotel_outlined),
  SearchCategoryOption('38', '쇼핑', Icons.shopping_bag_outlined),
];

/// 현재 선택된 카테고리(id, null이면 "전체")를 넘기면 새로 고른 카테고리 id를
/// 반환한다(취소하면 null이 아니라 아예 값 없이 닫힘 — Navigator.pop()).
Future<String?> showSearchFilterSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => _SearchFilterContent(current: current),
  );
}

class _SearchFilterContent extends StatelessWidget {
  const _SearchFilterContent({required this.current});

  final String? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('검색 카테고리', style: AppTypography.headline),
            const SizedBox(height: 4),
            Text(
              '고른 카테고리에 등록된 실제 관광지만 검색해요.',
              style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in searchCategoryOptions)
                  _CategoryChip(
                    option: option,
                    selected: option.id == current,
                    onTap: () => Navigator.of(context).pop(option.id ?? ''),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.option, required this.selected, required this.onTap});

  final SearchCategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTint : AppColors.fieldBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 16, color: selected ? AppColors.accentDeep : AppColors.inkSecondary),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: AppTypography.subhead.copyWith(
                color: selected ? AppColors.accentDeep : AppColors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
