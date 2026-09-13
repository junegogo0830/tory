import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/kakao_restaurant.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/home_providers.dart';

/// 카카오맵 기반 맛집 "자세히보기" 화면. lat/lng이 주어지면 그 위치 기준
/// 걸어갈 만한 반경부터 넓혀가며 찾은 맛집(내 주변 모드), 없으면 주요 도시
/// 풀(전국 모드)을 보여준다.
///
/// 카카오 로컬 API 자체엔 평점·리뷰 수가 없어 우리가 "몇 점/몇 개 리뷰"를
/// 보여줄 수 없다 — 대신 카드를 누르면 실제 평점·리뷰가 있는 카카오맵 원본
/// 페이지로 이동한다. 전화번호가 있으면 바로 걸 수도 있다.
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

  Future<void> _openPlacePage() async {
    final url = item.placeUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final phone = item.phone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final hasPlacePage = item.placeUrl != null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: hasPlacePage ? _openPlacePage : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (imageUrl == null)
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                  child: const Icon(Icons.restaurant, color: AppColors.accentDeep),
                )
              else
                SizedBox(
                  width: 44,
                  height: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    child: AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  ),
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
          if (item.phone != null || hasPlacePage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.phone != null) ...[
                  _ActionChip(icon: Icons.call_outlined, label: item.phone!, onTap: _call),
                  const SizedBox(width: 8),
                ],
                if (hasPlacePage)
                  const _ActionChip(icon: Icons.map_outlined, label: '카카오맵에서 리뷰 보기'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: content);
  }
}
