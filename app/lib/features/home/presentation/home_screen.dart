import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/feature_shortcut_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/yetgil_mark.dart';
import '../data/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                const YetgilMark(size: 30),
                const SizedBox(width: 10),
                Text('옛길', style: AppTypography.largeTitle),
              ],
            ),
            const SizedBox(height: 20),
            _EntryCard(controller: _queryController),
            const SizedBox(height: 28),
            SectionHeader(title: '무엇을 해볼까요'),
            const SizedBox(height: 12),
            _ShortcutRow(),
            const SizedBox(height: 28),
            SectionHeader(title: '최근 둘러본 골목'),
            const SizedBox(height: 12),
            recentAsync.when(
              data: (locations) => _RecentLocationList(locations: locations),
              loading: () => const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              ),
              error: (error, stack) => AppCard(
                child: Text('최근 골목을 불러오지 못했어요', style: AppTypography.subhead),
              ),
            ),
            const SizedBox(height: 28),
            _RecommendationBanner(),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('그때 그 골목이 궁금하다면', style: AppTypography.headline),
          const SizedBox(height: 4),
          Text(
            '고향 주소, 학교, 살던 아파트를 입력해보세요',
            style: AppTypography.subhead,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '예: 전라남도 순천시 전포동',
              prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.inkTertiary),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // MVP: 목 데이터의 첫 장소로 이동. 실제 구현에서는 지오코딩 결과 사용.
                context.push('/compare/suncheon-jeonpo');
              },
              child: const Text('그 시절 거리로 떠나기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shortcuts = <Widget>[
      FeatureShortcutTile(
        icon: Icons.compare_arrows,
        label: '비교',
        onTap: () => context.push('/compare/suncheon-jeonpo'),
      ),
      FeatureShortcutTile(
        icon: Icons.article_outlined,
        label: '뉴스',
        onTap: () => context.push('/archive/suncheon-jeonpo'),
      ),
      FeatureShortcutTile(
        icon: Icons.route_outlined,
        label: '코스',
        onTap: () => context.go('/course'),
      ),
      FeatureShortcutTile(
        icon: Icons.map_outlined,
        label: '지도',
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지도 기능은 준비 중이에요')),
        ),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < shortcuts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: shortcuts[i]),
        ],
      ],
    );
  }
}

class _RecentLocationList extends StatelessWidget {
  const _RecentLocationList({required this.locations});

  final List<HometownLocation> locations;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return AppCard(
        child: Text('아직 둘러본 골목이 없어요', style: AppTypography.subhead),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final location = locations[index];
          return SizedBox(
            width: 180,
            child: AppCard(
              onTap: () => context.push('/compare/${location.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.name, style: AppTypography.headline),
                  const SizedBox(height: 4),
                  Text(location.region, style: AppTypography.footnote),
                  const Spacer(),
                  Text(
                    '${location.pastYear} → ${location.currentYear}',
                    style: AppTypography.caption.copyWith(color: AppColors.goldDeep),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecommendationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/course'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.goldTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.goldDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('감성분석 기반 추천 코스', style: AppTypography.headline),
                const SizedBox(height: 2),
                Text('요즘 방문객들이 좋아하는 코스를 확인해보세요', style: AppTypography.footnote),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkTertiary),
        ],
      ),
    );
  }
}
