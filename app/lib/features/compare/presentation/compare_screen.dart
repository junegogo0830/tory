import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/compare_providers.dart';
import 'widgets/compare_slider.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationDetailProvider(locationId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('과거 ↔ 현재 비교')),
      body: locationAsync.when(
        data: (location) {
          if (location == null) {
            return Center(
              child: Text('장소 정보를 찾을 수 없어요', style: AppTypography.subhead),
            );
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(location.name, style: AppTypography.largeTitle),
                const SizedBox(height: 4),
                Text(location.region, style: AppTypography.subhead),
                const SizedBox(height: 20),
                CompareSlider(
                  pastYear: location.pastYear,
                  currentYear: location.currentYear,
                ),
                const SizedBox(height: 16),
                Text(
                  '가운데 핸들을 좌우로 드래그하면 그 시절과 지금의 모습을 비교할 수 있어요.',
                  style: AppTypography.footnote,
                ),
                const SizedBox(height: 20),
                Text(location.description, style: AppTypography.body),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
        ),
      ),
    );
  }
}
