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

/// 카카오맵 맛집 카테고리(자유 텍스트, 예: "한식"/"고기,구이"/"카페")를 파스텔
/// 배지 색으로 매핑한다. 카카오 카테고리는 값이 다양해서 문자열 자체가 아니라
/// 포함 여부로 느슨하게 매칭한다.
Color pastelForFoodCategory(String category) {
  if (category.contains('한식') || category.contains('고기') || category.contains('국밥')) {
    return AppColors.pastelPeach;
  }
  if (category.contains('카페') || category.contains('디저트') || category.contains('베이커리')) {
    return AppColors.pastelButter;
  }
  if (category.contains('일식') || category.contains('돈까스') || category.contains('초밥')) {
    return AppColors.pastelSky;
  }
  if (category.contains('중식')) {
    return AppColors.pastelLavender;
  }
  if (category.contains('양식') || category.contains('피자') || category.contains('패스트푸드')) {
    return AppColors.pastelMint;
  }
  return AppColors.accentTint;
}

/// [pastelForFoodCategory]와 짝을 이루는 아이콘.
IconData iconForFoodCategory(String category) {
  if (category.contains('한식') || category.contains('고기') || category.contains('국밥')) {
    return Icons.rice_bowl_outlined;
  }
  if (category.contains('카페') || category.contains('디저트') || category.contains('베이커리')) {
    return Icons.local_cafe_outlined;
  }
  if (category.contains('일식') || category.contains('돈까스') || category.contains('초밥')) {
    return Icons.ramen_dining_outlined;
  }
  if (category.contains('중식')) {
    return Icons.ramen_dining_outlined;
  }
  if (category.contains('양식') || category.contains('피자') || category.contains('패스트푸드')) {
    return Icons.local_pizza_outlined;
  }
  return Icons.restaurant_outlined;
}
