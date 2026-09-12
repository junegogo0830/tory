import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 코스 카테고리별 파스텔 배지 색 (docs/DESIGN_SYSTEM.md §1.3).
Color pastelForCategory(String category) {
  switch (category) {
    case '산책':
      return AppColors.pastelMint;
    case '역사':
      return AppColors.pastelPeach;
    case '미식':
      return AppColors.pastelButter;
    default:
      return AppColors.pastelSky;
  }
}
