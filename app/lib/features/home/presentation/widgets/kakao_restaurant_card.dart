import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_colors.dart';
import '../../../../core/utils/kakao_map_links.dart';
import '../../../../data/models/kakao_restaurant.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/photo_attribution_badge.dart';
import '../../data/home_providers.dart';
import 'restaurant_cuisine_filter.dart';

enum _KakaoRestaurantMode { nationwide, region }

/// 카카오맵 기반 맛집 추천 카드 — "전국"/"지역" 두 버튼으로 내용이 바뀐다.
/// "지역"은 GPS 대신 사용자가 직접 고르는 7개 광역권을 히어로 배너처럼 좌우로
/// 넘겨보고, 그 안에서 카테고리 토글(한식/중식/일식/양식/디저트)로 좁힌다.
/// 카카오 로컬 API 자체엔 사진이 없어서, 같은 이름으로 TourAPI에 등록된 사진이
/// 있으면 그걸 쓰고, 없으면 카테고리별 이모지 배지로 밋밋해 보이지 않게 했다.
class KakaoRestaurantCard extends ConsumerStatefulWidget {
  const KakaoRestaurantCard({super.key});

  @override
  ConsumerState<KakaoRestaurantCard> createState() => _KakaoRestaurantCardState();
}

class _KakaoRestaurantCardState extends ConsumerState<KakaoRestaurantCard> {
  _KakaoRestaurantMode _mode = _KakaoRestaurantMode.nationwide;
  final _regionController = PageController();
  int _regionIndex = 0;
  String? _cuisine; // null == 전체

  Timer? _timer;
  int _index = 0;
  int _itemCount = 0;

  String get _region => kakaoRestaurantRegions[_regionIndex];

  void _ensureTimer(int itemCount) {
    // 이 콜백은 addPostFrameCallback으로 예약돼서, 위젯이 그 사이 dispose된
    // 뒤에도 뒤늦게 호출될 수 있다 — 그때 새 Timer를 또 만들면 아무도 취소
    // 안 하는 좀비 타이머가 남는다.
    if (!mounted) return;
    if (itemCount == _itemCount && _timer != null) return;
    _itemCount = itemCount;
    _index = 0;
    _timer?.cancel();
    if (itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _itemCount);
    });
  }

  void _goToRegion(int index) {
    _regionController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('카카오맵 맛집 추천', style: AppTypography.headline.copyWith(fontWeight: FontWeight.w700)),
              ),
              _Segmented(
                left: '전국',
                right: '지역',
                selectedLeft: _mode == _KakaoRestaurantMode.nationwide,
                onSelectLeft: () => setState(() => _mode = _KakaoRestaurantMode.nationwide),
                onSelectRight: () => setState(() => _mode = _KakaoRestaurantMode.region),
              ),
            ],
          ),
          if (_mode == _KakaoRestaurantMode.region) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _ArrowButton(icon: Icons.chevron_left, onTap: _regionIndex > 0 ? () => _goToRegion(_regionIndex - 1) : null),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: PageView.builder(
                      controller: _regionController,
                      itemCount: kakaoRestaurantRegions.length,
                      onPageChanged: (i) => setState(() => _regionIndex = i),
                      itemBuilder: (context, i) => Center(
                        child: Text(
                          kakaoRestaurantRegions[i],
                          style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.accentDeep),
                        ),
                      ),
                    ),
                  ),
                ),
                _ArrowButton(
                  icon: Icons.chevron_right,
                  onTap: _regionIndex < kakaoRestaurantRegions.length - 1 ? () => _goToRegion(_regionIndex + 1) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            RestaurantCuisineFilter(selected: _cuisine, onSelect: (c) => setState(() => _cuisine = c)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: _mode == _KakaoRestaurantMode.nationwide ? _buildNationwide() : _buildRegion(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final path = _mode == _KakaoRestaurantMode.region
                    ? '/kakao-restaurants?region=$_region${_cuisine != null ? '&cuisine=$_cuisine' : ''}'
                    : '/kakao-restaurants';
                context.push(path);
              },
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
                  Icon(Icons.chevron_right, size: 14, color: AppColors.inkSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNationwide() {
    final restaurantsAsync = ref.watch(kakaoRestaurantsNationwideProvider);
    return restaurantsAsync.when(
      data: (restaurants) => _RestaurantTicker(
        restaurants: restaurants,
        index: _index,
        onCountResolved: _ensureTimer,
        emptyMessage: '전국 맛집 정보를 불러오지 못했어요',
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.footnote)),
    );
  }

  Widget _buildRegion() {
    final restaurantsAsync = ref.watch(kakaoRestaurantsByRegionProvider(_region));
    return restaurantsAsync.when(
      data: (restaurants) {
        final filtered = _cuisine == null ? restaurants : restaurants.where((r) => r.cuisine == _cuisine).toList();
        return _RestaurantTicker(
          restaurants: filtered,
          index: _index,
          onCountResolved: _ensureTimer,
          emptyMessage: '$_region에 등록된 맛집이 없어요',
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.footnote)),
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
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.inkTertiary : AppColors.ink),
      ),
    );
  }
}

/// "전국 / 지역" 두 옵션을 한 트랙 안에 이어붙인 segmented control.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.selectedLeft,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  final String left;
  final String right;
  final bool selectedLeft;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedOption(label: left, selected: selectedLeft, onTap: onSelectLeft),
          _SegmentedOption(label: right, selected: !selectedLeft, onTap: onSelectRight),
        ],
      ),
    );
  }
}

class _SegmentedOption extends StatelessWidget {
  const _SegmentedOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.surface : AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 한 번에 하나씩 보여주는 티커 — 사진이 없는 항목은 카테고리별 이모지
/// 배지 + 옅은 그림자로 밋밋해 보이지 않게 카드감을 살렸다.
class _RestaurantTicker extends StatelessWidget {
  const _RestaurantTicker({
    required this.restaurants,
    required this.index,
    required this.onCountResolved,
    required this.emptyMessage,
  });

  final List<KakaoRestaurant> restaurants;
  final int index;
  final ValueChanged<int> onCountResolved;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) {
      return Center(child: Text(emptyMessage, style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary)));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => onCountResolved(restaurants.length));

    final item = restaurants[index % restaurants.length];

    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: _RestaurantSingle(key: ValueKey(item.id), item: item),
      ),
    );
  }
}

class _RestaurantSingle extends StatelessWidget {
  const _RestaurantSingle({super.key, required this.item});

  final KakaoRestaurant item;

  Widget _emojiBadge() {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pastelForFoodCategory(item.category),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(emojiForFoodCategory(item.category), style: const TextStyle(fontSize: 30)),
    );
  }

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
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final hasPlacePage = item.placeUrl != null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      onTap: hasPlacePage ? _openPlacePage : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (imageUrl == null)
              _emojiBadge()
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _emojiBadge(),
                        errorWidget: (_, _, _) => _emojiBadge(),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.headline.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: pastelForFoodCategory(item.category),
                      borderRadius: BorderRadius.circular(AppRadius.tag),
                    ),
                    child: Text(
                      item.category,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.address,
                    style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item.phone != null) ...[
              const SizedBox(width: 6),
              _IconActionButton(icon: Icons.call_outlined, onTap: _call),
            ],
            if (item.hasCoordinates) ...[
              const SizedBox(width: 6),
              _IconActionButton(
                icon: Icons.directions,
                onTap: () => openKakaoMapDirections(
                  name: item.name,
                  latitude: item.latitude!,
                  longitude: item.longitude!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.iconChipBg, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: AppColors.iconChipFg),
      ),
    );
  }
}
