import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_proxy.dart';
import '../../../data/models/restaurant_category.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';

/// "자세히보기"로 들어오는 카테고리 맛집 전체 목록. 처음엔 그 카테고리의 전국
/// 맛집을 보여주고, 상단 "내 주변" 버튼을 누르면 현재 위치 기반 주변 맛집으로
/// 바뀐다(카테고리 구분 없이 — 위치 반경 안 실제 음식점 전체).
class CategoryRestaurantListScreen extends ConsumerStatefulWidget {
  const CategoryRestaurantListScreen({super.key, required this.category});

  final String category;

  @override
  ConsumerState<CategoryRestaurantListScreen> createState() => _CategoryRestaurantListScreenState();
}

class _CategoryRestaurantListScreenState extends ConsumerState<CategoryRestaurantListScreen> {
  bool _nearbyMode = false;
  bool _isLoading = true;
  List<RestaurantItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    setState(() {
      _isLoading = true;
      _nearbyMode = false;
    });
    try {
      final items = await ref.read(discoveryRepositoryProvider).getRestaurantsByCategory(widget.category);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNearby() async {
    setState(() => _isLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한이 필요해요');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('기기의 위치 서비스를 켜주세요');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final items = await ref
          .read(discoveryRepositoryProvider)
          .getRestaurantsNearby(lat: position.latitude, lng: position.longitude);
      if (!mounted) return;
      setState(() {
        _items = items;
        _nearbyMode = true;
      });
    } catch (_) {
      _showMessage('위치를 가져오지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('${widget.category} 맛집')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _nearbyMode ? '내 주변 맛집' : '전국 ${widget.category} 맛집',
                          style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _nearbyMode ? _loadCategory : _loadNearby,
                        icon: Icon(_nearbyMode ? Icons.restaurant_menu : Icons.location_searching, size: 16),
                        label: Text(_nearbyMode ? '카테고리로 보기' : '내 주변으로 보기'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: AppTypography.caption,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _items.isEmpty
                          ? EmptyState(
                              icon: Icons.restaurant_outlined,
                              title: '맛집을 찾지 못했어요',
                              message: _nearbyMode ? '이 근처는 아직 등록된 맛집이 부족해요.' : '잠시 후 다시 시도해주세요.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _RestaurantRow(item: _items[index]),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({required this.item});

  final RestaurantItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/compare/${item.id}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl == null
                  ? const PhotoFallback()
                  : CachedNetworkImage(
                      imageUrl: resolveImageUrl(item.imageUrl!),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const PhotoFallback(),
                      errorWidget: (_, _, _) => const PhotoFallback(),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.region, style: AppTypography.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkTertiary),
        ],
      ),
    );
  }
}
