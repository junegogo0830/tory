import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/home_providers.dart';

const _regions = ['전체', '전라', '경상', '강원', '서울'];

/// 둘러보기 탭: 저장된 골목들을 지역별로 훑어보고 비교/아카이브로 진입한다.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int selectedRegion = 0;

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(allLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: locationsAsync.when(
              data: (locations) {
                final regionKeyword = _regions[selectedRegion];
                final filtered = regionKeyword == '전체'
                    ? locations
                    : locations.where((l) => l.region.contains(regionKeyword)).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
                  children: [
                    const _Header(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _regions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => ChoiceChip(
                          label: Text(_regions[index]),
                          selected: selectedRegion == index,
                          onSelected: (_) => setState(() => selectedRegion = index),
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.surface,
                          side: BorderSide.none,
                          showCheckmark: false,
                          labelStyle: AppTypography.body.copyWith(
                            color: selectedRegion == index ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.explore_off_outlined,
                        title: '해당 지역의 골목이 아직 없어요',
                        message: '다른 지역을 선택해보세요.',
                      )
                    else ...[
                      Row(
                        children: [
                          const Icon(Icons.star_outline, color: AppColors.accentDeep, size: 27),
                          const SizedBox(width: 8),
                          Text('이번 주 추천 골목', style: AppTypography.title),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < filtered.length; i++) ...[
                        _PlaceCard(location: filtered[i]),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(
                child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('둘러보기', style: AppTypography.largeTitle.copyWith(fontSize: 34)),
        const SizedBox(height: 4),
        Text('추억이 머무는 동네를 둘러보세요', style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.location});
  final HometownLocation location;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 560;
          final imageWidget = Stack(
            fit: StackFit.expand,
            children: [
              location.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: location.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const PhotoFallback(),
                      placeholder: (_, _) => const PhotoFallback(),
                    )
                  : const PhotoFallback(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0x45000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          );
          final detail = _PlaceDetail(location: location);
          if (horizontal) {
            return SizedBox(
              height: 250,
              child: Row(
                children: [Expanded(flex: 4, child: imageWidget), Expanded(flex: 6, child: detail)],
              ),
            );
          }
          return Column(
            children: [SizedBox(height: 210, width: double.infinity, child: imageWidget), detail],
          );
        },
      ),
    );
  }
}

class _PlaceDetail extends ConsumerWidget {
  const _PlaceDetail({required this.location});
  final HometownLocation location;

  Future<void> _toggleSave(BuildContext context, WidgetRef ref, bool isLoggedIn, bool isSaved) async {
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하려면 먼저 로그인해주세요 (프로필 탭)')),
      );
      return;
    }
    final repo = ref.read(profileRepositoryProvider);
    if (isSaved) {
      await repo.unsaveLocation(location.id);
    } else {
      await repo.saveLocation(location.id);
    }
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authStateProvider).value ?? false;
    final profileAsync = isLoggedIn ? ref.watch(profileProvider) : null;
    final isSaved = profileAsync?.value?.savedLocations.any((l) => l.id == location.id) ?? false;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: Text(location.name, style: AppTypography.title.copyWith(fontSize: 23))),
              InkWell(
                onTap: () => _toggleSave(context, ref, isLoggedIn, isSaved),
                child: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: AppColors.accentDeep,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(location.region, style: AppTypography.subhead.copyWith(color: AppColors.accentDeep)),
          const SizedBox(height: 12),
          Text(location.description, style: AppTypography.subhead.copyWith(height: 1.55)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/compare/${location.id}'),
                  icon: const Icon(Icons.compare, size: 17),
                  label: const Text('과거와 비교'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/archive/${location.id}'),
                  icon: const Icon(Icons.newspaper_outlined, size: 17),
                  label: const Text('그 시절 뉴스'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
