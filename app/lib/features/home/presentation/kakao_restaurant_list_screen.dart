import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/kakao_restaurant.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/home_providers.dart';

/// 카카오맵 기반 맛집 "자세히보기" 화면. lat/lng이 주어지면 그 위치 기준 반경
/// 5km 내 맛집(내 주변 모드), 없으면 주요 도시 풀(전국 모드)을 보여준다.
/// 카카오 로컬 API엔 사진이 없어 텍스트 정보(이름/카테고리/주소/거리)만 있다.
class KakaoRestaurantListScreen extends ConsumerWidget {
  const KakaoRestaurantListScreen({super.key, this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNearby = lat != null && lng != null;
    final restaurantsAsync = isNearby
        ? ref.watch(kakaoRestaurantsNearbyProvider((lat: lat!, lng: lng!)))
        : ref.watch(kakaoRestaurantsNationwideProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(isNearby ? '내 주변 맛집' : '전국 맛집')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: restaurantsAsync.when(
              data: (restaurants) {
                if (restaurants.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: '맛집을 찾지 못했어요',
                    message: '잠시 후 다시 시도해주세요.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _RestaurantRow(item: restaurants[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({required this.item});

  final KakaoRestaurant item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: const Icon(Icons.restaurant, color: AppColors.accentDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(item.category, style: AppTypography.caption.copyWith(color: AppColors.accentDeep)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.distanceM != null ? '${item.address} · ${item.distanceM}m' : item.address,
                  style: AppTypography.footnote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
