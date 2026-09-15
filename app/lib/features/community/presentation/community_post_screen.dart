import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../../shared/widgets/report_dialog.dart';
import '../../auth/data/auth_providers.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';
import 'widgets/trade_status_chip.dart';

class CommunityPostScreen extends ConsumerStatefulWidget {
  const CommunityPostScreen({super.key, required this.postId});
  final int postId;
  @override
  ConsumerState<CommunityPostScreen> createState() =>
      _CommunityPostScreenState();
}

class _CommunityPostScreenState extends ConsumerState<CommunityPostScreen> {
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _comments = [];
  bool _busy = false, _more = false, _loadingMore = false;
  String? _error;
  final _comment = TextEditingController();
  int? _replyToId;
  String? _replyToNickname;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(communityRepositoryProvider);
      final result = await Future.wait<dynamic>([
        repo.getDetail(widget.postId),
        repo.comments(widget.postId),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = result[0] as Map<String, dynamic>;
        _comments = result[1] as List<Map<String, dynamic>>;
        _more = _comments.length == 30;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '불러오기 실패');
    }
  }

  void _invalidate() {
    if (_detail == null) return;
    final region = _detail!['region'] as String;
    ref.invalidate(
      communityFeedProvider((
        region: region,
        board: _detail!['board'] as String,
      )),
    );
    ref.invalidate(communityPreviewProvider(region));
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    if (ref.read(authStateProvider).asData?.value != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그인하면 댓글과 공감을 남길 수 있어요'),
          action: SnackBarAction(
            label: '로그인',
            onPressed: () => context.go('/profile'),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      _invalidate();
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.statusCode == 403
                  ? '작성자만 변경할 수 있어요'
                  : '저장하지 못했어요. 다시 시도해주세요.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('변경하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(CommunityPost post) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditPost(post: post),
    );
    if (result != null && mounted) {
      await _act(
        () => ref
            .read(communityRepositoryProvider)
            .update(post.id, result.$1, result.$2),
      );
    }
  }

  Future<void> _delete(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 글을 삭제할까요?'),
        content: const Text('댓글과 공감도 함께 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(communityRepositoryProvider).delete(post.id);
      _invalidate();
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요')));
      }
    }
  }

  Future<void> _changeTradeStatus(int postId, String status) async {
    await _act(() => ref.read(communityRepositoryProvider).updateTradeStatus(postId, status));
  }

  Future<void> _reportPost(int postId) async {
    final reason = await showReportDialog(context);
    if (reason == null || !mounted) return;
    await _act(() => ref.read(communityRepositoryProvider).reportPost(postId, reason));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고했어요')));
    }
  }

  Future<void> _reportComment(int postId, int commentId) async {
    final reason = await showReportDialog(context);
    if (reason == null || !mounted) return;
    await _act(() => ref.read(communityRepositoryProvider).reportComment(postId, commentId, reason));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고했어요')));
    }
  }

  Future<void> _blockAuthor(int userId, String nickname) async {
    final confirmed = await showBlockConfirmDialog(context, nickname);
    if (!confirmed || !mounted) return;
    if (ref.read(authStateProvider).asData?.value != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요해요')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(communityRepositoryProvider).blockUser(userId);
      _invalidate();
      if (mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단했어요')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단하지 못했어요')));
      }
    }
  }

  List<Map<String, dynamic>> get _topLevelComments =>
      _comments.where((c) => c['parent_id'] == null).toList();

  List<Map<String, dynamic>> _repliesFor(int parentId) =>
      _comments.where((c) => c['parent_id'] == parentId).toList();

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(communityRepositoryProvider)
          .comments(widget.postId, offset: _comments.length);
      if (mounted) {
        setState(() {
          _comments.addAll(next);
          _more = next.length == 30;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글을 불러오지 못했어요')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _detail;
    final post = data == null ? null : CommunityPost.fromJson(data);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('동네 이야기'),
        actions: [
          if (post != null)
            data?['is_mine'] == true
                ? PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (v) => v == 'edit' ? _edit(post) : _delete(post),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  )
                : PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (v) => v == 'report'
                        ? _reportPost(post.id)
                        : _blockAuthor(post.authorId, post.authorNickname),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('신고하기')),
                      PopupMenuItem(value: 'block', child: Text('작성자 차단')),
                    ],
                  ),
        ],
      ),
      body: post == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('글을 불러오지 못했어요. 삭제되었을 수 있어요.'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.region, style: AppTypography.caption),
                        const SizedBox(height: 8),
                        Text(
                          post.title ?? '그 시절의 추억',
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${post.authorNickname} · ${post.createdAt.toLocal().toString().substring(0, 16)}',
                          style: AppTypography.footnote,
                        ),
                        if (post.memoryYear != null)
                          Text(
                            '${post.memoryYear}년의 기억',
                            style: AppTypography.footnote,
                          ),
                        if (communityBoardById(post.board).isTradeBoard && post.tradeStatus != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                post.price != null ? '${formatPrice(post.price!)}원' : '나눔',
                                style: AppTypography.title.copyWith(fontSize: 20, color: AppColors.accentDeep),
                              ),
                              const SizedBox(width: 10),
                              if (post.tradeStatus != null)
                                data?['is_mine'] == true
                                    ? TradeStatusDropdown(
                                        status: post.tradeStatus!,
                                        onChanged: _busy ? null : (status) => _changeTradeStatus(post.id, status),
                                      )
                                    : TradeStatusChip(status: post.tradeStatus!),
                            ],
                          ),
                        ],
                        if (post.contentBlocks != null && post.contentBlocks!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ContentBlocksView(blocks: post.contentBlocks!),
                        ] else ...[
                          if (post.photoUrls.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: _PhotoGallery(photoUrls: post.photoUrls),
                            ),
                          const SizedBox(height: 12),
                          SelectableText(
                            post.caption ?? '',
                            style: AppTypography.body,
                          ),
                        ],
                        if (post.locationId != null)
                          TextButton.icon(
                            onPressed: () =>
                                context.push('/compare/${post.locationId}'),
                            icon: const Icon(Icons.place_outlined),
                            label: const Text('이 장소 둘러보기'),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _act(
                                  () => ref
                                      .read(communityRepositoryProvider)
                                      .setLike(post.id, data!['liked'] != true),
                                ),
                          icon: Icon(
                            data!['liked'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          label: Text('공감 ${data['like_count']}'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '댓글 ${data['comment_count']}',
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: 12),
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '첫 이야기를 들려주세요.',
                        style: AppTypography.subhead,
                      ),
                    ),
                  for (final c in _topLevelComments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommentRow(
                            comment: c,
                            busy: _busy,
                            onDelete: () => _act(
                              () => ref
                                  .read(communityRepositoryProvider)
                                  .deleteComment(post.id, c['id'] as int),
                            ),
                            onReport: () => _reportComment(post.id, c['id'] as int),
                            onReply: () => setState(() {
                              _replyToId = c['id'] as int;
                              _replyToNickname = c['author_nickname'] as String;
                            }),
                          ),
                          for (final reply in _repliesFor(c['id'] as int))
                            Padding(
                              padding: const EdgeInsets.only(left: 28, top: 8),
                              child: _CommentRow(
                                comment: reply,
                                busy: _busy,
                                onDelete: () => _act(
                                  () => ref
                                      .read(communityRepositoryProvider)
                                      .deleteComment(post.id, reply['id'] as int),
                                ),
                                onReport: () => _reportComment(post.id, reply['id'] as int),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_more)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? '불러오는 중…' : '댓글 더보기'),
                    ),
                  const SizedBox(height: 12),
                  if (_replyToNickname != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$_replyToNickname님에게 답글 남기는 중',
                              style: AppTypography.caption.copyWith(color: AppColors.accentDeep),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _replyToId = null;
                              _replyToNickname = null;
                            }),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _comment,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: _replyToNickname != null ? '답글을 남겨주세요' : '따뜻한 댓글을 남겨주세요',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _act(() async {
                            final text = _comment.text.trim();
                            if (text.isEmpty) return;
                            await ref
                                .read(communityRepositoryProvider)
                                .comment(post.id, text, parentId: _replyToId);
                            _comment.clear();
                            _replyToId = null;
                            _replyToNickname = null;
                          }),
                    child: Text(_busy ? '저장 중…' : _replyToNickname != null ? '답글 등록' : '댓글 등록'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 댓글 한 줄 — 본인 댓글이면 삭제, 남의 댓글이면 신고 아이콘. 최상위 댓글에만
/// "답글" 버튼이 있다(답글엔 답글을 안 달아 1단계 스레드만 유지, 서비스 레이어와
/// 동일한 규칙).
class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.busy,
    required this.onDelete,
    required this.onReport,
    this.onReply,
  });

  final Map<String, dynamic> comment;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(comment['author_nickname'] as String, style: AppTypography.footnote),
              ),
              if (comment['is_mine'] == true)
                IconButton(
                  tooltip: '댓글 삭제',
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                )
              else
                IconButton(
                  tooltip: '댓글 신고',
                  onPressed: busy ? null : onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16),
                ),
            ],
          ),
          Text(comment['body'] as String, style: AppTypography.body),
          if (onReply != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: busy ? null : onReply,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('답글달기', style: AppTypography.caption),
            ),
          ],
        ],
      ),
    );
  }
}

/// 블로그 스타일로 쓴 글의 본문 — 텍스트/사진 블록을 작성한 순서 그대로 세로로 나열한다.
class _ContentBlocksView extends StatelessWidget {
  const _ContentBlocksView({required this.blocks});

  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.type == 'image' && block.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppNetworkImage(
                imageUrl: block.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const PhotoFallback(),
                errorWidget: (_, _, _) => const PhotoFallback(),
              ),
            )
          else if (block.type == 'text' && (block.text ?? '').isNotEmpty)
            SelectableText(block.text!, style: AppTypography.body),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// 게시글 사진 — 여러 장이면 좌우로 넘겨보는 갤러리 + 페이지 점 표시.
class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photoUrls});

  final List<String> photoUrls;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.photoUrls;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => AppNetworkImage(
                imageUrl: urls[i],
                fit: BoxFit.contain,
                placeholder: (_, _) => const PhotoFallback(),
                errorWidget: (_, _, _) => const PhotoFallback(),
              ),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < urls.length; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? AppColors.accent : AppColors.hairline,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EditPost extends StatefulWidget {
  const _EditPost({required this.post});
  final CommunityPost post;
  @override
  State<_EditPost> createState() => _EditPostState();
}

class _EditPostState extends State<_EditPost> {
  late final _title = TextEditingController(text: widget.post.title);
  late final _body = TextEditingController(text: widget.post.caption);
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('이야기 수정'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: '제목'),
          ),
          TextField(
            controller: _body,
            maxLength: 2000,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '내용'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(
        onPressed: () {
          if (_title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty) {
            Navigator.pop(context, (_title.text.trim(), _body.text.trim()));
          }
        },
        child: const Text('저장'),
      ),
    ],
  );
}
