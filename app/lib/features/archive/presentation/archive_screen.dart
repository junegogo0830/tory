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
            return const EmptyState(
              icon: Icons.newspaper_outlined,
              title: '아직 모아둔 뉴스가 없어요',
              message: '이 지역은 데이터가 적어요. 곧 더 많은 이야기를 채워갈게요.',
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _NewsTimelineCard(item: items[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
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
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.year}',
              style: AppTypography.caption.copyWith(
                color: AppColors.goldDeep,
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
