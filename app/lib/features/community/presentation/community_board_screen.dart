import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/repository_providers.dart';
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

class CommunityBoardScreen extends ConsumerStatefulWidget {
  const CommunityBoardScreen({
    super.key,
    required this.region,
    required this.boardId,
  });
  final String region;
  final String boardId;
  @override
  ConsumerState<CommunityBoardScreen> createState() =>
      _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends ConsumerState<CommunityBoardScreen> {
  final _search = TextEditingController();
  List<CommunityPost> _posts = [];
  bool _loading = true, _more = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await ref
          .read(communityRepositoryProvider)
          .getPosts(
            widget.region,
            board: widget.boardId,
            offset: append ? _posts.length : 0,
            query: _search.text.trim(),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _posts = append ? [..._posts, ...posts] : posts;
        _more = posts.length == 20;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '글을 불러오지 못했어요');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = communityBoardById(widget.boardId);
    ref.listen(
      communityFeedProvider((region: widget.region, board: widget.boardId)),
      (_, next) {
        if (next.hasValue) _load();
      },
    );
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: board.color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(board.label, style: AppTypography.headline),
            Text(widget.region, style: AppTypography.caption),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          await showCommunityPostFlow(
            context,
            ref,
            region: widget.region,
            board: board,
          );
          if (mounted) _load();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '제목·내용 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: '검색 초기화',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                    itemCount: _posts.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index < _posts.length) {
                        return GestureDetector(
                          onTap: () async {
                            await context.push('/post/${_posts[index].id}');
                            if (mounted) _load();
                          },
                          child: AbsorbPointer(
                            child: _PostCard(post: _posts[index], board: board),
                          ),
                        );
                      }
                      if (_loading) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (_error != null) {
                        return Column(
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: () => _load(append: _posts.isNotEmpty),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        );
                      }
                      if (_posts.isEmpty) {
                        return EmptyState(
                          icon: board.icon,
                          title: _search.text.trim().isEmpty
                              ? '아직 글이 없어요'
                              : '검색 결과가 없어요',
                          message: '지역의 이야기를 먼저 나눠보세요.',
                        );
                      }
                      return _more
                          ? TextButton(
                              onPressed: () => _load(append: true),
                              child: const Text('이야기 더보기'),
                            )
                          : Center(
                              child: Text(
                                '모든 이야기를 읽었어요',
                                style: AppTypography.caption,
                              ),
                            );
                    },
                  ),
                ),
              ),
            ],
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
      onTap: () async {
        await context.push('/post/${post.id}');
      },
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AppNetworkImage(
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
                decoration: BoxDecoration(
                  color: board.color,
                  shape: BoxShape.circle,
                ),
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
                Text(
                  '${post.memoryYear}년',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accentDeep,
                  ),
                ),
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
              Text(
                post.authorNickname,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·',
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkTertiary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(post.createdAt.toLocal()),
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
