import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/image_proxy.dart';
import '../../../../data/models/highlight_card.dart';
import '../../../../shared/widgets/photo_fallback.dart';
import '../../data/home_providers.dart';

/// TourAPI 기반 인기 장소 카드를 4초마다 오른쪽에서 왼쪽으로 슬라이드하며
/// 보여준다. 다른 앱들의 "혜택 카드" 배너st 느낌이되, 카드 자체는 컴팩트하게
/// (예전 큰 장소 카드처럼 "기능 없이 크기만 한" 인상을 주지 않도록).
class HighlightCarousel extends ConsumerStatefulWidget {
  const HighlightCarousel({super.key});

  @override
  ConsumerState<HighlightCarousel> createState() => _HighlightCarouselState();
}

class _HighlightCarouselState extends ConsumerState<HighlightCarousel> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(highlightCardsProvider);

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        final card = cards[_index % cards.length];
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previousChildren, ?currentChild],
          ),
          child: _HighlightCardTile(key: ValueKey(card.id), card: card),
        );
      },
      loading: () => const SizedBox(height: 84),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HighlightCardTile extends StatelessWidget {
  const _HighlightCardTile({super.key, required this.card});

  final HighlightCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push('/compare/${card.id}'),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.card)),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: CachedNetworkImage(
                    imageUrl: resolveImageUrl(card.imageUrl),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const PhotoFallback(),
                    errorWidget: (_, _, _) => const PhotoFallback(),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.pastelSky,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          card.category,
                          style: AppTypography.caption.copyWith(color: AppColors.accentDeep),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote,
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.chevron_right, color: AppColors.inkTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
