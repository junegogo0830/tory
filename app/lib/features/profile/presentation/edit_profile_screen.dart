import 'dart:typed_data';

import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/data/auth_error.dart';
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
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  XFile? _pickedPhoto;
  bool _busy = false;
  bool _initialized = false;
  bool _changingPassword = false;
  bool _showPasswordFields = false;
  List<String>? _joinedRegions;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController();
    _loadJoinedRegions();
  }

  Future<void> _loadJoinedRegions() async {
    try {
      final regions = await ref.read(communityRepositoryProvider).myRegions();
      if (mounted) setState(() => _joinedRegions = regions);
    } catch (_) {
      if (mounted) setState(() => _joinedRegions = []);
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
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

  Future<void> _changePassword() async {
    final current = _currentPassword.text;
    final next = _newPassword.text;
    if (current.isEmpty || next.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호를 모두 입력해주세요')));
      return;
    }
    if (next.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 비밀번호는 8자 이상이어야 해요')));
      return;
    }
    if (next != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 비밀번호가 일치하지 않아요')));
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await ref.read(profileRepositoryProvider).changePassword(currentPassword: current, newPassword: next);
      if (mounted) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        setState(() => _showPasswordFields = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호를 변경했어요')));
      }
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeAuthError(e))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('변경하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
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
              const SizedBox(height: 28),
              Text('현재 가입한 커뮤니티', style: AppTypography.footnote),
              const SizedBox(height: 8),
              _JoinedRegionsList(regions: _joinedRegions),
              const SizedBox(height: 22),
              _NavRow(
                icon: Icons.badge_outlined,
                label: '정보 수정',
                subtitle: '나이·사는 곳·성별·이름·전화번호·모교·살았던 곳',
                onTap: () => context.push('/profile/info'),
              ),
              const SizedBox(height: 28),
              Text('내 계정 관리', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
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
              if (profile.hasPassword) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('비밀번호 변경', style: AppTypography.footnote),
                    TextButton(
                      onPressed: () => setState(() => _showPasswordFields = !_showPasswordFields),
                      child: Text(_showPasswordFields ? '취소' : '변경하기'),
                    ),
                  ],
                ),
                if (_showPasswordFields) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '현재 비밀번호'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '새 비밀번호 (8자 이상)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '새 비밀번호 확인'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _changingPassword ? null : _changePassword,
                      child: _changingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('비밀번호 변경'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
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

/// 내가 가입한 커뮤니티(지역) 전체 목록 — "사는 지역" 하나만 보여주던 자리를 대신한다.
class _JoinedRegionsList extends StatelessWidget {
  const _JoinedRegionsList({required this.regions});

  final List<String>? regions;

  @override
  Widget build(BuildContext context) {
    if (regions == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (regions!.isEmpty) {
      return Text('아직 가입한 커뮤니티가 없어요', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final region in regions!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_city_outlined, size: 15, color: AppColors.accentDeep),
                const SizedBox(width: 6),
                Text(region, style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.subtitle, required this.onTap});

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.accentDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
          ],
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
