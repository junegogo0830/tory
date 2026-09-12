import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 컬러 토큰.
/// 색은 99% 무채색, 강조색(accent)은 앱 전체에서 단 하나만, 포인트로만 사용한다.
/// (판단 기준: docs/DESIGN_SYSTEM.md)
abstract final class AppColors {
  static const Color paper = Color(0xFFF2EFEA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color fieldBg = Color(0xFFF4F1EC);

  static const Color ink = Color(0xFF1F1A16);
  static const Color inkSecondary = Color(0xFF8C857B);
  static const Color inkTertiary = Color(0xFFB3ADA2);

  static const Color accent = Color(0xFF6A452C);
  static const Color accentTint = Color(0xFFEFE4D9);
  static const Color accentDeep = Color(0xFF4A2F1D);

  static const Color hairline = Color(0xFFECE5DA);
  static const Color charcoal = Color(0xFF2B2826);

  // 카테고리 픽토그램 배지 전용 파스텔 팔레트 (docs/DESIGN_SYSTEM.md §1.3 참고).
  // 카드/화면 배경엔 절대 안 쓴다 — 원형 배지 안 아이콘 배경으로만, 화이트 카드
  // 위에서 "생기"를 주는 포인트. accent(브랜드색)는 그대로 버튼/선택상태 담당.
  static const Color pastelSky = Color(0xFFBEE3F0); // 둘러보기 / 관광지
  static const Color pastelPeach = Color(0xFFFFC9B3); // 역사 / 문화
  static const Color pastelMint = Color(0xFFC5E8D3); // 산책 / 자연
  static const Color pastelButter = Color(0xFFFCE8B8); // 미식
  static const Color pastelLavender = Color(0xFFDCCEF0); // 커뮤니티 / 친구찾기
}
