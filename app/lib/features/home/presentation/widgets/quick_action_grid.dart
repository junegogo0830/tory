import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_providers.dart';

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext context, WidgetRef ref) onTap;
}

/// GPS 없이 들어간다 — 화면(NearbyMapScreen) 안에서 장소를 직접 검색해서 고른다.
void _openNearbyMap(BuildContext context, WidgetRef ref) {
  context.push('/nearby-map');
}

/// "코스 등록"/"친구 찾기"처럼 로그인이 있어야 의미 있는 액션 공용 처리 —
/// custom_course_list_screen.dart의 로그인 체크와 같은 패턴.
void _requireLogin(BuildContext context, WidgetRef ref, String message, void Function() ifLoggedIn) {
  final isLoggedIn = ref.read(authStateProvider).value ?? false;
  if (!isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.go('/profile');
    return;
  }
  ifLoggedIn();
}

final List<_QuickAction> _quickActions = [
  _QuickAction(
    icon: Icons.route_outlined,
    label: '추천 코스',
    color: AppColors.pastelMint,
    onTap: (context, ref) => context.go('/course'),
  ),
  _QuickAction(
    icon: Icons.explore_outlined,
    label: '둘러보기',
    color: AppColors.pastelSky,
    onTap: (context, ref) => context.push('/explore'),
  ),
  _QuickAction(
    icon: Icons.near_me_outlined,
    label: '내 주변',
    color: AppColors.pastelPeach,
    onTap: _openNearbyMap,
  ),
  _QuickAction(
    icon: Icons.groups_outlined,
    label: '커뮤니티',
    color: AppColors.pastelLavender,
    onTap: (context, ref) => context.go('/community'),
  ),
  _QuickAction(
    icon: Icons.restaurant_outlined,
    label: '맛집 추천',
    color: AppColors.pastelButter,
    onTap: (context, ref) => context.push('/kakao-restaurants'),
  ),
  _QuickAction(
    icon: Icons.person_outline,
    label: '프로필',
    color: AppColors.accentTint,
    onTap: (context, ref) => context.go('/profile'),
  ),
  _QuickAction(
    icon: Icons.person_add_alt_outlined,
    label: '친구 찾기',
    color: AppColors.pastelRose,
    onTap: (context, ref) =>
        _requireLogin(context, ref, '친구 찾기를 하려면 먼저 로그인해주세요', () => context.push('/friends/find')),
  ),
  _QuickAction(
    icon: Icons.post_add_outlined,
    label: '코스 등록',
    color: AppColors.pastelMint,
    onTap: (context, ref) =>
        _requireLogin(context, ref, '코스를 만들려면 먼저 로그인해주세요', () => context.push('/custom-courses/create')),
  ),
];

/// 홈 화면 바로가기 카드 그리드 — 4열x2행, 타일 전체가 카테고리별 파스텔
/// 색으로 채워진 카드 형태(아이콘 배지가 아니라 카드 자체가 색을 입는다).
class QuickActionGrid extends ConsumerWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('지금, 무엇을 해볼까요?', style: AppTypography.sectionTitle),
            const SizedBox(width: 8),
            // 좁은 화면에서 부제가 밀려 Row 전체가 넘치지 않도록, 남는 공간
            // 안에서만 오른쪽 정렬 + 말줄임되게 한다(Spacer로 고정폭 텍스트
            // 둘을 나란히 두면 폭이 부족할 때 그대로 오버플로우한다).
            Expanded(
              child: Text(
                '여행이 더 특별해지는 다양한 방법',
                style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 목업처럼 화면 좌우 기본 여백만 유지하고(추가 인셋 없이), 원형
        // 아이콘 배지 + 아래 라벨 형태로 4열 x 2행 — 카드 배경/테두리 없이
        // 아이콘 배지 자체만 파스텔 색으로 채운다.
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 6,
          childAspectRatio: 1.05,
          children: [for (final action in _quickActions) _QuickActionTile(action: action)],
        ),
      ],
    );
  }
}

class _QuickActionTile extends ConsumerWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => action.onTap(context, ref),
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: action.color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(action.icon, color: AppColors.accentDeep, size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            action.label,
            style: AppTypography.caption.copyWith(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
