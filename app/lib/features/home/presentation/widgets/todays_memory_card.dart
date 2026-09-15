import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../community/data/community_providers.dart';
import '../../../profile/data/profile_providers.dart';

/// 홈 화면 "오늘의 추억" — 내 동네 추억 게시판에서 하루 동안 고정으로 보여줄
/// 글 하나를 뽑아 큼직하게 보여준다. "옛길" 컨셉(그 시절 향수)을 홈 화면에서
/// 가장 먼저 눈에 띄게 하려는 목적. 로그인/내 동네 설정이 안 됐으면 안내
/// 카드로 유도하고(community_preview_section.dart의 _JoinPromptCard와 같은
/// 패턴), 동네는 설정했지만 아직 추억 글이 하나도 없을 때만 조용히 숨긴다
/// (없는 걸 억지로 채울 순 없으니).
class TodaysMemoryCard extends ConsumerWidget {
  const TodaysMemoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isLoggedIn = authAsync.value ?? false;

    if (!isLoggedIn) return const _LoginPromptCard();

    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      data: (profile) {
        final region = profile.homeRegion;
        if (region == null) return const _SetRegionPromptCard();

        final memoryAsync = ref.watch(todaysMemoryProvider(region));
        return memoryAsync.when(
          data: (post) {
            if (post == null) return const _NoMemoryYetPromptCard();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘의 추억', style: AppTypography.sectionTitle),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => context.push('/post/${post.id}'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.card)),
                          child: SizedBox(
                            width: 104,
                            height: 104,
                            child: post.photoUrl == null
                                ? const PhotoFallback()
                                : AppNetworkImage(
                                    imageUrl: post.photoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => const PhotoFallback(),
                                    errorWidget: (_, _, _) => const PhotoFallback(),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (post.memoryYear != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.pastelPeach,
                                      borderRadius: BorderRadius.circular(AppRadius.tag),
                                    ),
                                    child: Text(
                                      '${post.memoryYear}년',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.accentDeep,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  post.title ?? post.caption ?? '(내용 없음)',
                                  style: AppTypography.headline.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (post.caption != null && post.title != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    post.caption!,
                                    style: AppTypography.footnote,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const Spacer(),
                                Text(post.authorNickname, style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// 내 동네는 설정했지만 그 동네 추억 게시판에 아직 글이 하나도 없는 상태 —
/// "지역 설정했는데 카드가 또 사라졌다"는 인상을 주지 않게, 조용히 숨기는 대신
/// 첫 글을 직접 남기도록 유도한다.
class _NoMemoryYetPromptCard extends StatelessWidget {
  const _NoMemoryYetPromptCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 추억', style: AppTypography.sectionTitle),
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
                  color: AppColors.pastelPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('아직 이 동네엔 추억이 없어요', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('첫 추억을 남기면 여기 가장 먼저 보여드려요', style: AppTypography.footnote),
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

/// 로그인은 했지만 "내 동네"를 아직 설정 안 한 상태 — 커뮤니티 탭에서 지역을
/// 고르면 그 순간부터 이 자리에 실제 추억이 뜬다.
class _SetRegionPromptCard extends StatelessWidget {
  const _SetRegionPromptCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 추억', style: AppTypography.sectionTitle),
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
                  color: AppColors.pastelPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_city_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 동네를 설정해보세요', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('커뮤니티 탭에서 동네를 고르면 그 시절 추억이 여기 떠요', style: AppTypography.footnote),
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

class _LoginPromptCard extends StatelessWidget {
  const _LoginPromptCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 추억', style: AppTypography.sectionTitle),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => context.go('/profile'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pastelPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('추억을 기록하고 보관해보세요', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('로그인 후 그때 그 시절을 오늘 다시 만나요', style: AppTypography.footnote),
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
