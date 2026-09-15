import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 컬러 토큰.
/// warm ivory/beige 배경 + 브라운 계열 강조색을 쓰는 "실제 출시된 한국 커머스
/// 앱" 톤을 기준으로 삼는다(판단 기준: docs/DESIGN_SYSTEM.md, 코스 공유 화면
/// 목업). 브라운은 장식이 아니라 selected/active/interactive 상태 표현에 쓴다.
///
/// 무채색 톤(paper/surface/ink 등)은 다크모드에서 반전되어야 해서 getter로
/// 만들어 [darkModeNotifier]를 참조한다 — 이 값이 바뀌면 [BrightnessScope]가
/// 앱 전체를 새로 그려서 화면에 반영한다. 강조색/파스텔 배지색은 두 모드에서
/// 동일하게 유지하는 게 자연스러워 그대로 static const로 남겨뒀다.
abstract final class AppColors {
  /// 현재 다크모드 여부. [BrightnessScope]가 시스템 설정 변경에 맞춰 갱신한다.
  static final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

  static bool get _dark => darkModeNotifier.value;

  // Primary Background
  static const Color _paperLight = Color(0xFFF2EFEA);
  static const Color _paperDark = Color(0xFF14120F);
  static Color get paper => _dark ? _paperDark : _paperLight;

  // Secondary Background — 입력창/서치바처럼 배경보다 한 단 들어간 표면.
  static const Color _fieldBgLight = Color(0xFFF6F3EE);
  static const Color _fieldBgDark = Color(0xFF2A2621);
  static Color get fieldBg => _dark ? _fieldBgDark : _fieldBgLight;

  // Surface — 카드/리스트 등 콘텐츠가 올라가는 가장 밝은 면.
  static const Color _surfaceLight = Color(0xFFFFFDFC);
  static const Color _surfaceDark = Color(0xFF211E1A);
  static Color get surface => _dark ? _surfaceDark : _surfaceLight;

  // Primary Text
  static const Color _inkLight = Color(0xFF29241F);
  static const Color _inkDark = Color(0xFFF2EEE8);
  static Color get ink => _dark ? _inkDark : _inkLight;

  // Secondary Text
  static const Color _inkSecondaryLight = Color(0xFF91877D);
  static const Color _inkSecondaryDark = Color(0xFFAFA89C);
  static Color get inkSecondary => _dark ? _inkSecondaryDark : _inkSecondaryLight;

  // Muted Text
  static const Color _inkTertiaryLight = Color(0xFFAAA198);
  static const Color _inkTertiaryDark = Color(0xFF716B62);
  static Color get inkTertiary => _dark ? _inkTertiaryDark : _inkTertiaryLight;

  // Light Divider — 리스트 행 사이 구분선.
  static const Color _hairlineLight = Color(0xFFEAE4DE);
  static const Color _hairlineDark = Color(0xFF3A352E);
  static Color get hairline => _dark ? _hairlineDark : _hairlineLight;

  // Default Border — 카드/컴포넌트 외곽선(구분선보다 한 단 또렷하다).
  static const Color _borderLight = Color(0xFFDED7CF);
  static const Color _borderDark = Color(0xFF453F37);
  static Color get border => _dark ? _borderDark : _borderLight;

  static const Color _charcoalLight = Color(0xFF2B2826);
  static const Color _charcoalDark = Color(0xFFE8E4DE);
  static Color get charcoal => _dark ? _charcoalDark : _charcoalLight;

  // 브랜드 브라운 스케일 — 두 모드에서 동일(브랜드 아이덴티티 색이라 반전하지
  // 않는다). accent는 selected/active 상태, accentDeep은 아이콘·강한 텍스트,
  // accentInteractive는 hover/pressed류 보조 상태, accentCta는 등록/제출 같은
  // 1차 액션 버튼 전용, accentBorder는 selected 카드 테두리.
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
