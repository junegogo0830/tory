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

  // 카테고리 픽토그램 배지 색 — 예전엔 카테고리별로 다른 파스텔(하늘/복숭아/민트 등)을
  // 썼는데, 톤이 튀어서 전체 베이지 톤과 안 어울린다는 피드백으로 전부 iconChipBg와
  // 같은 베이지로 통일했다. 이름은 호출부 17곳을 다 바꾸지 않으려고 그대로 뒀다 —
  // 이제 "파스텔"이 아니라 전부 같은 베이지 값을 가리킨다.
  static const Color pastelSky = iconChipBg;
  static const Color pastelPeach = iconChipBg;
  static const Color pastelMint = iconChipBg;
  static const Color pastelButter = iconChipBg;
  static const Color pastelLavender = iconChipBg;
  static const Color pastelRose = iconChipBg;

  // 챗봇 진입 풍선 전용 강조색 — 베이지 톤 화면 위에서 눈에 띄게 의도적으로
  // 다른 계열(주황)을 쓴다. 다른 곳엔 쓰지 않는다.
  static const Color chatbotOrange = Color(0xFFEF7B34);
}
