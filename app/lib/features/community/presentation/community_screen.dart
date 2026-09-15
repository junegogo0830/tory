import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/feature_shortcut_tile.dart';
import '../../../shared/widgets/neighbors_greeting_illustration.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../../shared/widgets/region_select_sheet.dart';
import '../../../shared/widgets/yetgil_mark.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/kakao_login_error.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';
import 'region_join_sheet.dart';
import 'school_search_sheet.dart';
import 'widgets/trade_status_chip.dart';

/// 커뮤니티 탭. 지역구를 하나 골라 그 지역 커뮤니티(자유/추억/주민/관광정보 4개
/// 게시판)로 들어가는 구조 — 각 지역구가 별도로 운영되는 독립된 게시판 묶음이다.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  bool _enteredAsGuest = false;
  String? _guestRegion;

  Future<void> _pickRegionAsGuest() async {
    final selected = await showRegionSelectSheet(
      context,
      prompt: '어느 지역 커뮤니티로 갈까요?',
    );
    if (selected != null && mounted) setState(() => _guestRegion = selected);
  }

  void _findNeighbors() => context.push('/friends/find');

  Future<void> _pickSchool() async {
    final schoolRegion = await showSchoolSearchSheet(context);
    if (schoolRegion == null || !mounted) return;
    context.push('/school-community/${Uri.encodeComponent(schoolRegion)}');
  }

  Future<void> _pickRegionAsMember() async {
    final selected = await showRegionSelectSheet(
      context,
      prompt: '어느 지역 커뮤니티로 갈까요?',
    );
    if (selected == null || !mounted) return;
    await _switchOrJoinRegion(selected);
  }

  /// 이미 가입한 지역이면 확인 없이 바로 전환하고, 처음 가입하는 지역이면
  /// 가입 확인 화면(규모 통계 포함)을 먼저 보여준다.
  Future<void> _switchOrJoinRegion(String region) async {
    final myRegions = await ref.read(myRegionsProvider.future);
    if (!mounted) return;
    if (myRegions.contains(region)) {
      await ref.read(communityRepositoryProvider).setHomeRegion(region);
    } else {
      final joined = await showRegionJoinConfirmSheet(context, region: region);
      if (!joined) return;
    }
    if (!mounted) return;
    ref.invalidate(profileProvider);
    ref.invalidate(myRegionsProvider);
  }

  /// 지역 토글에서 이미 가입한 동네를 탭했을 때 — 확인 없이 바로 전환한다.
  Future<void> _directSwitchRegion(String region) async {
    await ref.read(communityRepositoryProvider).setHomeRegion(region);
    if (!mounted) return;
    ref.invalidate(profileProvider);
  }

  Widget _buildAuthDependentSection(bool isLoggedIn) {
    if (isLoggedIn) {
      return _MemberSection(onChangeRegion: _pickRegionAsMember, onSwitchRegion: _directSwitchRegion);
    }
    if (!_enteredAsGuest) {
      return _LoginOrGuestCard(onGuest: () => setState(() => _enteredAsGuest = true));
    }
    if (_guestRegion == null) {
      return _RegionPromptCard(onPick: _pickRegionAsGuest);
    }
    return _RegionBoardsSection(region: _guestRegion!, onChangeRegion: _pickRegionAsGuest, onSwitchRegion: null);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              children: [
                Text('커뮤니티', style: AppTypography.title.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  '동네 사람들과 그때 그 시절을 나눠보세요',
                  style: AppTypography.subhead,
                ),
                const SizedBox(height: 20),
                // 친구 찾기 · 모교 커뮤니티 · 둘러보기 · 코스 커스텀 2x2 그리드.
                Row(
                  children: [
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.people_outline,
                        label: '친구 찾기',
                        subtitle: '동네 친구를 찾아요',
                        badgeColor: AppColors.pastelLavender,
                        onTap: _findNeighbors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.school_outlined,
                        label: '모교 커뮤니티',
                        subtitle: '같은 학교, 같은 추억',
                        badgeColor: AppColors.pastelRose,
                        onTap: _pickSchool,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.explore_outlined,
                        label: '둘러보기',
                        subtitle: '다른 동네도 구경해요',
                        badgeColor: AppColors.pastelSky,
                        onTap: () => context.push('/course'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.route_outlined,
                        label: '코스 커스텀',
                        subtitle: '나만의 코스를 만들어요',
                        badgeColor: AppColors.pastelMint,
                        onTap: () => context.push('/custom-courses'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                authAsync.when(
                  data: _buildAuthDependentSection,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  // 로그인 시도가 실패해도(예: 웹에서 카카오 로그인 자체가 막힌 경우)
                  // 로그인 안 된 상태와 같게 취급한다 — 여기서 무조건 로그인 카드로
                  // 되돌리면 "게스트로 입장"을 눌러도 그 상태가 반영되지 않는다.
                  error: (_, _) => _buildAuthDependentSection(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카카오 로그인 배너 + "게스트로 입장" — 비회원도 커뮤니티를 구경할 수 있게 한다.
class _LoginOrGuestCard extends ConsumerWidget {
  const _LoginOrGuestCard({required this.onGuest});

  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        children: [
          const NeighborsGreetingIllustration(),
          const SizedBox(height: 14),
          Text(
            '로그인하고 내 동네 커뮤니티에 가입해보세요',
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '아이디로 가입하거나 카카오 계정으로 간편하게 시작할 수 있어요',
            style: AppTypography.subhead,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('아이디로 로그인'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).loginWithKakao();
                if (!context.mounted) return;
                final authState = ref.read(authStateProvider);
                if (authState.value != true && authState.hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(describeKakaoLoginError(authState.error))),
                  );
                }
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text('카카오로 시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: onGuest, child: const Text('게스트로 입장')),
          ),
        ],
      ),
    );
  }
}

class _RegionPromptCard extends StatelessWidget {
  const _RegionPromptCard({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_city_outlined,
              color: AppColors.accentDeep,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '어느 지역 커뮤니티로 갈까요?',
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '지역구를 고르면 그 동네 게시판으로 이동해요',
            style: AppTypography.subhead,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.location_searching),
              label: const Text('지역 선택하기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 로그인 사용자용 — 내 동네(home_region)가 없으면 먼저 고르게 하고, 있으면
/// 바로 게시판 목록을 보여준다.
class _MemberSection extends ConsumerWidget {
  const _MemberSection({required this.onChangeRegion, required this.onSwitchRegion});

  final VoidCallback onChangeRegion;
  final ValueChanged<String> onSwitchRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      data: (profile) {
        final region = profile.homeRegion;
        if (region == null) return _RegionPromptCard(onPick: onChangeRegion);
        return _RegionBoardsSection(
          region: region,
          onChangeRegion: onChangeRegion,
          onSwitchRegion: onSwitchRegion,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, _) => Text('프로필을 불러오지 못했어요', style: AppTypography.subhead),
    );
  }
}

/// 지역 배너(현재 지역 + 전환 버튼) + 게시판 목록 + (회원이면) 가입한 동네
/// 토글. "각 지역구별로 커뮤니티가 별도로 운영되는" 구조를 그대로 드러내는
/// 커뮤니티 탭의 본체. 게시판은 한 카드 안에 줄 단위로 늘어놓고, 각 줄에 그
/// 게시판의 최신 글 미리보기를 보여준다.
class _RegionBoardsSection extends ConsumerWidget {
  const _RegionBoardsSection({
    required this.region,
    required this.onChangeRegion,
    required this.onSwitchRegion,
  });

  final String region;
  final VoidCallback onChangeRegion;
  // null이면(게스트) 토글을 아예 안 보여준다 — 가입 이력은 로그인 사용자만 있다.
  final ValueChanged<String>? onSwitchRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.tile,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.accentDeep,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shortRegionLabel(region),
                  style: AppTypography.headline,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onChangeRegion,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('동네 추가·전환'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _YetgilBoardCard(),
        const SizedBox(height: 20),
        Text('게시판', style: AppTypography.sectionTitle),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.tile,
          ),
          child: Column(
            children: [
              for (var i = 0; i < communityBoards.length; i++) ...[
                _BoardRow(region: region, board: communityBoards[i]),
                if (i != communityBoards.length - 1)
                  Divider(
                    height: 1,
                    color: AppColors.hairline,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
        if (onSwitchRegion != null) ...[
          const SizedBox(height: 22),
          Text('내가 가입한 동네', style: AppTypography.sectionTitle),
          const SizedBox(height: 10),
          _RegionToggleRow(currentRegion: region, onSwitch: onSwitchRegion!, onAddNew: onChangeRegion),
        ],
        const SizedBox(height: 28),
        Text(
          '분란 조장, 허위 정보, 광고성 게시글은 신고 누적 시 자동으로 숨겨져요.\n'
          '서로 예의를 지키며 따뜻한 동네 커뮤니티를 만들어가요.',
          style: AppTypography.caption.copyWith(color: AppColors.inkTertiary, height: 1.5),
        ),
      ],
    );
  }
}

/// 로그인 사용자가 가입한 모든 동네를 칩으로 보여주는 토글 — 이미 가입한
/// 동네끼리는 확인 없이 바로 전환되고, "+"로 새 동네를 추가(가입)할 수 있다.
class _RegionToggleRow extends ConsumerWidget {
  const _RegionToggleRow({required this.currentRegion, required this.onSwitch, required this.onAddNew});

  final String currentRegion;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(myRegionsProvider);
    return regionsAsync.when(
      data: (regions) => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final r in regions) ...[
              ChoiceChip(
                label: Text(shortRegionLabel(r)),
                selected: r == currentRegion,
                onSelected: (_) => r == currentRegion ? null : onSwitch(r),
                showCheckmark: false,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: r == currentRegion ? AppColors.accent : AppColors.hairline),
                shape: const StadiumBorder(),
                labelStyle: AppTypography.footnote.copyWith(
                  color: r == currentRegion ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              const SizedBox(width: 8),
            ],
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: AppColors.accentDeep),
              label: const Text('동네 추가'),
              onPressed: onAddNew,
              backgroundColor: AppColors.paper,
              side: BorderSide(color: AppColors.hairline),
              shape: const StadiumBorder(),
              labelStyle: AppTypography.footnote.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 38),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// "경기도 수원시" → "경기 수원시"처럼 앞쪽 시/도 이름의 행정구역 접미사만
/// 줄여 짧게 보여준다. 긴 접미사(특별자치시/특별자치도)부터 확인해야 "강원특별
/// 자치도"가 "강원특별자치"로 잘못 잘리지 않는다.
String shortRegionLabel(String region) {
  const suffixes = ['특별자치시', '특별자치도', '광역시', '특별시', '도'];
  for (final suffix in suffixes) {
    final index = region.indexOf(suffix);
    if (index > 0) {
      return (region.substring(0, index) +
              region.substring(index + suffix.length))
          .trim();
    }
  }
  return region;
}

/// 게시판 한 줄 — 이름·설명·아이콘에 더해 최신 글 미리보기(제목+썸네일)까지
/// 보여줘서 탭하기 전에도 그 게시판이 지금 어떤 분위기인지 느낄 수 있게 한다.
/// 주민 게시판은 최신 글의 가격/거래상태 배지를 함께 보여줘 "중고거래 게시판"
/// 이라는 성격이 목록에서부터 드러난다.
class _BoardRow extends ConsumerWidget {
  const _BoardRow({required this.region, required this.board});

  final String region;
  final CommunityBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(
      communityFeedProvider((region: region, board: board.id)),
    );
    final posts = feedAsync.value;
    final latest = (posts != null && posts.isNotEmpty) ? posts.first : null;
    final preview = latest?.title ?? latest?.caption;

    return InkWell(
      onTap: () =>
          context.push('/community/${Uri.encodeComponent(region)}/${board.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: board.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(board.icon, color: AppColors.accentDeep, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        board.label,
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(width: 6),
                      if (latest != null)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFFE0533D), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    board.description,
                    style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (board.isTradeBoard && latest?.tradeStatus != null) ...[
                        TradeStatusChip(status: latest!.tradeStatus!),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          preview ?? '아직 올라온 글이 없어요 · 첫 글을 남겨보세요',
                          style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (board.isTradeBoard && latest?.price != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${formatPrice(latest!.price!)}원',
                      style: AppTypography.footnote.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            if (latest?.photoUrl != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: AppNetworkImage(
                    imageUrl: latest!.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const PhotoFallback(),
                    errorWidget: (_, _, _) => const PhotoFallback(),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right, size: 18, color: AppColors.inkTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 일반 게시판(자유/추억/주민/관광정보/타임캡슐)과 다르게 동작하는 특별
/// 카드 — 누르면 글 목록으로 바로 가는 대신 "코스 공유/코스 둘러보기"를
/// 고르는 팝업을 띄운다. 기존 "코스 커스텀"(내가 만든 코스, 추천/비추천·댓글)
/// 인프라를 그대로 재사용하되, 커뮤니티 탭에서 바로 들어오는 입구를 하나
/// 더 만드는 셈이다.
class _YetgilBoardCard extends ConsumerWidget {
  const _YetgilBoardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showYetgilBoardChoice(context, ref),
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.featureTint,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: AppColors.featureBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              // 홈 화면은 워드마크(글자)를 쓰도록 바뀌어서, 여기는 반대로
              // 아이콘 로고를 쓴다(서로 자리를 바꿨다).
              child: const YetgilMark(size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '옛길 게시판',
                    style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '나의 추억을 만들어줬던 코스를 많은 사람들과 나눠요',
                    style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.accentDeep),
          ],
        ),
      ),
    );
  }
}

void _showYetgilBoardChoice(BuildContext context, WidgetRef ref) {
  // 팝업 버튼에서 다이얼로그를 pop()한 다음 "그 다이얼로그 자신의" context로
  // 곧바로 context.push/go를 부르면, 그 context는 이미 제거되고 있는 위젯의
  // 것이라 라우팅이 씹히거나(에러 없이 조용히 실패) 이상한 화면에 남는 문제가
  // 있었다 — 커뮤니티 화면 자체의 context(다이얼로그 밑에 계속 살아있는 위젯)를
  // 미리 붙잡아두고, pop 이후 네비게이션은 전부 이 context로만 한다.
  final screenContext = context;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('어떤 항목으로 이동하시겠어요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!screenContext.mounted) return;
                final isLoggedIn = ref.read(authStateProvider).value ?? false;
                if (!isLoggedIn) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(content: Text('코스를 공유하려면 먼저 로그인해주세요')),
                  );
                  screenContext.go('/profile');
                  return;
                }
                screenContext.push('/custom-courses/create');
              },
              icon: const Icon(Icons.add_road),
              label: const Text('코스 공유'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!screenContext.mounted) return;
                screenContext.push('/custom-courses');
              },
              icon: const Icon(Icons.explore_outlined),
              label: const Text('코스 둘러보기'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('닫기')),
      ],
    ),
  );
}

