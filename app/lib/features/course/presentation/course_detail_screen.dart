import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_colors.dart';
import '../../../core/utils/kakao_map_links.dart';
import '../../../data/models/nearby_place.dart';
import '../../../data/models/tour_course.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/photo_attribution_badge.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../../shared/widgets/save_course_button.dart';
import '../../auth/data/auth_providers.dart';
import '../../home/data/home_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/course_providers.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('코스 상세'),
        actions: [SaveCourseButton(courseType: 'generated', courseId: courseId)],
      ),
      body: courseAsync.when(
        data: (course) {
          if (course == null) {
            return Center(
              child: Text('코스를 찾을 수 없어요', style: AppTypography.subhead),
            );
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (course.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(
                            imageUrl: course.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const PhotoFallback(icon: Icons.route_outlined),
                            errorWidget: (_, _, _) =>
                                const PhotoFallback(icon: Icons.route_outlined),
                          ),
                          // 코스 대표사진은 보통 정류지 사진 중 하나를 그대로 쓴다 —
                          // 같은 URL을 쓰는 정류지의 출처 표기를 그대로 붙인다.
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Builder(
                              builder: (context) {
                                final source = course.stops.where((s) => s.imageUrl == course.imageUrl);
                                final match = source.isEmpty ? null : source.first;
                                return PhotoAttributionBadge(
                                  name: match?.photoAttributionName,
                                  url: match?.photoAttributionUrl,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: const PhotoFallback(icon: Icons.route_outlined, label: '사진이 없어요'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(course.title, style: AppTypography.largeTitle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Badge(
                      label: course.category,
                      color: pastelForCategory(course.category),
                    ),
                    _Badge(label: course.durationLabel),
                    if (course.distanceKm != null)
                      _Badge(label: '이동 약 ${course.distanceKm}km'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(course.description, style: AppTypography.body),
                if (course.weatherLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      course.weatherLabel,
                      style: AppTypography.headline,
                    ),
                  ),
                for (final note in course.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(note, style: AppTypography.footnote),
                  ),
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('방문 순서', style: AppTypography.headline),
                      const SizedBox(height: 4),
                      Text(
                        '정류지 옆 길찾기를 누르면 카카오맵으로 바로 이동해요',
                        style: AppTypography.footnote,
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < course.stops.length; i++)
                        _StopTimelineRow(
                          stop: course.stops[i],
                          showLine: i < course.stops.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _CompleteCourseButton(courseId: course.id),
                if (course.locationId.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _NearbyRestaurants(locationId: course.locationId),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        // 원인을 바로 알 수 있게 실제 에러도 화면에 함께 보여준다(디버깅용) —
        // "불러오는 중 문제가 발생했어요" 하나만 보여주면 재현되는 실제 버그가
        // 있어도 어디가 문제인지 알 길이 없다.
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
                const SizedBox(height: 8),
                Text(
                  '잠시 후 다시 시도해주세요.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? AppColors.accentTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accentDeep,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 정류지 한 칸 — 왼쪽에 사진 카드, 그 옆에 이어지는 세로선+원 마커, 오른쪽에
/// 이름/주소/머무는 시간과 길찾기. 이전엔 사진 없이 번호+글자만 나열해서
/// "단조롭다"는 피드백이 있었다 — 사진(TourAPI 보강, backend recommendation.py
/// _enrich_course 참고)과 로드맵 선으로 실제 코스를 따라 걷는 느낌을 준다.
class _StopTimelineRow extends StatelessWidget {
  const _StopTimelineRow({required this.stop, required this.showLine});

  final CourseStop stop;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 11, child: _StopPhotoCard(stop: stop)),
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                  ),
                  if (showLine)
                    Expanded(
                      child: Container(width: 2, color: AppColors.hairline),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stop.source == 'tourapi' || stop.source == 'kakao')
                      Text(
                        stop.source == 'tourapi' ? '한국관광공사 관광정보' : '카카오맵 장소',
                        style: AppTypography.caption,
                      ),
                    if (stop.category.isNotEmpty ||
                        stop.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.category.isNotEmpty
                            ? '${stop.category} · 약 ${stop.stayMinutes}분'
                            : stop.address,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (stop.hasCoordinates) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => openKakaoMapDirections(
                          name: stop.name,
                          latitude: stop.latitude!,
                          longitude: stop.longitude!,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions,
                              size: 15,
                              color: AppColors.accentDeep,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '길찾기',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accentDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopPhotoCard extends StatelessWidget {
  const _StopPhotoCard({required this.stop});

  final CourseStop stop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: SizedBox(
        height: 84,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _StopPhoto(stop: stop),
            if (stop.photoAttributionName != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: PhotoAttributionBadge(
                  name: stop.photoAttributionName,
                  url: stop.photoAttributionUrl,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopPhoto extends StatelessWidget {
  const _StopPhoto({required this.stop});

  final CourseStop stop;

  @override
  Widget build(BuildContext context) {
    return stop.imageUrl == null
        ? const PhotoFallback(icon: Icons.route_outlined, label: '사진이 없어요')
        : AppNetworkImage(
            imageUrl: stop.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
            errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
          );
  }
}

/// "완주했어요" 체크 — 프로필 탭 "완주한 코스" 통계를 실제로 늘리는 유일한 버튼.
/// 백엔드가 중복 완주 기록을 알아서 무시해서(idempotent) 여러 번 눌러도 안전하다.
class _CompleteCourseButton extends ConsumerStatefulWidget {
  const _CompleteCourseButton({required this.courseId});

  final String courseId;

  @override
  ConsumerState<_CompleteCourseButton> createState() =>
      _CompleteCourseButtonState();
}

class _CompleteCourseButtonState extends ConsumerState<_CompleteCourseButton> {
  bool _completed = false;
  bool _busy = false;

  Future<void> _complete() async {
    if (ref.read(authStateProvider).value != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인하면 완주 기록을 남길 수 있어요')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).completeCourse(widget.courseId);
      ref.invalidate(profileProvider);
      if (mounted) {
        setState(() => _completed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('완주를 기록했어요! 프로필에서 확인해보세요')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기록하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy || _completed ? null : _complete,
        icon: Icon(_completed ? Icons.check_circle : Icons.flag_outlined),
        label: Text(_completed ? '완주를 기록했어요' : '이 코스 완주했어요'),
      ),
    );
  }
}

class _NearbyRestaurants extends ConsumerWidget {
  const _NearbyRestaurants({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(nearbyRestaurantsProvider(locationId));

    return restaurantsAsync.when(
      data: (restaurants) {
        if (restaurants.isEmpty) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주변 맛집', style: AppTypography.headline),
              const SizedBox(height: 4),
              Text('코스 근처 실제 음식점이에요', style: AppTypography.footnote),
              const SizedBox(height: 12),
              for (final place in restaurants.take(5))
                _RestaurantRow(place: place),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({required this.place});
  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.restaurant, size: 18, color: AppColors.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: AppTypography.body),
                if (place.distanceM != null)
                  Text(
                    '${place.distanceM}m · ${place.address}',
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          if (place.hasCoordinates)
            IconButton(
              onPressed: () => openKakaoMapDirections(
                name: place.name,
                latitude: place.latitude!,
                longitude: place.longitude!,
              ),
              icon: const Icon(
                Icons.directions,
                size: 20,
                color: AppColors.accentDeep,
              ),
            ),
        ],
      ),
    );
  }
}
