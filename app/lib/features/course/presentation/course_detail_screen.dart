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
import '../../../shared/widgets/photo_fallback.dart';
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
      appBar: AppBar(title: const Text('코스 상세')),
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
                      child: AppNetworkImage(
                        imageUrl: course.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const PhotoFallback(icon: Icons.route_outlined),
                        errorWidget: (_, _, _) =>
                            const PhotoFallback(icon: Icons.route_outlined),
                      ),
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
                        '정류지를 눌러 카카오맵으로 길찾기를 시작해요',
                        style: AppTypography.footnote,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < course.stops.length; i++)
                        _StopRow(number: i + 1, stop: course.stops[i]),
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

class _StopRow extends StatelessWidget {
  const _StopRow({required this.number, required this.stop});

  final int number;
  final CourseStop stop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.caption.copyWith(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.name, style: AppTypography.body),
                if (stop.address.isNotEmpty)
                  Text(stop.address, style: AppTypography.caption),
                if (stop.category.isNotEmpty)
                  Text(
                    '${stop.category} · 약 ${stop.stayMinutes}분 머물기',
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          if (stop.hasCoordinates)
            TextButton.icon(
              onPressed: () => openKakaoMapDirections(
                name: stop.name,
                latitude: stop.latitude!,
                longitude: stop.longitude!,
              ),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('길찾기'),
            ),
        ],
      ),
    );
  }
}

/// "완주했어요" 체크 — 프로필 탭 "완주한 코스" 통계를 실제로 늘리는 유일한 버튼.
/// 백엔드가 중복 완주 기록을 알아서 무시해서(idempotent) 여러 번 눌러도 안전하다.
class _CompleteCourseButton extends ConsumerStatefulWidget {
  const _CompleteCourseButton({required this.courseId});

  final String courseId;

  @override
  ConsumerState<_CompleteCourseButton> createState() => _CompleteCourseButtonState();
}

class _CompleteCourseButtonState extends ConsumerState<_CompleteCourseButton> {
  bool _completed = false;
  bool _busy = false;

  Future<void> _complete() async {
    if (ref.read(authStateProvider).value != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인하면 완주 기록을 남길 수 있어요')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록하지 못했어요. 다시 시도해주세요.')),
        );
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
