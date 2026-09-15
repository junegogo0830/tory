import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/neighbors_greeting_illustration.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/kakao_login_error.dart';
import '../../notifications/data/notification_providers.dart';
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
        Text('프로필', style: AppTypography.title.copyWith(fontSize: 22)),
        const SizedBox(height: 40),
        AppCard(
          child: Column(
            children: [
              const NeighborsGreetingIllustration(),
              const SizedBox(height: 14),
              Text('로그인하고 추억을 저장해보세요', style: AppTypography.headline),
              const SizedBox(height: 6),
              Text(
                '아이디로 가입하거나 카카오 계정으로 간편하게 시작할 수 있어요',
                style: AppTypography.subhead,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('아이디로 로그인'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text('회원가입'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.hairline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('또는', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                  ),
                  Expanded(child: Divider(color: AppColors.hairline)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).loginWithKakao();
                    if (!context.mounted) return;
                    final authState = ref.read(authStateProvider);
                    final loggedIn = authState.value ?? false;
                    if (!loggedIn && authState.hasError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(describeKakaoLoginError(authState.error))),
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
          _ProfileHeader(displayName: profile.displayName),
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
  const _ProfileHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('프로필', style: AppTypography.title.copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text('$displayName님, 오늘도 좋은 하루예요', style: AppTypography.subhead),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/edit-profile'),
          icon: const Icon(Icons.settings_outlined, size: 22),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: profile.profileImageUrl != null
                      ? AppNetworkImage(
                          imageUrl: profile.profileImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => ColoredBox(color: AppColors.surface),
                          errorWidget: (_, _, _) => ColoredBox(
                            color: AppColors.surface,
                            child: const Icon(Icons.person, color: AppColors.accentDeep, size: 36),
                          ),
                        )
                      : ColoredBox(
                          color: AppColors.surface,
                          child: const Icon(Icons.person, color: AppColors.accentDeep, size: 36),
                        ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: AppTypography.title.copyWith(fontSize: 22, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(profile.tagline, style: AppTypography.subhead),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: '등록한 코스',
                  value: '${profile.registeredCourseCount}',
                  onTap: () => context.push('/my-custom-courses'),
                ),
              ),
              const _VerticalLine(),
              Expanded(
                child: _Stat(
                  label: '저장한 코스',
                  value: '${profile.savedCourseCount}',
                  onTap: () => context.push('/saved-courses'),
                ),
              ),
              const _VerticalLine(),
              Expanded(
                child: _Stat(
                  label: '등록한 게시글',
                  value: '${profile.postCount}',
                  onTap: () => context.push(
                    '/my-posts/${profile.userId}?nickname=${Uri.encodeComponent(profile.displayName)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(label, style: AppTypography.footnote),
            const SizedBox(height: 6),
            Text(value, style: AppTypography.largeTitle.copyWith(fontSize: 26)),
          ],
        ),
      ),
    );
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 44, color: AppColors.hairline);
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
        Text('나의 옛길', style: AppTypography.sectionTitle),
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
                Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSecondary),
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
          _MenuRow(
            icon: Icons.map_outlined,
            badgeColor: AppColors.pastelMint,
            label: '내가 만든 코스',
            onTap: () => context.push('/my-courses'),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.camera_alt_outlined,
            badgeColor: AppColors.pastelPeach,
            label: '사진으로 남긴 추억',
            onTap: () => context.push('/my-memories'),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.notifications_none,
            badgeColor: AppColors.pastelSky,
            label: '알림 설정',
            onTap: () => context.push('/notifications'),
            trailing: const _UnreadNotificationBadge(),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.auto_awesome_outlined,
            badgeColor: AppColors.pastelLavender,
            label: '나의 추억 조건 관리',
            onTap: () => context.push('/friends/my-attributes'),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.people_outline,
            badgeColor: AppColors.pastelRose,
            label: '친구·연결 요청',
            onTap: () => context.push('/friends/connections'),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.info_outline,
            badgeColor: AppColors.pastelButter,
            label: '옛길 소개',
            onTap: () => context.push('/about'),
          ),
          const Divider(),
          _MenuRow(
            icon: Icons.logout,
            badgeColor: AppColors.fieldBg,
            label: '로그아웃',
            onTap: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.badgeColor, required this.label, required this.onTap, this.trailing});
  final IconData icon;
  final Color badgeColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.accentDeep, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500))),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

/// 안 읽은 알림 개수 배지 — 0이면 아무것도 안 보여준다.
class _UnreadNotificationBadge extends ConsumerWidget {
  const _UnreadNotificationBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFE0533D), borderRadius: BorderRadius.circular(999)),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surface,
              child: const Icon(Icons.group_outlined, color: AppColors.accentDeep, size: 24),
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

BoxDecoration get _whiteCard => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadius.card),
  boxShadow: AppShadows.card,
);
