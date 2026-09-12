import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/image_proxy.dart';
import '../../../../data/models/restaurant_category.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../data/home_providers.dart';

const double _kHeroHeight = 150;
const double _kHeadlineHeight = 24;
const double _kThumbRowHeight = 100;
const double _kFooterHeight = 28;
const double _kCardHeight = _kHeroHeight + 8 + _kHeadlineHeight + 8 + _kThumbRowHeight + 4 + _kFooterHeight;

/// 지역 뉴스/커뮤니티 사이 "카테고리별 맛집" 발견 카드. 한식/카페/일식/중식/양식
/// 카테고리 하나씩을 야놀자류 프로모션 카드 모양(큰 사진+헤드라인+자세히보기,
/// 밑에 소형 카드 3장)으로 만들어 좌우로 넘겨볼 수 있게 한다.
class RestaurantCategoriesCarousel extends ConsumerStatefulWidget {
  const RestaurantCategoriesCarousel({super.key});

  @override
  ConsumerState<RestaurantCategoriesCarousel> createState() => _RestaurantCategoriesCarouselState();
}

class _RestaurantCategoriesCarouselState extends ConsumerState<RestaurantCategoriesCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(restaurantCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        final page = _page.clamp(0, categories.length - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '관광공사 Pick이 궁금하신가요?',
              style: AppTypography.footnote.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _kCardHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: categories.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _CategoryCard(category: categories[index]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ArrowButton(
                  icon: Icons.chevron_left,
                  onTap: page > 0 ? () => _goTo(page - 1) : null,
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${page + 1} / ${categories.length}',
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                  ),
                ),
                _ArrowButton(
                  icon: Icons.chevron_right,
                  onTap: page < categories.length - 1 ? () => _goTo(page + 1) : null,
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppShadows.tile,
        ),
        child: Icon(icon, size: 20, color: onTap == null ? AppColors.inkTertiary : AppColors.ink),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final RestaurantCategory category;

  @override
  Widget build(BuildContext context) {
    final hero = category.items.first;
    final thumbs = category.items.skip(1).take(3).toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kHeroHeight,
            width: double.infinity,
            child: hero.imageUrl == null
                ? const PhotoFallback()
                : CachedNetworkImage(
                    imageUrl: resolveImageUrl(hero.imageUrl!),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const PhotoFallback(),
                    errorWidget: (_, _, _) => const PhotoFallback(),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _kHeadlineHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  category.headline,
                  style: AppTypography.headline.copyWith(color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _kThumbRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  for (var i = 0; i < thumbs.length; i++) ...[
                    if (i != 0) const SizedBox(width: 8),
                    Expanded(child: _ThumbCard(item: thumbs[i])),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _kFooterHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/restaurants/${Uri.encodeComponent(category.category)}'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.inkSecondary,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('자세히보기', style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                      const Icon(Icons.chevron_right, size: 14, color: AppColors.inkSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbCard extends StatelessWidget {
  const _ThumbCard({required this.item});

  final RestaurantItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/compare/${item.id}'),
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: SizedBox(
              height: 72,
              width: double.infinity,
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
          const SizedBox(height: 4),
          Text(
            item.name,
            style: AppTypography.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
