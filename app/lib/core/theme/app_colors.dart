import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 컬러 토큰.
/// warm ivory/beige 배경 + 브라운 계열 강조색을 쓰는 "실제 출시된 한국 커머스
/// 앱" 톤을 기준으로 삼는다(판단 기준: docs/DESIGN_SYSTEM.md, 코스 공유 화면
/// 목업). 브라운은 장식이 아니라 selected/active/interactive 상태 표현에 쓴다.
abstract final class AppColors {
  // Primary Background
  static const Color paper = Color(0xFFF2EFEA);

  // Secondary Background — 입력창/서치바처럼 배경보다 한 단 들어간 표면.
  static const Color fieldBg = Color(0xFFF6F3EE);

  // Surface — 카드/리스트 등 콘텐츠가 올라가는 가장 밝은 면.
  static const Color surface = Color(0xFFFFFDFC);

  // Primary Text
  static const Color ink = Color(0xFF29241F);

  // Secondary Text
  static const Color inkSecondary = Color(0xFF91877D);

  // Muted Text
  static const Color inkTertiary = Color(0xFFAAA198);

  // Light Divider — 리스트 행 사이 구분선.
  static const Color hairline = Color(0xFFEAE4DE);

  // Default Border — 카드/컴포넌트 외곽선(구분선보다 한 단 또렷하다).
  static const Color border = Color(0xFFDED7CF);

  static const Color charcoal = Color(0xFF2B2826);

  // 브랜드 브라운 스케일. accent는 selected/active 상태, accentDeep은
  // 아이콘·강한 텍스트, accentInteractive는 hover/pressed류 보조 상태,
  // accentCta는 등록/제출 같은 1차 액션 버튼 전용, accentBorder는 selected
  // 카드 테두리.
  static const Color accent = Color(0xFF755039); // Primary Brown
  static const Color accentDeep = Color(0xFF583B2A); // Dark Brown
  static const Color accentInteractive = Color(0xFF916247); // Interactive Brown
  static const Color accentCta = Color(0xFFAE704B); // CTA Brown
  static const Color accentBorder = Color(0xFFA17C63); // Brown Border
  static const Color accentTint = Color(0xFFEFE4D9); // 옅은 브라운 틴트(칩/뱃지 배경)

  // Important Feature Card — 화면에서 가장 강조할 1차 기능(옛길 게시판 등).
  static const Color featureTint = Color(0xFFF2E9DF);
  static const Color featureBorder = Color(0xFFB58F74);

  // 전화/길찾기 같은 작은 원형 아이콘 버튼 전용.
  static const Color iconChipBg = Color(0xFFF0E7DE);
  static const Color iconChipFg = Color(0xFF60422F);

  // 카테고리 픽토그램 배지 전용 파스텔 팔레트 (docs/DESIGN_SYSTEM.md §1.3 참고).
  // 카드/화면 배경엔 절대 안 쓴다 — 원형 배지 안 아이콘 배경으로만, 화이트 카드
  // 위에서 "생기"를 주는 포인트. accent(브랜드색)는 그대로 버튼/선택상태 담당.
  static const Color pastelSky = Color(0xFFDCECF0); // 둘러보기 / 관광지
  static const Color pastelPeach = Color(0xFFF3DED2); // 역사 / 문화
  static const Color pastelMint = Color(0xFFDFECE3); // 산책 / 자연
  static const Color pastelButter = Color(0xFFEFE6CF); // 미식
  static const Color pastelLavender = Color(0xFFE6DEEA); // 커뮤니티 / 친구찾기
  static const Color pastelRose = Color(0xFFF0C9D6); // 타임캡슐 편지
}
