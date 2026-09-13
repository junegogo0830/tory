import 'dart:typed_data';

import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../data/profile_providers.dart';

/// 프로필 "설정" 아이콘 → 닉네임/프로필 사진 수정 + 회원 탈퇴.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nickname;
  XFile? _pickedPhoto;
  bool _busy = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked != null && mounted) setState(() => _pickedPhoto = picked);
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요')));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateNickname(nickname);
      final photo = _pickedPhoto;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await repo.updatePhoto(
          photoBytes: bytes,
          photoFilename: photo.name,
          photoMimeType: 'image/jpeg',
        );
      }
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요')));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴할까요?'),
        content: const Text('내 글, 댓글, 저장한 골목 등 모든 데이터가 영구적으로 삭제되고 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      ref.invalidate(profileProvider);
      ref.invalidate(authStateProvider);
      if (mounted) {
        context.go('/profile');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('탈퇴가 완료됐어요')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('탈퇴하지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    profileAsync.whenData((profile) {
      if (!_initialized) {
        _initialized = true;
        _nickname.text = profile.displayName;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('프로필 수정')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _pickPhoto,
                  child: Stack(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: _pickedPhoto != null
                              ? _LocalPhotoPreview(file: _pickedPhoto!)
                              : profile.profileImageUrl != null
                                  ? AppNetworkImage(imageUrl: profile.profileImageUrl!, fit: BoxFit.cover)
                                  : const ColoredBox(
                                      color: AppColors.accentTint,
                                      child: Icon(Icons.person, color: AppColors.accentDeep, size: 40),
                                    ),
                        ),
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.accent,
                          child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('닉네임', style: AppTypography.footnote),
              const SizedBox(height: 6),
              TextField(
                controller: _nickname,
                maxLength: 80,
                decoration: const InputDecoration(hintText: '닉네임을 입력해주세요'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '저장 중…' : '저장'),
                ),
              ),
              const SizedBox(height: 40),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('탈퇴하기', style: AppTypography.headline),
                    const SizedBox(height: 6),
                    Text(
                      '탈퇴하면 내 글·댓글·저장한 골목 등 모든 데이터가 삭제되고 복구할 수 없어요.',
                      style: AppTypography.footnote,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _deleteAccount,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('회원 탈퇴'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}

class _LocalPhotoPreview extends StatelessWidget {
  const _LocalPhotoPreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const ColoredBox(color: AppColors.accentTint);
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      },
    );
  }
}
