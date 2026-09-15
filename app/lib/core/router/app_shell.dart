import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/data/profile_providers.dart';
import '../theme/app_colors.dart';

/// 하단 iOS 탭바를 제공하는 셸. 4개 탭: 추억 / 커뮤니티 / 코스 / 프로필.
/// 예전 "둘러보기" 탭은 커뮤니티 화면 안의 블록(→ `/explore`)으로 옮겨갔다.
///
/// 로그인 상태가 되면(카카오든 자체 회원가입이든, 어느 탭에서 로그인했든) 여기서
/// profile.onboardingCompleted를 확인해 첫 로그인 온보딩 화면을 한 번 띄운다 —
/// AppShell은 로그인 이후 항상 떠 있는 화면이라 진입 지점이 어디든 여기 한
/// 곳에서만 처리하면 된다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _onboardingChecked = false;

  Future<void> _maybeShowOnboarding() async {
    if (_onboardingChecked || !mounted) return;
    _onboardingChecked = true;

    final engaged = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const OnboardingScreen()),
    );
    if (!mounted) return;

    // 거주지나 살았던 곳을 채웠으면 곧장 다음 액션(글쓰기)으로 이어지도록 살짝 더 안내한다.
    if (engaged == true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('첫 이야기를 남겨볼까요?'),
          content: const Text('커뮤니티에서 동네 사람들과 그 시절 추억을 나눠보세요.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('나중에')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/community');
              },
              child: const Text('커뮤니티 가기'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isLoggedIn = authAsync.value ?? false;

    if (!isLoggedIn) {
      _onboardingChecked = false; // 로그아웃하면 다음 로그인 때 다시 체크한다.
    } else {
      final profileAsync = ref.watch(profileProvider);
      profileAsync.whenData((profile) {
        if (!profile.onboardingCompleted && !_onboardingChecked) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
        }
      });
    }

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
            // 비활성은 outlined, 활성은 filled로 통일 — 예전엔 홈만 filled라
            // 아이콘 스타일이 섞여 보였다.
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: '추억',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_outlined),
                activeIcon: Icon(Icons.groups_rounded),
                label: '커뮤니티',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map_rounded),
                label: '코스',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: '프로필',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
