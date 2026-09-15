import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';

/// 친구찾기에서 이웃을 눌렀을 때 — 그 사람이 이 동네에 쓴 글(게시판 무관) 목록.
/// region이 null이면(프로필 "등록한 게시글") 지역 무관 내가 쓴 글 전체를 보여준다.
class UserPostsScreen extends ConsumerStatefulWidget {
  const UserPostsScreen({super.key, required this.authorId, required this.authorNickname, this.region});

  final int authorId;
  final String authorNickname;
  final String? region;

  @override
  ConsumerState<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends ConsumerState<UserPostsScreen> {
  List<CommunityPost> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await ref
          .read(communityRepositoryProvider)
          .postsByUser(widget.authorId, region: widget.region);
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) setState(() => _error = '글을 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(widget.region == null ? '내가 쓴 글' : '${widget.authorNickname}님의 글')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _error != null
                  ? Center(child: Text(_error!, style: AppTypography.subhead))
                  : _posts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyState(
                              icon: Icons.article_outlined,
                              title: widget.region == null ? '아직 쓴 글이 없어요' : '아직 이 동네에 쓴 글이 없어요',
                              message: widget.region == null ? '커뮤니티에 첫 글을 남겨보세요.' : '다른 동네에 글을 남겼을 수도 있어요.',
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _posts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _PostRow(post: _posts[index]),
                        ),
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/post/${post.id}'),
      child: Row(
        children: [
          if (post.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AppNetworkImage(
                  imageUrl: post.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const PhotoFallback(),
                  errorWidget: (_, _, _) => const PhotoFallback(),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
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
                const SizedBox(height: 4),
                Text(
                  '${post.board} · ${post.createdAt.toLocal().toString().substring(0, 10)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
