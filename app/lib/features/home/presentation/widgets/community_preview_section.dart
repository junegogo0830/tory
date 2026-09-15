import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/card_fade_art.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../community/data/community_providers.dart';
import '../../../community/domain/community_board.dart';
import '../../../profile/data/profile_providers.dart';
import '../../../../data/models/community_post.dart';

/// 홈 화면 "우리 동네 최신 이야기" — 게시판(자유/추억/주민/관광정보)을 가리지
/// 않고 내 동네에서 최근에 올라온 글을 커뮤니티 피드처럼 미리 보여준다.
/// 옛길의 핵심이 커뮤니티라는 걸 홈 화면에서부터 드러내는 게 목적이라, 단순
/// 사진 나열이 아니라 작성자·게시판·시간까지 보이는 실제 피드 카드로 구성했다.
class CommunityPreviewSection extends ConsumerWidget {
  const CommunityPreviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isLoggedIn = authAsync.value ?? false;

    if (!isLoggedIn) return const _JoinPromptCard();

    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      data: (profile) {
        final region = profile.homeRegion;
        if (region == null) return const _JoinPromptCard();

        final storiesAsync = ref.watch(communityLatestStoriesProvider(region));
        return storiesAsync.when(
          data: (posts) {
            if (posts.isEmpty) return const _NoStoriesYetPromptCard();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: '우리 동네 최신 이야기',
                  actionLabel: '더보기',
                  onAction: () => context.go('/community'),
                ),
                const SizedBox(height: 10),
                // 글마다 카드를 따로 띄우면 같은 상자가 6개 반복돼 템플릿처럼
                // 보인다 — 흰 컨테이너 하나에 헤어라인으로 나눈 목록으로 묶는다.
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < posts.length; i++) ...[
                        _StoryRow(post: posts[i]),
                        if (i != posts.length - 1)
                          Divider(height: 1, indent: 56, endIndent: 14, color: AppColors.hairline),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final board = communityBoardById(post.board);
    return InkWell(
      onTap: () => context.push('/post/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: board.color, borderRadius: BorderRadius.circular(10)),
              child: Icon(board.icon, size: 16, color: AppColors.accentDeep),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title ?? post.caption ?? '(내용 없음)',
                    style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${board.label} · ${post.authorNickname} · ${_relativeTime(post.createdAt)}',
                    style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (post.photoUrl != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: AppNetworkImage(
                    imageUrl: post.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const PhotoFallback(),
                    errorWidget: (_, _, _) => const PhotoFallback(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${time.month}/${time.day}';
}

/// 내 동네는 있지만 4개 게시판(자유/추억/주민/관광정보)에 글이 하나도 없는
/// 상태 — 조용히 숨기면 "동네 설정했는데 또 사라졌다"는 인상을 준다.
class _NoStoriesYetPromptCard extends StatelessWidget {
  const _NoStoriesYetPromptCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '우리 동네 최신 이야기',
          actionLabel: '더보기',
          onAction: () => context.go('/community'),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => context.go('/community'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_note_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('아직 이 동네엔 이야기가 없어요', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('첫 이야기를 남기면 우리 동네가 채워져요', style: AppTypography.footnote),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ],
    );
  }
}

class _JoinPromptCard extends StatelessWidget {
  const _JoinPromptCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => context.go('/community'),
      child: Stack(
        children: [
          const CardFadeArt(imageAsset: 'assets/logo/community.png'),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 동네 커뮤니티에 가입해보세요', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('추억을 나누고 새 소식을 받아볼 수 있어요', style: AppTypography.footnote),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
