import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/tour_course.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/photo_fallback.dart';

/// 코스 탭 상단에 "현재 계신 곳을 기준으로 코스를 짜봤어요"로 바로 보여주는
/// 위치 기반 코스.
///
/// 처음 진입할 때 한 번만 자동으로 불러오고, 그 뒤로는 절대 자동으로 다시
/// 부르지 않는다(리스트 스크롤 등으로 위젯이 다시 빌드돼도) — 위치+Claude
/// 호출은 비용이 있어서, `ref.watch(family)`처럼 좌표가 미세하게 흔들릴 때마다
/// 새 캐시 키로 재호출되는 방식 대신 순수 로컬 상태로 관리한다. 다시 만들고
/// 싶으면 작은 새로고침 버튼을 직접 눌러야 한다.
class NearbyCourseCard extends ConsumerStatefulWidget {
  const NearbyCourseCard({super.key});

  @override
  ConsumerState<NearbyCourseCard> createState() => _NearbyCourseCardState();
}

enum _LoadState { idle, loading, loaded, unavailable }

class _NearbyCourseCardState extends ConsumerState<NearbyCourseCard> {
  _LoadState _state = _LoadState.idle;
  TourCourse? _course;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _state = _LoadState.unavailable);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _state = _LoadState.unavailable);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      final course = await ref
          .read(courseRepositoryProvider)
          .getCourseByCoords(lat: position.latitude, lng: position.longitude);
      if (!mounted) return;
      setState(() {
        _course = course;
        _state = course == null ? _LoadState.unavailable : _LoadState.loaded;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _LoadState.idle:
      case _LoadState.loading:
        return const _NearbyCourseLoading();
      case _LoadState.unavailable:
        return const SizedBox.shrink();
      case _LoadState.loaded:
        return _NearbyCourseContent(course: _course!, onRefresh: _load);
    }
  }
}

class _NearbyCourseLoading extends StatelessWidget {
  const _NearbyCourseLoading();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text('현재 계신 곳 근처 코스를 짜고 있어요…', style: AppTypography.subhead),
        ],
      ),
    );
  }
}

class _NearbyCourseContent extends StatelessWidget {
  const _NearbyCourseContent({required this.course, required this.onRefresh});

  final TourCourse course;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.near_me_outlined,
              color: AppColors.accentDeep,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '현재 계신 곳을 기준으로 코스를 짜봤어요',
                style: AppTypography.headline,
              ),
            ),
            // 자동으로는 다시 안 부르고, 누르면만 새로고침한다.
            InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(99),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.my_location,
                  size: 18,
                  color: AppColors.accentDeep,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(12),
          onTap: () => context.push('/course/${course.id}'),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: course.imageUrl != null
                      ? AppNetworkImage(
                          imageUrl: course.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const PhotoFallback(icon: Icons.route_outlined),
                          errorWidget: (_, _, _) =>
                              const PhotoFallback(icon: Icons.route_outlined),
                        )
                      : const PhotoFallback(icon: Icons.route_outlined),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ],
    );
  }
}
