import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// 사진이 없는 장소/코스에 쓰는 공용 대체 화면.
///
/// 예전엔 미리 준비한 AI 이미지 4장을 순환 배정해 마치 실제 사진처럼 보여줬지만,
/// 백엔드가 이제 특정 장소 사진이 없으면 시/군 대표 사진으로 거의 항상 채워주므로
/// (완전히 없는 경우는 드묾) 남은 예외는 "사진 없음"을 있는 그대로 보여주는 게 맞다.
class PhotoFallback extends StatelessWidget {
  const PhotoFallback({super.key, this.icon = Icons.photo_camera_back_outlined, this.label});

  final IconData icon;
  // "정말로 사진이 없는" 경우에만 채워서 넘긴다(로딩/에러 중 임시 표시엔 안 씀) —
  // 사용자가 "왜 이 정류지는 사진이 안 나오지"라고 헷갈리지 않게 작은 글씨로 알려준다.
  final String? label;

  @override
  Widget build(BuildContext context) {
    // label이 없으면 기존과 완전히 같은 구조(Center에 아이콘 하나)를 유지한다 —
    // Column으로 감싸면 36~40px짜리 작은 썸네일(course_roadmap.dart 등)에서
    // 아이콘 크기(40)가 그 박스보다 커서 RenderFlex 오버플로 에러가 난다.
    // label은 여백이 넉넉한 큰 카드에서만 쓰므로 그때만 Column으로 감싼다.
    final iconWidget = Icon(icon, color: AppColors.inkTertiary, size: 40);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentTint, AppColors.paper],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: label == null
            ? iconWidget
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: 6),
                  Text(label!, style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                ],
              ),
      ),
    );
  }
}
