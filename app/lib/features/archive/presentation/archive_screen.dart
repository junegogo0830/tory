import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/news_item.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/archive_providers.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsByLocationProvider(locationId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('그 시절 지역 뉴스')),
      body: newsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _RegionStoryCard(locationId: locationId),
                  const EmptyState(
                    icon: Icons.newspaper_outlined,
                    title: '아직 모아둔 뉴스가 없어요',
                    message: '이 지역은 데이터가 적어요. 곧 더 많은 이야기를 채워갈게요.',
                  ),
                ],
              ),
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) return _RegionStoryCard(locationId: locationId);
                return _NewsTimelineCard(item: items[index - 1]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
    );
  }
}

/// Claude가 웹 검색으로 찾아 종합한 "그 시절" 이야기. 뉴스 검색 API가 못 채우는
/// 1990~2000년대 지역 기록을, 첫 방문에서만 (몇 초 걸려) 만들고 그 뒤로는 백엔드가
/// 사실상 영구 캐싱한다 — 못 찾으면 조용히 아무것도 안 보여준다.
class _RegionStoryCard extends ConsumerWidget {
  const _RegionStoryCard({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(regionStoryProvider(locationId));

    return storyAsync.when(
      data: (story) {
        if (story == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, color: AppColors.accentDeep, size: 20),
                    const SizedBox(width: 8),
                    Text('AI가 찾은 이 동네의 그 시절 이야기', style: AppTypography.headline),
                  ],
                ),
                const SizedBox(height: 10),
                Text(story, style: AppTypography.subhead.copyWith(height: 1.6)),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          child: Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Text('AI가 그 시절 기록을 찾아보고 있어요…', style: AppTypography.subhead),
            ],
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _NewsTimelineCard extends StatelessWidget {
  const _NewsTimelineCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.year}',
              style: AppTypography.caption.copyWith(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTypography.headline),
                const SizedBox(height: 4),
                Text(item.summary, style: AppTypography.subhead),
                const SizedBox(height: 6),
                Text(item.source, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
