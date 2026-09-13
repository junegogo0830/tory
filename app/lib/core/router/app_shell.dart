import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// 하단 iOS 탭바를 제공하는 셸. 4개 탭: 추억 / 커뮤니티 / 코스 / 프로필.
/// 예전 "둘러보기" 탭은 커뮤니티 화면 안의 블록(→ `/explore`)으로 옮겨갔다.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '추억'),
              BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: '커뮤니티'),
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '코스'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '프로필'),
            ],
          ),
        ),
      ),
    );
  }
}
