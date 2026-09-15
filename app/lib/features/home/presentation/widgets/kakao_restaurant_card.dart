import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
import '../../data/home_providers.dart';

enum _KakaoRestaurantMode { nationwide, nearby }

/// 카카오맵 기반 맛집 추천 카드 — "전국"/"내 주변" 두 버튼으로 내용이 바뀌고,
/// 한 번에 하나씩 애니메이션처럼 넘어간다. 카카오 로컬 API 자체엔 사진이 없어서,
/// 같은 이름으로 TourAPI에 등록된 사진이 있으면 그걸 쓰고, 없으면 카테고리별
/// 이모지 배지로 밋밋해 보이지 않게 했다.
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
    if (itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _itemCount);
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
              // 전국/내 주변 — 실제 GUI의 segmented control처럼 하나의 트랙
              // 안에서 좌우로 붙여 하나의 컨트롤처럼 보이게 한다.
              _Segmented(
                left: '전국',
                right: '내 주변',
                selectedLeft: _mode == _KakaoRestaurantMode.nationwide,
                onSelectLeft: () => setState(() => _mode = _KakaoRestaurantMode.nationwide),
                onSelectRight: _selectNearby,
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
      data: (restaurants) => _RestaurantTicker(
        restaurants: restaurants,
        index: _index,
        onCountResolved: _ensureTimer,
        emptyMessage: '전국 맛집 정보를 불러오지 못했어요',
        isNearby: false,
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
      data: (restaurants) => _RestaurantTicker(
        restaurants: restaurants,
        index: _index,
        onCountResolved: _ensureTimer,
        emptyMessage: '반경 5km 안에 등록된 맛집이 없어요',
        isNearby: true,
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.footnote)),
    );
  }
}

/// "전국 / 내 주변" 두 옵션을 한 트랙 안에 이어붙인 segmented control.
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
    required this.isNearby,
  });

  final List<KakaoRestaurant> restaurants;
  final int index;
  final ValueChanged<int> onCountResolved;
  final String emptyMessage;
  final bool isNearby;

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
        child: _RestaurantSingle(key: ValueKey(item.id), item: item, isNearby: isNearby),
      ),
    );
  }
}

class _RestaurantSingle extends StatelessWidget {
  const _RestaurantSingle({super.key, required this.item, required this.isNearby});

  final KakaoRestaurant item;
  final bool isNearby;

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
        // 바깥 카드와 같은 surface 색 + 헤어라인 테두리로만 구분한다 — 이전엔
        // paper(다른 톤) 배경을 써서 "카드 안에 색이 다른 카드"처럼 어색해 보였다.
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
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _emojiBadge(),
                    errorWidget: (_, _, _) => _emojiBadge(),
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
                  Row(
                    children: [
                      Flexible(
                        child: Container(
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
                      ),
                      // "내 위치에서"는 실제 GPS 기준 거리인 "내 주변" 모드에서만
                      // 뜻이 통한다 — "전국" 모드의 distance는 도시 중심 좌표
                      // 기준이라 여기서 보여주면 오해를 준다.
                      if (isNearby && item.distanceM != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '내 위치에서 ${item.distanceM}m',
                            style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
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
