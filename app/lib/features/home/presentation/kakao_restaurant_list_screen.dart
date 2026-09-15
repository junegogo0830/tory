import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/kakao_map_links.dart';
import '../../../data/models/kakao_restaurant.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/home_providers.dart';

enum _Mode { nationwide, nearby }

/// 카카오맵 기반 맛집 "자세히보기" 화면. lat/lng이 주어지면 내 주변 모드로
/// 열리고, 위에 붙은 전국/내 주변 segmented control로 그 자리에서 바로
/// 전환할 수 있다(내 주변으로 바꿨는데 좌표가 없으면 그때 위치를 받아온다).
///
/// 카카오 로컬 API 자체엔 평점·리뷰 수가 없어 우리가 "몇 점/몇 개 리뷰"를
/// 보여줄 수 없다 — 대신 카드를 누르면 실제 평점·리뷰가 있는 카카오맵 원본
/// 페이지로 이동한다. 전화번호/좌표가 있으면 바로 걸거나 길찾기로 넘어간다.
class KakaoRestaurantListScreen extends ConsumerStatefulWidget {
  const KakaoRestaurantListScreen({super.key, this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  ConsumerState<KakaoRestaurantListScreen> createState() => _KakaoRestaurantListScreenState();
}

class _KakaoRestaurantListScreenState extends ConsumerState<KakaoRestaurantListScreen> {
  late _Mode _mode = widget.lat != null && widget.lng != null ? _Mode.nearby : _Mode.nationwide;
  Position? _position;
  bool _isLocating = false;
  String? _locationError;

  Future<void> _selectNearby() async {
    setState(() => _mode = _Mode.nearby);
    if (widget.lat != null && widget.lng != null) return;
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
  Widget build(BuildContext context) {
    final lat = widget.lat ?? _position?.latitude;
    final lng = widget.lng ?? _position?.longitude;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('맛집 추천')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('카카오맵 맛집 추천', style: AppTypography.sectionTitle)),
                      _Segmented(
                        left: '전국',
                        right: '내 주변',
                        selectedLeft: _mode == _Mode.nationwide,
                        onSelectLeft: () => setState(() => _mode = _Mode.nationwide),
                        onSelectRight: _selectNearby,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _mode == _Mode.nationwide
                      ? _RestaurantList(restaurantsAsync: ref.watch(kakaoRestaurantsNationwideProvider))
                      : _buildNearby(lat, lng),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearby(double? lat, double? lng) {
    if (_isLocating) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (_locationError != null) {
      return Center(child: Text(_locationError!, style: AppTypography.subhead));
    }
    if (lat == null || lng == null) return const SizedBox.shrink();
    return _RestaurantList(restaurantsAsync: ref.watch(kakaoRestaurantsNearbyProvider((lat: lat, lng: lng))));
  }
}

class _RestaurantList extends StatelessWidget {
  const _RestaurantList({required this.restaurantsAsync});

  final AsyncValue<List<KakaoRestaurant>> restaurantsAsync;

  @override
  Widget build(BuildContext context) {
    return restaurantsAsync.when(
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return const EmptyState(
            icon: Icons.restaurant_outlined,
            title: '맛집을 찾지 못했어요',
            message: '잠시 후 다시 시도해주세요.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < restaurants.length; i++) ...[
                    _RestaurantRow(item: restaurants[i]),
                    if (i != restaurants.length - 1)
                      Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.hairline),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
    );
  }
}

/// "전국 / 내 주변" 두 옵션을 한 트랙 안에 이어붙인 segmented control —
/// 홈 화면의 카카오맵 맛집 추천 카드와 같은 컴포넌트.
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? AppColors.surface : AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl == null)
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.pastelButter, borderRadius: BorderRadius.circular(AppRadius.tile)),
                  child: Icon(Icons.restaurant_outlined, color: AppColors.accentDeep, size: 20),
                )
              else
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    child: AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item.category, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                      ],
                    ),
                    const SizedBox(height: 3),
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
          if (item.phone != null || item.hasCoordinates || hasPlacePage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.phone != null) ...[
                  _IconActionButton(icon: Icons.call_outlined, onTap: _call),
                  const SizedBox(width: 8),
                ],
                if (item.hasCoordinates) ...[
                  _IconActionButton(
                    icon: Icons.directions_outlined,
                    onTap: () => openKakaoMapDirections(name: item.name, latitude: item.latitude!, longitude: item.longitude!),
                  ),
                  const SizedBox(width: 8),
                ],
                if (hasPlacePage)
                  TextButton(
                    onPressed: _openPlacePage,
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
              ],
            ),
          ],
        ],
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
