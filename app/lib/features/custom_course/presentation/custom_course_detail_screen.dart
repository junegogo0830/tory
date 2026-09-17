import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/kakao_map_links.dart';
import '../../../data/models/custom_course.dart';
import '../../../data/models/memory_match.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/photo_attribution_badge.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../../shared/widgets/save_course_button.dart';
import '../../auth/data/auth_providers.dart';
import '../data/custom_course_providers.dart';

class CustomCourseDetailScreen extends ConsumerStatefulWidget {
  const CustomCourseDetailScreen({super.key, required this.courseId});

  final int courseId;

  @override
  ConsumerState<CustomCourseDetailScreen> createState() => _CustomCourseDetailScreenState();
}

class _CustomCourseDetailScreenState extends ConsumerState<CustomCourseDetailScreen> {
  final _commentController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => ref.read(authStateProvider).asData?.value ?? false;

  Future<void> _requireLogin() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('로그인하면 추천·비추천과 댓글을 남길 수 있어요'),
        action: SnackBarAction(label: '로그인', onPressed: () => context.go('/profile')),
      ),
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    if (!_isLoggedIn) {
      await _requireLogin();
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.statusCode == 403 ? '작성자만 할 수 있어요' : '처리하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('처리하지 못했어요. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vote(CustomCourse course, int value) async {
    await _act(() async {
      final newValue = course.myVote == value ? 0 : value;
      await ref.read(customCourseRepositoryProvider).vote(course.id, newValue);
      ref.invalidate(customCourseDetailProvider(course.id));
    });
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    await _act(() async {
      await ref.read(customCourseRepositoryProvider).addComment(widget.courseId, body);
      _commentController.clear();
      ref.invalidate(customCourseCommentsProvider(widget.courseId));
      ref.invalidate(customCourseDetailProvider(widget.courseId));
    });
  }

  Future<void> _deleteComment(int commentId) async {
    await _act(() async {
      await ref.read(customCourseRepositoryProvider).deleteComment(widget.courseId, commentId);
      ref.invalidate(customCourseCommentsProvider(widget.courseId));
      ref.invalidate(customCourseDetailProvider(widget.courseId));
    });
  }

  Future<void> _deleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('코스를 삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _act(() async {
      await ref.read(customCourseRepositoryProvider).delete(widget.courseId);
      ref.invalidate(customCourseListProvider);
      ref.invalidate(myCustomCoursesProvider);
      if (mounted) context.pop();
    });
  }

  void _openMap() => context.push('/custom-courses/${widget.courseId}/map');

  void _showItinerarySheet(CustomCourse course) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('일정표', style: AppTypography.headline),
            const SizedBox(height: 12),
            for (var i = 0; i < course.places.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.places[i].name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
                          Text(course.places[i].address, style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                          if (course.places[i].note != null && course.places[i].note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(course.places[i].note!, style: AppTypography.footnote.copyWith(height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCourse(CustomCourse course) async {
    final buffer = StringBuffer('옛길에서 만든 코스 — ${course.title}\n');
    for (var i = 0; i < course.places.length; i++) {
      buffer.writeln('${i + 1}. ${course.places[i].name}');
    }
    // 웹에선 지금 보고 있는 페이지 주소를 그대로 붙인다 — 모바일 빌드는 아직
    // 이 코스로 바로 여는 딥링크 스킴이 없어 텍스트만 공유한다.
    if (kIsWeb) buffer.writeln(Uri.base.toString());
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스 정보를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(customCourseDetailProvider(widget.courseId));
    final commentsAsync = ref.watch(customCourseCommentsProvider(widget.courseId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('코스 둘러보기'),
        actions: [
          courseAsync.maybeWhen(
            data: (course) => course.isMine
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: OutlinedButton(
                      onPressed: () => context.push('/custom-courses/${course.id}/edit'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        side: BorderSide(color: AppColors.accent),
                        foregroundColor: AppColors.accentDeep,
                        shape: const StadiumBorder(),
                        textStyle: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('코스 수정'),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(onPressed: _openMap, icon: const Icon(Icons.map_outlined)),
          SaveCourseButton(courseType: 'custom', courseId: '${widget.courseId}'),
          courseAsync.maybeWhen(
            data: (course) => course.isMine
                ? IconButton(onPressed: _deleteCourse, icon: const Icon(Icons.delete_outline))
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: courseAsync.when(
              data: (course) => ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.pastelMint, borderRadius: BorderRadius.circular(AppRadius.tag)),
                        child: Text(course.category, style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('by ${course.authorNickname}', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                      if (!course.isPublic) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(AppRadius.tag)),
                          child: Text('비공개', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(course.title, textAlign: TextAlign.center, style: AppTypography.title.copyWith(fontSize: 22)),
                  if (course.description != null && course.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(course.description!, textAlign: TextAlign.center, style: AppTypography.subhead.copyWith(height: 1.5)),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '선택한 ${course.places.length}개의 장소로 이런 여행 코스가 완성됐어요.\n일정을 확인하고, 이 코스를 떠나보세요!',
                    textAlign: TextAlign.center,
                    style: AppTypography.subhead.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  _JourneyTimeline(
                    places: course.places,
                    onTapPlace: (place) => place.hasCoordinates
                        ? openKakaoMapDirections(name: place.name, latitude: place.latitude!, longitude: place.longitude!)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppColors.hairline),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _ActionPillButton(icon: Icons.map_outlined, label: '지도 보기', onTap: _openMap)),
                      const SizedBox(width: 8),
                      Expanded(child: _ActionPillButton(icon: Icons.list_alt, label: '일정표 보기', onTap: () => _showItinerarySheet(course))),
                      const SizedBox(width: 8),
                      Expanded(child: _ActionPillButton(icon: Icons.share_outlined, label: '코스 공유하기', onTap: () => _shareCourse(course))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: const Text('이 코스 선택하기'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: AppColors.hairline),
                  const SizedBox(height: 16),
                  _VoteBar(course: course, busy: _busy, onVote: (value) => _vote(course, value)),
                  const SizedBox(height: 24),
                  _MemoryOverlapSection(courseId: widget.courseId),
                  const SizedBox(height: 24),
                  Text('댓글 (${course.commentCount})', style: AppTypography.sectionTitle),
                  const SizedBox(height: 10),
                  commentsAsync.when(
                    data: (comments) => comments.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('첫 댓글을 남겨보세요', style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary)),
                          )
                        : Column(children: [for (final comment in comments) _CommentRow(comment: comment, onDelete: () => _deleteComment(comment.id))]),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    ),
                    error: (_, _) => Text('댓글을 불러오지 못했어요', style: AppTypography.footnote),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          maxLength: 300,
                          decoration: const InputDecoration(hintText: '댓글을 남겨보세요', counterText: ''),
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _busy ? null : _submitComment,
                        icon: const Icon(Icons.send),
                        color: AppColors.accentDeep,
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 장소들을 사진+글이 좌우로 번갈아 붙는 "여행 일정" 형태로 보여주는 타임라인.
class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({required this.places, required this.onTapPlace});

  final List<CustomCoursePlace> places;
  final ValueChanged<CustomCoursePlace> onTapPlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < places.length; i++) ...[
          if (i > 0) _JourneyConnector(fromLeft: (i - 1).isEven),
          _JourneyStopRow(
            index: i,
            place: places[i],
            onLeft: i.isEven,
            onTap: places[i].hasCoordinates ? () => onTapPlace(places[i]) : null,
          ),
        ],
      ],
    );
  }
}

class _JourneyStopRow extends StatelessWidget {
  const _JourneyStopRow({required this.index, required this.place, required this.onLeft, this.onTap});

  final int index;
  final CustomCoursePlace place;
  final bool onLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photo = _JourneyPhotoCard(index: index, place: place, onTap: onTap);
    final text = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: _JourneyNote(place: place),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: onLeft
          ? [Expanded(flex: 5, child: photo), const SizedBox(width: 14), Expanded(flex: 6, child: text)]
          : [Expanded(flex: 6, child: text), const SizedBox(width: 14), Expanded(flex: 5, child: photo)],
    );
  }
}

class _JourneyPhotoCard extends StatelessWidget {
  const _JourneyPhotoCard({required this.index, required this.place, this.onTap});

  final int index;
  final CustomCoursePlace place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 번호 배지가 위/왼쪽으로 살짝 튀어나오는 만큼 여백을 미리 준다.
            padding: const EdgeInsets.only(top: 10, left: 10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: place.imageUrl == null
                        ? const PhotoFallback(label: '사진이 없어요')
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              AppNetworkImage(
                                imageUrl: place.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const PhotoFallback(),
                                errorWidget: (_, _, _) => const PhotoFallback(),
                              ),
                              if (place.photoAttributionName != null)
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: PhotoAttributionBadge(
                                    name: place.photoAttributionName,
                                    url: place.photoAttributionUrl,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  top: -10,
                  left: -10,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.paper, width: 2),
                      boxShadow: AppShadows.tile,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 14, color: AppColors.accentDeep),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  place.name,
                  style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (place.address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
                place.address,
                style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JourneyNote extends StatelessWidget {
  const _JourneyNote({required this.place});

  final CustomCoursePlace place;

  @override
  Widget build(BuildContext context) {
    final note = place.note;
    if (note == null || note.isEmpty) {
      return Text(
        '${place.name}에서 잠시 머물러보세요',
        style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary, fontStyle: FontStyle.italic, height: 1.5),
      );
    }
    return Text(note, style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary, height: 1.5));
  }
}

/// 앞 칸에서 다음 칸으로 이어지는 구불구불한 점선 연결선 — 좌우로 번갈아
/// 배치된 사진 카드를 손그림 로드맵처럼 이어준다.
class _JourneyConnector extends StatelessWidget {
  const _JourneyConnector({required this.fromLeft});

  final bool fromLeft;
  static const double _height = 42;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: CustomPaint(
        size: const Size(double.infinity, _height),
        painter: _JourneyConnectorPainter(fromLeft: fromLeft, color: AppColors.accent),
      ),
    );
  }
}

class _JourneyConnectorPainter extends CustomPainter {
  _JourneyConnectorPainter({required this.fromLeft, required this.color});

  final bool fromLeft;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final startX = fromLeft ? size.width * 0.22 : size.width * 0.78;
    final endX = fromLeft ? size.width * 0.78 : size.width * 0.22;
    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(startX, size.height * 0.6, endX, size.height * 0.3, endX, size.height);

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next.toDouble()), paint);
        distance += dash + gap;
      }
    }
    canvas.drawCircle(Offset(startX, 0), 2.6, Paint()..color = color);
    canvas.drawCircle(Offset(endX, size.height), 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _JourneyConnectorPainter oldDelegate) =>
      oldDelegate.fromLeft != fromLeft || oldDelegate.color != color;
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        side: BorderSide(color: AppColors.border),
        foregroundColor: AppColors.accentDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accentDeep),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// "이 코스와 추억이 겹치는 사람 N명" — 코스가 방문하는 장소를 추억 장소로
/// 등록했거나 거기 글을 남긴 사람, 또는 코스 작성자와 학교·동네가 겹치는
/// 사람을 보여준다. 아무도 없으면(대부분의 코스) 조용히 아무것도 안 보여준다.
class _MemoryOverlapSection extends ConsumerWidget {
  const _MemoryOverlapSection({required this.courseId});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlapAsync = ref.watch(courseMemoryOverlapProvider(courseId));
    return overlapAsync.when(
      data: (matches) {
        if (matches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: AppColors.hairline),
            const SizedBox(height: 16),
            Text('이 코스와 추억이 겹치는 사람 ${matches.length}명', style: AppTypography.sectionTitle),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return InkWell(
                    onTap: () => _showOverlapDetail(context, match),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.accentTint,
                            backgroundImage: match.profileImageUrl != null
                                ? NetworkImage(match.profileImageUrl!)
                                : null,
                            child: match.profileImageUrl == null
                                ? const Icon(Icons.person, size: 24, color: AppColors.accentDeep)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            match.nickname,
                            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
  }

  void _showOverlapDetail(BuildContext context, MemoryMatch match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.nickname, style: AppTypography.headline),
            const SizedBox(height: 10),
            for (final reason in match.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppColors.accentDeep),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reason, style: AppTypography.body)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/memory-profile/${match.userId}');
                },
                child: const Text('추억 프로필 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({required this.course, required this.busy, required this.onVote});

  final CustomCourse course;
  final bool busy;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _VoteButton(
          icon: Icons.thumb_up_alt_outlined,
          activeIcon: Icons.thumb_up_alt,
          label: '${course.likeCount}',
          active: course.myVote == 1,
          onTap: busy ? null : () => onVote(1),
        ),
        const SizedBox(width: 10),
        _VoteButton(
          icon: Icons.thumb_down_alt_outlined,
          activeIcon: Icons.thumb_down_alt,
          label: '${course.dislikeCount}',
          active: course.myVote == -1,
          onTap: busy ? null : () => onVote(-1),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accentTint : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.accent : AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, size: 17, color: AppColors.accentDeep),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.footnote.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.onDelete});

  final CustomCourseComment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.authorNickname, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(width: 6),
                    Text(_formatDate(comment.createdAt.toLocal()), style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.body, style: AppTypography.subhead),
              ],
            ),
          ),
          if (comment.isMine)
            InkWell(
              onTap: onDelete,
              child: Icon(Icons.close, size: 16, color: AppColors.inkTertiary),
            ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}
