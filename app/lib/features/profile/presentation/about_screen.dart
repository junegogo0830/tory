import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/yetgil_mark.dart';

/// 프로필 "옛길 소개" — 정적 소개 화면.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('옛길 소개')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: YetgilMark(size: 56)),
            const SizedBox(height: 16),
            Text('옛길', style: AppTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '고향의 옛 골목을 다시 걷는 위치 기반 추억 여행 앱',
              style: AppTypography.subhead.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const _AboutCard(
              icon: Icons.compare_outlined,
              title: '그 시절 ↔ 지금',
              body: '고향 주소·학교·살던 아파트를 입력하면 그곳의 과거 거리 모습과 지금 모습을 나란히 비교해요.',
            ),
            const SizedBox(height: 12),
            const _AboutCard(
              icon: Icons.newspaper_outlined,
              title: '그 시절 이야기',
              body: 'AI가 웹에서 찾아 정리한 그 동네의 옛 기록과, 최근 소식을 함께 보여줘요.',
            ),
            const SizedBox(height: 12),
            const _AboutCard(
              icon: Icons.map_outlined,
              title: '오늘의 코스',
              body: '날씨·연령대·관심사에 맞춰 그 동네를 다시 걸어볼 수 있는 코스를 만들어드려요.',
            ),
            const SizedBox(height: 12),
            const _AboutCard(
              icon: Icons.groups_outlined,
              title: '동네 커뮤니티',
              body: '같은 동네 사람들과 추억과 소식을 나누고, 동네 이웃을 찾아보세요.',
            ),
            const SizedBox(height: 24),
            Text(
              '한국관광공사 「2026 관광데이터 활용 공모전」 출품작',
              style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '데이터 제공: 한국관광공사(국문 관광정보 서비스, 관광사진 정보 서비스),\n'
              '카카오맵, 구글 플레이스, 기상청',
              style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accentDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headline),
                const SizedBox(height: 4),
                Text(body, style: AppTypography.footnote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
