import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/kakao_map_links.dart';
import '../../../data/models/nearby_place.dart';
import '../../../data/models/tour_course.dart';
import '../../../shared/widgets/app_card.dart';
import '../../home/data/home_providers.dart';
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
            return Center(child: Text('코스를 찾을 수 없어요', style: AppTypography.subhead));
          }
          final scorePercent = (course.sentimentScore * 100).round();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (course.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: CachedNetworkImage(imageUrl: course.imageUrl!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(course.title, style: AppTypography.largeTitle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Badge(label: course.category),
                    _Badge(label: '감성 $scorePercent%'),
                    _Badge(label: course.durationLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Text(course.description, style: AppTypography.body),
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('방문 순서', style: AppTypography.headline),
                      const SizedBox(height: 4),
                      Text('정류지를 눌러 카카오맵으로 길찾기를 시작해요', style: AppTypography.footnote),
                      const SizedBox(height: 12),
                      for (var i = 0; i < course.stops.length; i++)
                        _StopRow(number: i + 1, stop: course.stops[i]),
                    ],
                  ),
                ),
                if (course.locationId.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _NearbyRestaurants(locationId: course.locationId),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.accentTint, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
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
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(stop.name, style: AppTypography.body)),
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
              for (final place in restaurants.take(5)) _RestaurantRow(place: place),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
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
          const Icon(Icons.restaurant, size: 18, color: AppColors.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: AppTypography.body),
                if (place.distanceM != null)
                  Text('${place.distanceM}m · ${place.address}', style: AppTypography.caption),
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
              icon: const Icon(Icons.directions, size: 20, color: AppColors.accentDeep),
            ),
        ],
      ),
    );
  }
}
