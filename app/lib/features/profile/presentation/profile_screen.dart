import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('프로필')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.goldTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.goldDeep),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('게스트', style: AppTypography.headline),
                      Text('로그인하고 추억을 저장해보세요', style: AppTypography.footnote),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MenuRow(icon: Icons.bookmark_outline, label: '저장한 골목'),
                  const Divider(height: 24),
                  _MenuRow(icon: Icons.notifications_none, label: '알림 설정'),
                  const Divider(height: 24),
                  _MenuRow(icon: Icons.info_outline, label: '옛길 소개'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppTypography.body)),
        const Icon(Icons.chevron_right, color: AppColors.inkTertiary),
      ],
    );
  }
}
