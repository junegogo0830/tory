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
import '../../../shared/widgets/region_select_sheet.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/kakao_login_error.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';

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

  Future<void> _findNeighbors() async {
    // 이미 내 동네가 있으면(로그인 상태) 바로 그 동네로, 없으면 지역을 골라서.
    final profile = ref.read(profileProvider).value;
    final region = profile?.homeRegion ?? _guestRegion ??
        await showRegionSelectSheet(context, prompt: '어느 동네 이웃을 찾아볼까요?');
    if (region == null || !mounted) return;
    context.push('/neighbors/${Uri.encodeComponent(region)}');
  }

  Future<void> _pickRegionAsMember() async {
    final selected = await showRegionSelectSheet(
      context,
      prompt: '어느 지역 커뮤니티로 갈까요?',
    );
    if (selected == null || !mounted) return;
    await ref.read(communityRepositoryProvider).setHomeRegion(selected);
    ref.invalidate(profileProvider);
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
                Text('커뮤니티', style: AppTypography.title),
                const SizedBox(height: 4),
                Text(
                  '동네 사람들과 그때 그 시절을 나눠보세요',
                  style: AppTypography.body.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.explore_outlined,
                        label: '둘러보기',
                        badgeColor: AppColors.pastelSky,
                        onTap: () => context.push('/explore'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.people_outline,
                        label: '친구 찾기',
                        badgeColor: AppColors.pastelLavender,
                        onTap: _findNeighbors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                authAsync.when(
                  data: (isLoggedIn) {
                    if (isLoggedIn) {
                      return _MemberSection(
                        onChangeRegion: _pickRegionAsMember,
                      );
                    }
                    if (!_enteredAsGuest) {
                      return _LoginOrGuestCard(
                        onGuest: () => setState(() => _enteredAsGuest = true),
                      );
                    }
                    if (_guestRegion == null) {
                      return _RegionPromptCard(onPick: _pickRegionAsGuest);
                    }
                    return _RegionBoardsSection(
                      region: _guestRegion!,
                      onChangeRegion: _pickRegionAsGuest,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (_, _) => _LoginOrGuestCard(
                    onGuest: () => setState(() => _enteredAsGuest = true),
                  ),
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
          Text(
            '로그인하고 내 동네 커뮤니티에 가입해보세요',
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '카카오 계정으로 간편하게 시작할 수 있어요',
            style: AppTypography.subhead,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).loginWithKakao();
                if (!context.mounted) return;
                final authState = ref.read(authStateProvider);
                if (authState.value != true) {
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
  const _MemberSection({required this.onChangeRegion});

  final VoidCallback onChangeRegion;

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

/// 지역 배너(현재 지역 + 전환 버튼) + 게시판 목록. "각 지역구별로 커뮤니티가
/// 별도로 운영되는" 구조를 그대로 드러내는 커뮤니티 탭의 본체. 게시판은 한
/// 카드 안에 줄 단위로 늘어놓고, 각 줄에 그 게시판의 최신 글 미리보기를 보여준다.
class _RegionBoardsSection extends StatelessWidget {
  const _RegionBoardsSection({
    required this.region,
    required this.onChangeRegion,
  });

  final String region;
  final VoidCallback onChangeRegion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
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
                label: const Text('지역 변경'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '게시판',
          style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
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
      ],
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

/// 즐겨찾는 게시판 목록 스타일의 한 줄 — 게시판 이름(고정폭) + 최신 글 미리보기
/// + 새 글이 있으면 빨간 N 배지, 없으면 화살표. 카드 자체가 화이트라 배지
/// 색만으로 게시판을 구분해 색감을 준다.
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: board.color,
                shape: BoxShape.circle,
              ),
              child: Icon(board.icon, color: AppColors.ink, size: 14),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 78,
              child: Text(
                board.label,
                style: AppTypography.subhead.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                preview ?? '아직 글이 없어요',
                style: AppTypography.footnote.copyWith(
                  color: AppColors.inkTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (latest != null)
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0533D),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.inkTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
