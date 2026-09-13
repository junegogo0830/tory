import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_colors.dart';
import '../../../../data/models/kakao_restaurant.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/home_providers.dart';

enum _KakaoRestaurantMode { nationwide, nearby }

const int _kGroupSize = 3;

/// 카카오맵 기반 맛집 추천 카드 — "전국"/"내 주변" 두 버튼으로 내용이 바뀌고,
/// 한 번에 3개씩 애니메이션처럼 넘어간다. 카카오 로컬 API 자체엔 사진이 없어서,
/// 같은 이름으로 TourAPI에 등록된 사진이 있으면 그걸 쓰고, 없으면 카테고리별
/// 파스텔 아이콘 배지로 밋밋해 보이지 않게 했다.
class KakaoRestaurantCard extends ConsumerStatefulWidget {
  const KakaoRestaurantCard({super.key});

  @override
  ConsumerState<KakaoRestaurantCard> createState() => _KakaoRestaurantCardState();
}

class _KakaoRestaurantCardState extends ConsumerState<KakaoRestaurantCard> {
  _KakaoRestaurantMode _mode = _KakaoRestaurantMode.nationwide;
  Position? _position;
  bool _isLocating = false;
  String? _locationError;

  Timer? _timer;
  int _index = 0;
  int _itemCount = 0;

  void _ensureTimer(int itemCount) {
    if (itemCount == _itemCount && _timer != null) return;
    _itemCount = itemCount;
    _index = 0;
    _timer?.cancel();
    if (itemCount <= _kGroupSize) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index = (_index + _kGroupSize) % _itemCount);
    });
  }

  Future<void> _selectNearby() async {
    setState(() => _mode = _KakaoRestaurantMode.nearby);
    if (_position != null || _isLocating) return;

    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationError = '위치 권한이 필요해요');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationError = '기기의 위치 서비스를 켜주세요');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      if (mounted) setState(() => _locationError = '위치를 가져오지 못했어요');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('카카오맵 맛집 추천', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w600)),
              ),
              _ModeButton(
                label: '전국',
                selected: _mode == _KakaoRestaurantMode.nationwide,
                onTap: () => setState(() => _mode = _KakaoRestaurantMode.nationwide),
              ),
              const SizedBox(width: 6),
              _ModeButton(
                label: '내 주변',
                selected: _mode == _KakaoRestaurantMode.nearby,
                onTap: _selectNearby,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: _mode == _KakaoRestaurantMode.nationwide ? _buildNationwide() : _buildNearby(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final position = _position;
                final path = _mode == _KakaoRestaurantMode.nearby && position != null
                    ? '/kakao-restaurants?lat=${position.latitude}&lng=${position.longitude}'
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
      data: (restaurants) => _RestaurantTickerGroup(
        restaurants: restaurants,
        index: _index,
        onCountResolved: _ensureTimer,
        emptyMessage: '전국 맛집 정보를 불러오지 못했어요',
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.footnote)),
    );
  }

  Widget _buildNearby() {
    if (_isLocating) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_locationError != null) {
      return Center(child: Text(_locationError!, style: AppTypography.footnote));
    }
    final position = _position;
    if (position == null) return const SizedBox.shrink();

    final restaurantsAsync = ref.watch(
      kakaoRestaurantsNearbyProvider((lat: position.latitude, lng: position.longitude)),
    );
    return restaurantsAsync.when(
      data: (restaurants) => _RestaurantTickerGroup(
        restaurants: restaurants,
        index: _index,
        onCountResolved: _ensureTimer,
        emptyMessage: '반경 5km 안에 등록된 맛집이 없어요',
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.footnote)),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

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
          color: selected ? AppColors.accent : AppColors.paper,
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

/// 한 번에 3개씩 보여주는 그룹 — 사진이 없는 항목은 카테고리별 파스텔 아이콘
/// 배지 + 옅은 그림자로 밋밋해 보이지 않게 카드감을 살렸다.
class _RestaurantTickerGroup extends StatelessWidget {
  const _RestaurantTickerGroup({
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

    final groupSize = math.min(_kGroupSize, restaurants.length);
    final group = List.generate(groupSize, (i) => restaurants[(index + i) % restaurants.length]);

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
        child: Row(
          key: ValueKey(group.first.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < group.length; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              Expanded(child: _RestaurantChip(item: group[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestaurantChip extends StatelessWidget {
  const _RestaurantChip({required this.item});

  final KakaoRestaurant item;

  Widget _iconBadge() {
    final color = pastelForFoodCategory(item.category);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Icon(iconForFoodCategory(item.category), size: 17, color: AppColors.ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        boxShadow: AppShadows.tile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl == null)
            _iconBadge()
          else
            SizedBox(
              width: 32,
              height: 32,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _iconBadge(),
                  errorWidget: (_, _, _) => _iconBadge(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(item.name, style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            item.distanceM != null ? '${item.distanceM}m' : item.address,
            style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
