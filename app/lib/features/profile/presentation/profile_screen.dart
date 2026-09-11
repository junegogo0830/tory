import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/data/auth_providers.dart';
import '../data/profile_providers.dart';

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('아직 준비 중인 기능이에요')),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: authAsync.when(
              data: (isLoggedIn) => isLoggedIn ? const _LoggedInProfile() : const _GuestProfile(),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => const _GuestProfile(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestProfile extends ConsumerWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
      children: [
        Text('프로필', style: AppTypography.largeTitle.copyWith(fontSize: 34)),
        const SizedBox(height: 40),
        AppCard(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, color: AppColors.accentDeep, size: 32),
              ),
              const SizedBox(height: 16),
              Text('로그인하고 추억을 저장해보세요', style: AppTypography.headline),
              const SizedBox(height: 6),
              Text(
                '카카오 계정으로 간편하게 시작할 수 있어요',
                style: AppTypography.subhead,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).loginWithKakao();
                    final loggedIn = ref.read(authStateProvider).value ?? false;
                    if (!context.mounted) return;
                    if (!loggedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('카카오 로그인에 실패했어요. 다시 시도해주세요.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('카카오로 시작하기'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEE500), foregroundColor: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoggedInProfile extends ConsumerWidget {
  const _LoggedInProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 22),
          _MemberCard(profile: profile),
          const SizedBox(height: 28),
          _SavedPlaces(profile: profile),
          const SizedBox(height: 22),
          const _MenuCard(),
          const SizedBox(height: 18),
          const _FamilyBanner(),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(
        child: Text('프로필을 불러오지 못했어요', style: AppTypography.subhead),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('프로필', style: AppTypography.largeTitle.copyWith(fontSize: 34))),
        IconButton(
          onPressed: () => _showComingSoon(context),
          icon: const Icon(Icons.settings_outlined, size: 31),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.accentDeep, size: 36),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: AppTypography.title.copyWith(fontSize: 24)),
                    const SizedBox(height: 5),
                    Text(profile.tagline, style: AppTypography.subhead),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          Row(
            children: [
              Expanded(child: _Stat(label: '저장한 골목', value: '${profile.savedLocationsCount}')),
              const _VerticalLine(),
              Expanded(child: _Stat(label: '완주한 코스', value: '${profile.completedCoursesCount}')),
              const _VerticalLine(),
              Expanded(child: _Stat(label: '추억 사진', value: '${profile.memoryPhotoCount}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTypography.subhead.copyWith(color: AppColors.ink)),
        const SizedBox(height: 6),
        Text(value, style: AppTypography.largeTitle.copyWith(fontSize: 30)),
      ],
    );
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 55, color: AppColors.hairline);
}

class _SavedPlaces extends ConsumerWidget {
  const _SavedPlaces({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile.savedLocations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나의 옛길', style: AppTypography.title.copyWith(fontSize: 25)),
          const SizedBox(height: 10),
          Text('둘러보기에서 마음에 드는 골목을 저장해보세요', style: AppTypography.subhead),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('나의 옛길', style: AppTypography.title.copyWith(fontSize: 25)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < profile.savedLocations.length; i++) ...[
              if (i > 0) const SizedBox(width: 13),
              Expanded(
                child: _SavedPlaceCard(
                  place: profile.savedLocations[i],
                  onUnsave: () async {
                    await ref.read(profileRepositoryProvider).unsaveLocation(profile.savedLocations[i].id);
                    ref.invalidate(profileProvider);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({required this.place, required this.onUnsave});
  final SavedLocationSummary place;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _whiteCard,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.headline),
                ),
                InkWell(
                  onTap: onUnsave,
                  child: const Icon(Icons.bookmark, color: AppColors.accent, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSecondary),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(place.region, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: _whiteCard,
      child: Column(
        children: [
          _MenuRow(icon: Icons.map_outlined, label: '내가 만든 코스', onTap: () => _showComingSoon(context)),
          const Divider(),
          _MenuRow(icon: Icons.camera_alt_outlined, label: '사진으로 남긴 추억', onTap: () => _showComingSoon(context)),
          const Divider(),
          _MenuRow(icon: Icons.notifications_none, label: '알림 설정', onTap: () => _showComingSoon(context)),
          const Divider(),
          _MenuRow(icon: Icons.info_outline, label: '옛길 소개', onTap: () => _showComingSoon(context)),
          const Divider(),
          _MenuRow(
            icon: Icons.logout,
            label: '로그아웃',
            onTap: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentDeep, size: 25),
            const SizedBox(width: 15),
            Expanded(child: Text(label, style: AppTypography.body)),
            const Icon(Icons.chevron_right, color: AppColors.inkSecondary),
          ],
        ),
      ),
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showComingSoon(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.group_outlined, color: AppColors.accentDeep, size: 29),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('가족과 추억을 공유해보세요', style: AppTypography.headline),
                  const SizedBox(height: 3),
                  Text('함께한 추억 여행을 더 특별하게 간직할 수 있어요.', style: AppTypography.footnote),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.accentDeep),
          ],
        ),
      ),
    );
  }
}

const _whiteCard = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(19)),
  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7))],
);
