import 'package:flutter/material.dart';
import 'app_colors.dart';

const String _fontFamily = 'Pretendard';

/// 옛길 디자인 시스템 타입스케일 (iOS 타입스케일 기반).
abstract final class AppTypography {
  static const TextStyle largeTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.25,
  );

  /// 홈/탭 화면의 섹션 제목 ("우리 동네 최신 이야기" 등). 페이지 제목([title])보다
  /// 한 단계 작고, 본문 카드 제목([headline])보다는 확실히 무겁게.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.25,
    letterSpacing: -0.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.4,
  );

  static const TextStyle subhead = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
    height: 1.35,
  );

  static const TextStyle footnote = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.inkTertiary,
    height: 1.3,
  );

  /// 통계/숫자 강조 페어 (2:1 비율). 감성 점수·연도·소요 시간처럼
  /// 시선이 숫자에 먼저 가야 하는 곳에 [statUnit]과 짝으로 쓴다.
  static const TextStyle statNumber = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.1,
  );

  static const TextStyle statUnit = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
    height: 1.2,
  );
}
