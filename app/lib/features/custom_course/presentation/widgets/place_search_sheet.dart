import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/custom_course.dart';
import '../../../../data/models/hometown_location.dart';
import '../../../../data/repositories/repository_providers.dart';

/// 코스 커스텀에 넣을 장소 하나를 검색해서 고르는 바텀시트 — TourAPI(관광지로
/// 등록된 곳)와 카카오맵(식당·카페 등 실제 장소 전반) 두 소스 중 골라 검색한다.
/// 고르면 [CustomCoursePlace]를 반환한다(취소하면 null).
Future<CustomCoursePlace?> showPlaceSearchSheet(BuildContext context) {
  return showModalBottomSheet<CustomCoursePlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => const _PlaceSearchContent(),
  );
}

enum _Source { tour, kakao }

class _PlaceSearchContent extends ConsumerStatefulWidget {
  const _PlaceSearchContent();

  @override
  ConsumerState<_PlaceSearchContent> createState() => _PlaceSearchContentState();
}

class _PlaceSearchContentState extends ConsumerState<_PlaceSearchContent> {
  final _controller = TextEditingController();
  Timer? _debounce;
  _Source _source = _Source.tour;
  List<HometownLocation> _tourResults = [];
  List<KakaoPlaceSearchResult> _kakaoResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _tourResults = [];
        _kakaoResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      if (_source == _Source.tour) {
        final results = await ref.read(locationRepositoryProvider).searchTourLocations(query, limit: 10);
        if (!mounted) return;
        setState(() => _tourResults = results);
      } else {
        final results = await ref.read(customCourseRepositoryProvider).searchKakaoPlaces(query);
        if (!mounted) return;
        setState(() => _kakaoResults = results);
      }
    } catch (_) {
      if (mounted) setState(() => _source == _Source.tour ? _tourResults = [] : _kakaoResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _switchSource(_Source source) {
    if (_source == source) return;
    setState(() => _source = source);
    final query = _controller.text.trim();
    if (query.isNotEmpty) _search(query);
  }

  @override
  Widget build(BuildContext context) {
    final results = _source == _Source.tour
        ? _tourResults.map(_fromTour).toList()
        : _kakaoResults.map(_fromKakao).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('코스에 넣을 장소를 검색해주세요', style: AppTypography.headline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SourceChip(
                  label: '관광지 (TourAPI)',
                  selected: _source == _Source.tour,
                  onTap: () => _switchSource(_Source.tour),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SourceChip(
                  label: '카카오맵',
                  selected: _source == _Source.kakao,
                  onTap: () => _switchSource(_Source.kakao),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: _source == _Source.tour ? '예: 경복궁, 해운대' : '예: 스타벅스, 식당 이름',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().isEmpty ? '장소 이름을 입력해주세요' : '검색 결과가 없어요',
                          style: AppTypography.subhead.copyWith(color: AppColors.inkTertiary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
                        itemBuilder: (context, index) {
                          final place = results[index];
                          return ListTile(
                            leading: Icon(
                              _source == _Source.tour ? Icons.landscape_outlined : Icons.storefront_outlined,
                              color: AppColors.accentDeep,
                            ),
                            title: Text(place.name, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(place.address, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.of(context).pop(place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  CustomCoursePlace _fromTour(HometownLocation location) => CustomCoursePlace(
        source: 'tour',
        placeId: location.id,
        name: location.name,
        address: location.region,
        latitude: location.latitude,
        longitude: location.longitude,
        imageUrl: location.imageUrl,
      );

  CustomCoursePlace _fromKakao(KakaoPlaceSearchResult result) => CustomCoursePlace(
        source: 'kakao',
        placeId: result.id,
        name: result.name,
        address: result.address,
        latitude: result.latitude,
        longitude: result.longitude,
      );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.paper,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
