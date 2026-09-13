import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../community/presentation/memory_upload_flow.dart';
import '../../course/data/course_providers.dart';
import '../data/compare_providers.dart';
import 'widgets/compare_slider.dart';

/// webview_flutter는 웹 플랫폼 구현체가 없어 Chrome 등에서 바로 쓰면 크래시난다.
/// 웹에서는 백엔드가 서빙하는 같은 로드뷰 페이지를 새 탭으로 여는 것으로 대체한다
/// (실제 배포 대상은 안드로이드 앱이므로, 웹은 개발 중 확인용 폴백이면 충분하다).
Future<void> _openRoadview(BuildContext context, String locationId, String name) async {
  if (kIsWeb) {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/roadview/$locationId');
    await launchUrl(uri, webOnlyWindowName: '_blank');
    return;
  }
  if (context.mounted) {
    context.push('/roadview/$locationId?name=${Uri.encodeComponent(name)}');
  }
}

/// 장소 상세 화면. 검색/추천을 통해 들어온 장소의 실제 관광정보(TourAPI 사진·설명),
/// 큐레이션된 "그 시절" 비교(있을 때만), 실시간 로드뷰, 그 지역 뉴스로 가는 입구를 모은다.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationDetailProvider(locationId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('장소 정보')),
      body: locationAsync.when(
        data: (location) {
          if (location == null) {
            return Center(
              child: Text('장소 정보를 찾을 수 없어요', style: AppTypography.subhead),
            );
          }
          // 큐레이션된 3곳은 실제로 다른 과거/현재 연도를 갖는다. TourAPI로 새로
          // 찾은 장소는 큐레이션된 옛 사진이 없어 past_year를 current_year와
          // 같게 내려주므로, 이 경우 비교 슬라이더 섹션 자체를 뺀다.
          final hasCuratedPast = location.pastYear != location.currentYear;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroImage(location: location),
                if (location.imageSourceName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${location.name} 사진이 없어서 가까운 ${location.imageSourceName} 사진을 보여드려요.',
                    style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                  ),
                ],
                const SizedBox(height: 18),
                Text(location.name, style: AppTypography.largeTitle),
                const SizedBox(height: 4),
                Text(location.region, style: AppTypography.subhead),
                const SizedBox(height: 14),
                Text(location.description, style: AppTypography.body),
                if (hasCuratedPast) ...[
                  const SizedBox(height: 24),
                  Text('그 시절 ↔ 현재', style: AppTypography.title),
                  const SizedBox(height: 12),
                  CompareSlider(
                    pastYear: location.pastYear,
                    currentYear: location.currentYear,
                    currentImageUrl: location.imageUrl,
                    useLiveRoadview: true,
                    locationId: location.id,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '가운데 핸들을 좌우로 드래그하면 그 시절과 지금의 모습을 비교할 수 있어요.',
                    style: AppTypography.footnote,
                  ),
                ],
                const SizedBox(height: 24),
                _NearbyCoursePreview(locationId: location.id),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () => _openRoadview(context, location.id, location.name),
                  child: const _ActionRow(
                    icon: Icons.threesixty,
                    title: '실시간 로드뷰',
                    subtitle: '카카오 로드뷰로 지금 이 거리를 둘러보세요',
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () => context.push('/archive/${location.id}'),
                  child: const _ActionRow(
                    icon: Icons.newspaper_outlined,
                    title: '그 시절 뉴스',
                    subtitle: '이 지역 관련 뉴스를 모아봐요',
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () => showMemoryUploadFlow(
                    context,
                    ref,
                    region: location.region,
                    locationId: location.id,
                  ),
                  child: const _ActionRow(
                    icon: Icons.add_a_photo_outlined,
                    title: '추억 등록',
                    subtitle: '이 동네에서의 추억을 사진으로 남겨보세요',
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.location});

  final HometownLocation location;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: location.imageUrl != null
            ? AppNetworkImage(
                imageUrl: location.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const PhotoFallback(),
                errorWidget: (_, _, _) => const PhotoFallback(),
              )
            : const PhotoFallback(),
      ),
    );
  }
}

/// 이 장소 주변 추천 코스 미리보기. 큐레이션 3곳은 손으로 다듬은 코스, 그 밖의
/// 검색된 장소는 좌표 기반 실제 주변 장소 + LLM으로 그 계절에 맞게 생성된 코스다.
/// 코스가 없으면(좌표 없음/생성 실패 등) 조용히 아무것도 안 보여준다 — 로드뷰·뉴스
/// 카드와 달리 이건 있으면 좋은 보조 정보라 빈 상태 UI까지는 필요 없다.
class _NearbyCoursePreview extends ConsumerWidget {
  const _NearbyCoursePreview({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesByLocationProvider(locationId));

    return coursesAsync.when(
      data: (courses) {
        if (courses.isEmpty) return const SizedBox.shrink();
        final course = courses.first;

        return AppCard(
          onTap: () => context.push('/course/${course.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                    child: const Icon(Icons.map_outlined, color: AppColors.accentDeep),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('이 근처 추천 코스', style: AppTypography.footnote),
                        Text(course.title, style: AppTypography.headline),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.inkTertiary),
                ],
              ),
              const SizedBox(height: 10),
              Text(course.description, style: AppTypography.subhead),
              const SizedBox(height: 8),
              Text(course.stops.map((s) => s.name).join(' · '), style: AppTypography.caption),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.accentDeep),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headline),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.footnote),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: AppColors.inkTertiary),
      ],
    );
  }
}
