import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/community_providers.dart';

/// "장소별 추억 타임라인" — 추억 게시판 글을 연도순으로 쭉 훑어보는 화면.
/// 최신순 목록과 별개로, "이 동네가 시절별로 어떻게 변해왔는지"를 한 번에
/// 보여주는 게 목적이라 페이지네이션 없이 연도 구간으로 묶어서 보여준다.
class MemoryTimelineScreen extends ConsumerWidget {
  const MemoryTimelineScreen({super.key, required this.region});

  final String region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(communityTimelineProvider(region));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('$region 추억 타임라인')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: timelineAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history_outlined,
                    title: '아직 추억이 없어요',
                    message: '이 동네의 첫 추억을 남겨보세요.',
                  );
                }
                final groups = _groupByYear(posts);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  group.year == null ? '연도 미상' : '${group.year}년',
                                  style: AppTypography.subhead.copyWith(
                                    color: AppColors.surface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Divider(color: AppColors.hairline)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final post in group.posts) ...[
                            _TimelineRow(post: post),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(
                child: Text('타임라인을 불러오지 못했어요', style: AppTypography.subhead),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearGroup {
  const _YearGroup({required this.year, required this.posts});
  final int? year;
  final List<CommunityPost> posts;
}

List<_YearGroup> _groupByYear(List<CommunityPost> posts) {
  final groups = <int?, List<CommunityPost>>{};
  for (final post in posts) {
    groups.putIfAbsent(post.memoryYear, () => []).add(post);
  }
  final years = groups.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });
  return [for (final year in years) _YearGroup(year: year, posts: groups[year]!)];
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      onTap: () => context.push('/post/${post.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: SizedBox(
              width: 72,
              height: 72,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title ?? post.caption ?? '(내용 없음)',
                  style: AppTypography.headline,
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
                const SizedBox(height: 4),
                Text(
                  post.authorNickname,
                  style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
