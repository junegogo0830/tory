import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/pending_photo.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';

const _maxPhotosPerPost = 5;

/// compare_screen(특정 장소 상세)의 "추억 등록" 카드가 쓰는 얇은 래퍼 — 항상
/// 추억 게시판에 사진과 함께 올린다.
Future<void> showMemoryUploadFlow(
  BuildContext context,
  WidgetRef ref, {
  required String region,
  String? locationId,
}) {
  return showCommunityPostFlow(
    context,
    ref,
    region: region,
    board: communityBoardById('memory'),
    locationId: locationId,
  );
}

/// 게시판별 글쓰기 플로우. 로그인 확인 → (사진 필수 게시판이면) 사진 선택 →
/// 제목/내용(+선택 사진) 입력 → 업로드. 4개 게시판(자유/추억/주민/관광정보)이
/// 전부 같은 흐름을 쓰되, 추억 게시판만 사진이 사실상 필수다. 사진은 최대
/// [_maxPhotosPerPost]장까지 첨부할 수 있다.
Future<void> showCommunityPostFlow(
  BuildContext context,
  WidgetRef ref, {
  required String region,
  required CommunityBoard board,
  String? locationId,
}) async {
  final isLoggedIn = ref.read(authStateProvider).value ?? false;
  if (!isLoggedIn) {
    // 회원만 가능한 액션 — 안내만 하고 끝내는 대신 바로 가입 화면(프로필 탭의
    // 로그인 카드)으로 보낸다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${board.label}에 글을 쓰려면 먼저 로그인해주세요')),
    );
    context.push('/profile');
    return;
  }

  List<XFile> requiredPhotos = const [];
  if (board.requiresPhoto) {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1920);
    if (picked.isEmpty || !context.mounted) return;
    requiredPhotos = picked.take(_maxPhotosPerPost).toList();
  }

  final details = await showModalBottomSheet<_PostDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => SingleChildScrollView(
      child: _PostDetailsSheet(board: board, requiredPhotos: requiredPhotos),
    ),
  );
  if (details == null || !context.mounted) return;

  try {
    final photos = requiredPhotos.isNotEmpty ? requiredPhotos : details.optionalPhotos;
    final pendingPhotos = <PendingPhoto>[];
    for (final photo in photos) {
      final bytes = await photo.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${photo.name}은(는) 8MB를 넘어서 제외했어요')),
          );
        }
        continue;
      }
      final mimeType =
          bytes.length >= 12 && bytes[0] == 0x89 && bytes[1] == 0x50
          ? 'image/png'
          : bytes.length >= 12 && bytes[0] == 0x52 && bytes[8] == 0x57
          ? 'image/webp'
          : 'image/jpeg';
      pendingPhotos.add(PendingPhoto(bytes: bytes, filename: photo.name, mimeType: mimeType));
    }
    if (board.requiresPhoto && pendingPhotos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('첨부할 수 있는 사진이 없어요. 다시 시도해주세요.')));
      }
      return;
    }

    await ref
        .read(communityRepositoryProvider)
        .createPost(
          region: region,
          board: board.id,
          title: details.title,
          photos: pendingPhotos,
          locationId: locationId,
          caption: details.caption,
          memoryYear: details.year,
        );
    ref.invalidate(profileProvider);
    ref.invalidate(communityFeedProvider((region: region, board: board.id)));
    if (board.id == 'memory') ref.invalidate(communityPreviewProvider(region));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('글이 등록됐어요')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('등록에 실패했어요. 다시 시도해주세요.')));
  }
}

class _PostDetails {
  const _PostDetails({this.title, this.caption, this.year, this.optionalPhotos = const []});
  final String? title;
  final String? caption;
  final int? year;
  final List<XFile> optionalPhotos;
}

class _PostDetailsSheet extends StatefulWidget {
  const _PostDetailsSheet({required this.board, this.requiredPhotos = const []});

  final CommunityBoard board;
  final List<XFile> requiredPhotos;

  @override
  State<_PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<_PostDetailsSheet> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _yearController = TextEditingController();
  List<XFile> _optionalPhotos = const [];

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickOptionalPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1920);
    if (picked.isEmpty || !mounted) return;
    setState(() => _optionalPhotos = picked.take(_maxPhotosPerPost).toList());
  }

  void _submit() {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();
    if (title.isEmpty && caption.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목이나 내용을 입력해주세요')));
      return;
    }
    final yearText = _yearController.text.trim();
    final year = int.tryParse(yearText);
    if (yearText.isNotEmpty &&
        (year == null || year < 1900 || year > DateTime.now().year)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1900년부터 올해 사이의 연도를 입력해주세요')),
      );
      return;
    }
    Navigator.pop(
      context,
      _PostDetails(
        title: title.isEmpty ? null : title,
        caption: caption.isEmpty ? null : caption,
        year: int.tryParse(_yearController.text.trim()),
        optionalPhotos: _optionalPhotos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final showOptionalPhotoPicker = !board.requiresPhoto;
    final requiredCount = widget.requiredPhotos.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: board.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(board.icon, size: 18, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Text(board.label, style: AppTypography.headline),
            ],
          ),
          if (requiredCount > 0) ...[
            const SizedBox(height: 6),
            Text('사진 $requiredCount장 선택됨', style: AppTypography.footnote),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            maxLength: 60,
            decoration: const InputDecoration(hintText: '제목'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _captionController,
            maxLength: 500,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: board.id == 'memory'
                  ? '예: 우리 아파트 놀이터에서 친구들이랑'
                  : '내용을 입력해주세요',
            ),
          ),
          if (board.id == 'memory') ...[
            const SizedBox(height: 6),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '몇 년도 사진인가요? 예: 1999',
              ),
            ),
          ],
          if (showOptionalPhotoPicker) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickOptionalPhotos,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(
                _optionalPhotos.isEmpty ? '사진 추가 (선택, 최대 $_maxPhotosPerPost장)' : '사진 ${_optionalPhotos.length}장 첨부됨',
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('등록하기'),
            ),
          ),
        ],
      ),
    );
  }
}
