import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// "자세히보기"로 들어오는 관광공사 Pick 카테고리 맛집 전체 목록(전국).
/// 위치 기반 "내 주변" 보기는 별도의 카카오맵 기반 맛집 카드/화면으로 옮겨서
/// 여기서는 뺐다.
class CategoryRestaurantListScreen extends ConsumerStatefulWidget {
  const CategoryRestaurantListScreen({super.key, required this.category});

  final String category;

  @override
  ConsumerState<CategoryRestaurantListScreen> createState() => _CategoryRestaurantListScreenState();
}

class _CategoryRestaurantListScreenState extends ConsumerState<CategoryRestaurantListScreen> {
  bool _isLoading = true;
  List<RestaurantItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '관광공사 Pick · 전국 ${widget.category} 맛집',
                      style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _items.isEmpty
                          ? const EmptyState(
                              icon: Icons.restaurant_outlined,
                              title: '맛집을 찾지 못했어요',
                              message: '잠시 후 다시 시도해주세요.',
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
