import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/repository_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';
import 'memory_upload_flow.dart';
import 'widgets/trade_status_chip.dart';

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
  String? _selectedCategory;
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
            category: _selectedCategory,
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

  void _selectCategory(String? category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final board = communityBoardById(widget.boardId);
    final categories = ref.watch(communityPostCategoriesProvider).value?[board.id] ?? const [];
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
        actions: [
          if (board.id == 'memory')
            IconButton(
              tooltip: '연도별 타임라인',
              icon: const Icon(Icons.timeline),
              onPressed: () => context.push(
                '/memory-timeline/${Uri.encodeComponent(widget.region)}',
              ),
            ),
          if (board.isMapBoard)
            IconButton(
              tooltip: '지도로 보기',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => context.push(
                '/community-map/${Uri.encodeComponent(widget.region)}/${board.id}',
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
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
              if (categories.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final label = index == 0 ? '전체' : categories[index - 1];
                      final value = index == 0 ? null : categories[index - 1];
                      return _CategoryToggle(
                        label: label,
                        selected: _selectedCategory == value,
                        onTap: () => _selectCategory(value),
                      );
                    },
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
                        final post = _posts[index];
                        return _PostCard(
                          post: post,
                          board: board,
                          onTap: () async {
                            if (!post.revealed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${_formatDate(post.revealAt!.toLocal())}에 열려요')),
                              );
                              return;
                            }
                            await context.push('/post/${post.id}');
                            if (mounted) _load();
                          },
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

/// 게시판 필터 토글 하나("전체" 포함) — 검색창 아래 가로 스크롤 행에 쓴다.
class _CategoryToggle extends StatelessWidget {
  const _CategoryToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.fieldBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 조회수/좋아요/댓글 수 표시 — 목록 카드에서는 눌러도 반응 없이 숫자만 보여준다
/// (상세로 들어가야 실제로 좋아요를 누르거나 댓글을 달 수 있다).
class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.inkTertiary),
        const SizedBox(width: 3),
        Text('$count', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
      ],
    );
  }
}

/// 사진이 여러 장이면 옆으로 넘겨볼 수 있는 목록 카드용 미니 갤러리.
class _PostPhotoCarousel extends StatefulWidget {
  const _PostPhotoCarousel({required this.photos});

  final List<String> photos;

  @override
  State<_PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<_PostPhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => AppNetworkImage(
            imageUrl: widget.photos[i],
            fit: BoxFit.cover,
            placeholder: (_, _) => const PhotoFallback(),
            errorWidget: (_, _, _) => const PhotoFallback(),
          ),
        ),
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.photos.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 스레드 스타일 게시글 카드 — 왼쪽 아바타 + 오른쪽 박스(닉네임 볼드/제목/
/// 본문/사진/조회·좋아요·댓글·공유).
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.board, required this.onTap});

  final CommunityPost post;
  final CommunityBoard board;
  final VoidCallback onTap;

  Future<void> _share(BuildContext context) async {
    final text = post.title ?? post.caption ?? '';
    await Clipboard.setData(ClipboardData(text: '옛길 ${board.label} — $text'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('글 내용을 복사했어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!post.revealed) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: _LockedTimeCapsuleCard(post: post),
      );
    }

    final photos = post.photoUrls.isNotEmpty
        ? post.photoUrls
        : (post.photoUrl != null ? [post.photoUrl!] : const <String>[]);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(imageUrl: post.authorAvatarUrl, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.authorNickname,
                          style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.memoryYear != null) ...[
                        Text('${post.memoryYear}년', style: AppTypography.caption.copyWith(color: AppColors.accentDeep)),
                        const SizedBox(width: 6),
                      ],
                      Text(_formatDate(post.createdAt.toLocal()), style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                    ],
                  ),
                  if (post.title != null) ...[
                    const SizedBox(height: 4),
                    Text(post.title!, style: AppTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (board.isTradeBoard && (post.price != null || post.tradeStatus != null)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (post.tradeStatus != null) ...[
                          TradeStatusChip(status: post.tradeStatus!),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          post.price != null ? '${formatPrice(post.price!)}원' : '나눔',
                          style: AppTypography.subhead.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.caption!,
                      style: AppTypography.subhead,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: photos.length == 1
                            ? AppNetworkImage(
                                imageUrl: photos.first,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const PhotoFallback(),
                                errorWidget: (_, _, _) => const PhotoFallback(),
                              )
                            : _PostPhotoCarousel(photos: photos),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatIcon(icon: Icons.remove_red_eye_outlined, count: post.viewCount),
                      const SizedBox(width: 14),
                      _StatIcon(icon: Icons.favorite_border, count: post.likeCount),
                      const SizedBox(width: 14),
                      _StatIcon(icon: Icons.mode_comment_outlined, count: post.commentCount),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => _share(context),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.share_outlined, size: 16, color: AppColors.inkTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 타임캡슐 편지가 아직 봉인 해제 전일 때 보여주는 잠긴 카드 — 내용은 아예
/// 서버가 안 내려주니(services/community.py 참고) 여기선 남은 기간만 보여준다.
class _LockedTimeCapsuleCard extends StatelessWidget {
  const _LockedTimeCapsuleCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final revealAt = post.revealAt;
    final daysLeft = revealAt == null
        ? null
        : revealAt.toLocal().difference(DateTime.now()).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pastelRose.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.pastelRose),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_lock_outlined, color: AppColors.accentDeep, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('봉인된 편지', style: AppTypography.headline),
                const SizedBox(height: 2),
                Text(
                  revealAt == null
                      ? '아직 열 수 없어요'
                      : daysLeft != null && daysLeft > 0
                          ? '${_formatDate(revealAt.toLocal())}에 열려요 (D-$daysLeft)'
                          : '곧 열려요',
                  style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
