import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../shared/widgets/region_select_sheet.dart';

/// 도 → 시군구 2단계로 지역을 고르면, 그 지역으로 Claude 코스를 만들어 상세
/// 화면으로 이동한다. 신규 백엔드 호출 없음 — 기존 `/api/location?query=`
/// (카카오 검색) + `/api/course/by-location/{id}`(기존 LLM 코스 생성)만 재사용.
Future<void> showRegionPickerSheet(BuildContext context, WidgetRef ref) async {
  final selected = await showRegionSelectSheet(context, prompt: '어느 지역 코스를 만들까요?');
  if (selected == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    ),
  );

  try {
    final location = await ref.read(locationRepositoryProvider).resolveFromQuery(selected);
    final courses = await ref.read(courseRepositoryProvider).getCoursesByLocation(location.id);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 로딩 다이얼로그 닫기

    if (courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 지역은 아직 코스를 만들 수 없어요')),
      );
      return;
    }
    context.push('/course/${courses.first.id}');
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코스를 만들지 못했어요. 다시 시도해주세요')),
    );
  }
}
