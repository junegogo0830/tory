import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/yetgil_mark.dart';
import 'search_filter_sheet.dart';
import 'top_attractions_ticker.dart';

/// 홈 상단 기능 헤더 — 로고/타이틀, 프로필, 검색, HOT 지역을 실제 GUI
/// control처럼 쌓아 보여준다. 검색창 힌트 텍스트는 시간대 기반 인사말이다
/// (예전엔 GPS로 날씨까지 반영했었는데, 화면 어디에도 날씨 자체를 보여주는
/// 곳이 없어서 굳이 위치 권한을 요구할 이유가 없었다 — 인사말 문구는
/// 시간대만으로도 충분히 자연스럽다).
class WeatherTopBanner extends ConsumerWidget {
  const WeatherTopBanner({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.categoryFilter,
    required this.onCategoryFilterChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 홈 화면은 로고 아이콘 대신 워드마크(글자) 이미지를 쓴다 — 아이콘은
              // 옛길 게시판 카드 쪽으로 옮겼다(둘이 서로 자리를 바꿨다).
              const YetgilWordmark(fontSize: 22),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: AppColors.border),
              const SizedBox(width: 10),
              // 뷰포트가 아주 좁아질 때(개발자도구 패널로 창이 눌리는 순간 등)
              // 이 Row 전체가 넘치지 않도록 태그라인을 줄어들 수 있게 한다.
              // (Flexible+Spacer를 함께 쓰면 둘 다 flex:1이라 남는 공간을 반씩
              // "예약"만 하고 Text가 그 절반을 다 안 쓰면 그만큼이 통째로
              // 버려져 프로필 버튼이 오른쪽 끝까지 안 밀리는 버그였다 — Expanded
              // 하나로 합쳐 남는 공간 전부가 프로필 버튼 앞까지 온전히 가게 한다.)
              Expanded(
                child: Text(
                  '걷는 만큼,\n더 가까워지는 이야기',
                  style: AppTypography.caption.copyWith(color: AppColors.inkSecondary, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const _ProfileButton(),
            ],
          ),
          const SizedBox(height: 12),
          _SearchField(
            controller: controller,
            onSubmitted: onSubmitted,
            hintText: _greetingFor(DateTime.now()),
            categoryFilter: categoryFilter,
            onCategoryFilterChanged: onCategoryFilterChanged,
          ),
          const SizedBox(height: 10),
          const HotTicker(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.hintText,
    required this.categoryFilter,
    required this.onCategoryFilterChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String hintText;
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryFilterChanged;

  Future<void> _openFilterSheet(BuildContext context) async {
    final picked = await showSearchFilterSheet(context, current: categoryFilter);
    if (picked == null) return; // 취소 — 기존 필터 유지
    onCategoryFilterChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = categoryFilter != null;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      style: AppTypography.subhead.copyWith(color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: AppTypography.subhead.copyWith(color: AppColors.inkTertiary),
        hintMaxLines: 1,
        prefixIcon: Icon(Icons.search, color: AppColors.inkSecondary, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: IconButton(
          icon: Icon(
            hasFilter ? Icons.tune : Icons.tune_outlined,
            color: hasFilter ? AppColors.accent : AppColors.inkSecondary,
            size: 20,
          ),
          tooltip: hasFilter
              ? searchCategoryOptions.firstWhere((o) => o.id == categoryFilter).label
              : '검색 필터',
          onPressed: () => _openFilterSheet(context),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        // 검색창만 배경(fieldBg)과 다른 흰색으로 — 헤더 배경에 묻히지 않고
        // 도드라지게. 다른 텍스트필드는 그대로 테마 기본값(fieldBg)을 쓴다.
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/profile'),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: AppColors.iconChipBg, shape: BoxShape.circle),
        child: const Icon(Icons.person, color: AppColors.iconChipFg, size: 19),
      ),
    );
  }
}

/// 시간대로 "선선한 오후예요, 어디로 떠나볼까요?" 같은 인사말을 만든다.
String _greetingFor(DateTime now) {
  final hour = now.hour;
  final String timeOfDay;
  if (hour < 6) {
    timeOfDay = '새벽';
  } else if (hour < 11) {
    timeOfDay = '아침';
  } else if (hour < 14) {
    timeOfDay = '점심';
  } else if (hour < 18) {
    timeOfDay = '오후';
  } else if (hour < 21) {
    timeOfDay = '저녁';
  } else {
    timeOfDay = '밤';
  }

  // "밤예요"(X) / "밤이에요"(O) — 받침 있는 음절 뒤엔 "이에요", 없으면 "예요".
  final copula = _hasFinalConsonant(timeOfDay) ? '이에요' : '예요';
  return '$timeOfDay$copula, 어디로 떠나볼까요?';
}

/// 한글 완성형 음절(가~힣)의 마지막 글자에 받침이 있는지 본다.
/// 유니코드 한글 음절 블록은 (코드 - 0xAC00) % 28 == 0이면 받침이 없다.
bool _hasFinalConsonant(String word) {
  if (word.isEmpty) return false;
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}
