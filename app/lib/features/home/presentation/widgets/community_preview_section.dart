import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../community/data/community_providers.dart';
import '../../../profile/data/profile_providers.dart';

/// 홈 화면 "커뮤니티 새 소식" 섹션 — 내 동네 최근 추억 3개를 작게 미리보기.
/// 비로그인/내 동네 미설정이면 가입 유도 카드를 작게 보여준다.
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

        final previewAsync = ref.watch(communityPreviewProvider(region));
        return previewAsync.when(
          data: (posts) {
            if (posts.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('커뮤니티 새 소식', style: AppTypography.headline)),
                    TextButton(
                      onPressed: () => context.go('/community'),
                      child: const Text('더보기'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: post.photoUrl == null
                              ? const PhotoFallback()
                              : AppNetworkImage(
                                  imageUrl: post.photoUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const PhotoFallback(),
                                  errorWidget: (_, _, _) => const PhotoFallback(),
                                ),
                        ),
                      );
                    },
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

class _JoinPromptCard extends StatelessWidget {
  const _JoinPromptCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.go('/community'),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: AppColors.accentDeep, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 동네 커뮤니티에 가입해보세요', style: AppTypography.headline),
                Text('추억을 나누고 새 소식을 받아볼 수 있어요', style: AppTypography.footnote),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.inkTertiary),
        ],
      ),
    );
  }
}
