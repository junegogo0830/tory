import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 사진이 없는 장소/코스에 쓰는 공용 대체 화면.
///
/// 예전엔 미리 준비한 AI 이미지 4장을 순환 배정해 마치 실제 사진처럼 보여줬지만,
/// 백엔드가 이제 특정 장소 사진이 없으면 시/군 대표 사진으로 거의 항상 채워주므로
/// (완전히 없는 경우는 드묾) 남은 예외는 "사진 없음"을 있는 그대로 보여주는 게 맞다.
class PhotoFallback extends StatelessWidget {
  const PhotoFallback({super.key, this.icon = Icons.photo_camera_back_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentTint, AppColors.paper],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: AppColors.inkTertiary, size: 40),
      ),
    );
  }
}
