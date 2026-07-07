import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/home_providers.dart';

/// 둘러보기 탭: 저장된 골목들을 훑어보고 비교/아카이브로 진입한다.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(recentLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('둘러보기')),
      body: locationsAsync.when(
        data: (locations) => SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: locations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _LocationCard(location: locations[index]),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});

  final HometownLocation location;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location.name, style: AppTypography.headline),
          const SizedBox(height: 2),
          Text(location.region, style: AppTypography.footnote),
          const SizedBox(height: 4),
          Text(location.description, style: AppTypography.subhead),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/compare/${location.id}'),
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('비교'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/archive/${location.id}'),
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('뉴스'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
