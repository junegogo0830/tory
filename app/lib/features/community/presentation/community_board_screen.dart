import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';
import 'memory_upload_flow.dart';

/// 지역+게시판 단위 게시글 목록. region_picker로 고른 지역과 게시판 하나를 받아
/// 그 조합의 글만 보여준다 — "지역구별로 게시판이 따로 운영되는" 구조를 화면
/// 단위로 그대로 드러낸다.
class CommunityBoardScreen extends ConsumerWidget {
  const CommunityBoardScreen({super.key, required this.region, required this.boardId});

  final String region;
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = communityBoardById(boardId);
    final feedAsync = ref.watch(communityFeedProvider((region: region, board: board.id)));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: board.color,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(board.label, style: AppTypography.headline),
            Text(region, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => showCommunityPostFlow(context, ref, region: region, board: board),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: feedAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return EmptyState(
                    icon: board.icon,
                    title: '아직 글이 없어요',
                    message: '$region의 첫 ${board.label} 글을 남겨보세요.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _PostCard(post: posts[index], board: board),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(
                child: Text('글을 불러오지 못했어요', style: AppTypography.subhead),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.board});

  final CommunityPost post;
  final CommunityBoard board;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: post.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const PhotoFallback(),
                  errorWidget: (_, _, _) => const PhotoFallback(),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: board.color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  post.title ?? post.caption ?? '(내용 없음)',
                  style: AppTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (post.memoryYear != null)
                Text('${post.memoryYear}년', style: AppTypography.caption.copyWith(color: AppColors.accentDeep)),
            ],
          ),
          if (post.title != null && post.caption != null) ...[
            const SizedBox(height: 6),
            Text(
              post.caption!,
              style: AppTypography.subhead,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(post.authorNickname, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
              const SizedBox(width: 6),
              Text('·', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
              const SizedBox(width: 6),
              Text(
                _formatDate(post.createdAt.toLocal()),
                style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
