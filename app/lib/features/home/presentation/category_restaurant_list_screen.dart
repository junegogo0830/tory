import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/restaurant_category.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_attribution_badge.dart';
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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
                          // 항목마다 카드를 띄우는 대신 흰 컨테이너 하나 안에 줄로
                          // 나열한다 — 같은 카드 수십 장이 반복되면 템플릿처럼 보인다.
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              children: [
                                AppCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < _items.length; i++) ...[
                                        _RestaurantRow(item: _items[i]),
                                        if (i != _items.length - 1)
                                          Divider(height: 1, indent: 86, endIndent: 14, color: AppColors.hairline),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
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
    return InkWell(
      onTap: () => context.push('/compare/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl == null
                        ? const PhotoFallback()
                        : AppNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const PhotoFallback(),
                            errorWidget: (_, _, _) => const PhotoFallback(),
                          ),
                    if (item.photoAttributionName != null)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: PhotoAttributionBadge(
                          name: item.photoAttributionName,
                          url: item.photoAttributionUrl,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(item.region, style: AppTypography.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}
