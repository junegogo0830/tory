import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';

/// "추억 등록" 플로우. compare_screen(특정 장소)과 커뮤니티 탭(내 동네) 양쪽에서
/// 같은 흐름을 쓴다: 로그인 확인 → 안내 다이얼로그 → 사진 권한 → 사진 선택
/// → 캡션/연도(선택) → 업로드.
Future<void> showMemoryUploadFlow(
  BuildContext context,
  WidgetRef ref, {
  required String region,
  String? locationId,
}) async {
  final isLoggedIn = ref.read(authStateProvider).value ?? false;
  if (!isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('추억을 등록하려면 먼저 로그인해주세요 (프로필 탭)')),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('이 지역에서의 추억이 있나요?', style: AppTypography.headline),
      content: Text(
        '지금 사진을 등록해서 추억을 공유해주세요.',
        style: AppTypography.subhead,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('등록하기')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final permission = await Permission.photos.request();
  if (!permission.isGranted && !context.mounted) return;
  if (!permission.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사진 접근 권한이 필요해요')),
    );
    return;
  }

  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (picked == null || !context.mounted) return;

  final details = await showModalBottomSheet<_MemoryDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => const _MemoryDetailsSheet(),
  );
  if (!context.mounted) return;

  try {
    final bytes = await picked.readAsBytes();
    await ref.read(communityRepositoryProvider).createPost(
          region: region,
          photoBytes: bytes,
          photoFilename: picked.name,
          photoMimeType: picked.mimeType ?? 'image/jpeg',
          locationId: locationId,
          caption: details?.caption,
          memoryYear: details?.year,
        );
    ref.invalidate(profileProvider);
    ref.invalidate(communityFeedProvider(region));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('추억이 등록됐어요')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('등록에 실패했어요. 다시 시도해주세요.')),
    );
  }
}

class _MemoryDetails {
  const _MemoryDetails({this.caption, this.year});
  final String? caption;
  final int? year;
}

class _MemoryDetailsSheet extends StatefulWidget {
  const _MemoryDetailsSheet();

  @override
  State<_MemoryDetailsSheet> createState() => _MemoryDetailsSheetState();
}

class _MemoryDetailsSheetState extends State<_MemoryDetailsSheet> {
  final _captionController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _submit() {
    final year = int.tryParse(_yearController.text.trim());
    Navigator.pop(
      context,
      _MemoryDetails(
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        year: year,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('추억 한 줄 남기기 (선택)', style: AppTypography.headline),
          const SizedBox(height: 14),
          TextField(
            controller: _captionController,
            maxLength: 80,
            decoration: const InputDecoration(hintText: '예: 우리 아파트 놀이터에서 친구들이랑'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '몇 년도 사진인가요? 예: 1999'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _submit, child: const Text('등록하기')),
          ),
        ],
      ),
    );
  }
}
