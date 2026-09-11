import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/community_post.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/feature_shortcut_tile.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';
import 'memory_upload_flow.dart';

/// 커뮤니티 탭. 당근마켓st로 "내 동네" 기준 추억 피드를 보여주고, 친구찾기/둘러보기로
/// 가는 작은 블록을 상단에 둔다. 예전 "둘러보기"는 사라진 게 아니라 블록 하나로
/// 진입하는 하위 화면(`/explore`, 루트 레벨 push 라우트)이 됐다.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              children: [
                Text('커뮤니티', style: AppTypography.largeTitle.copyWith(fontSize: 34)),
                const SizedBox(height: 4),
                Text('동네 사람들과 그때 그 시절을 나눠보세요', style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.explore_outlined,
                        label: '둘러보기',
                        onTap: () => context.push('/explore'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FeatureShortcutTile(
                        icon: Icons.people_outline,
                        label: '친구 찾기',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('친구 찾기는 곧 만나볼 수 있어요')),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                authAsync.when(
                  data: (isLoggedIn) => isLoggedIn ? const _MyRegionFeed() : const _GuestPrompt(),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (_, _) => const _GuestPrompt(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestPrompt extends ConsumerWidget {
  const _GuestPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        children: [
          Text('로그인하고 내 동네 커뮤니티에 가입해보세요', style: AppTypography.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('카카오 계정으로 간편하게 시작할 수 있어요', style: AppTypography.subhead, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).loginWithKakao();
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text('카카오로 시작하기'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEE500), foregroundColor: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRegionFeed extends ConsumerWidget {
  const _MyRegionFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        final region = profile.homeRegion;
        if (region == null) return const _HomeRegionSetup();

        final feedAsync = ref.watch(communityFeedProvider(region));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.accentDeep, size: 20),
                      const SizedBox(width: 6),
                      Expanded(child: Text(region, style: AppTypography.headline, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showMemoryUploadFlow(context, ref, region: region),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                  label: const Text('추억 남기기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            feedAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.photo_camera_back_outlined,
                    title: '아직 등록된 추억이 없어요',
                    message: '이 동네에서의 첫 추억을 남겨보세요.',
                  );
                }
                return Column(
                  children: [
                    for (final post in posts) ...[
                      _MemoryCard(post: post),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('피드를 불러오지 못했어요', style: AppTypography.subhead),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (_, _) => Text('프로필을 불러오지 못했어요', style: AppTypography.subhead),
    );
  }
}

class _HomeRegionSetup extends ConsumerStatefulWidget {
  const _HomeRegionSetup();

  @override
  ConsumerState<_HomeRegionSetup> createState() => _HomeRegionSetupState();
}

class _HomeRegionSetupState extends ConsumerState<_HomeRegionSetup> {
  bool _isLocating = false;

  Future<void> _setupHomeRegion() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한이 필요해요');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('기기의 위치 서비스를 켜주세요');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final region = await ref
          .read(communityRepositoryProvider)
          .regionByCoords(lat: position.latitude, lng: position.longitude);
      if (region == null) {
        _showMessage('현재 위치의 동네를 찾지 못했어요');
        return;
      }
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: Text('$region 커뮤니티에 가입할까요?', style: AppTypography.headline),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('가입하기')),
          ],
        ),
      );
      if (confirmed != true) return;

      await ref.read(communityRepositoryProvider).setHomeRegion(region);
      ref.invalidate(profileProvider);
    } catch (_) {
      _showMessage('위치를 가져오지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: const Icon(Icons.near_me_outlined, color: AppColors.accentDeep, size: 26),
          ),
          const SizedBox(height: 14),
          Text('내 동네 커뮤니티에 가입해보세요', style: AppTypography.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            '현재 위치를 기준으로 동네를 찾아드릴게요',
            style: AppTypography.subhead,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLocating ? null : _setupHomeRegion,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.location_searching),
              label: const Text('내 동네 설정하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: post.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => const PhotoFallback(),
                errorWidget: (_, _, _) => const PhotoFallback(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(post.authorNickname, style: AppTypography.headline)),
              if (post.memoryYear != null)
                Text('${post.memoryYear}년', style: AppTypography.caption.copyWith(color: AppColors.accentDeep)),
            ],
          ),
          if (post.caption != null) ...[
            const SizedBox(height: 4),
            Text(post.caption!, style: AppTypography.subhead),
          ],
        ],
      ),
    );
  }
}
