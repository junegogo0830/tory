import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 컬러 토큰.
/// 색은 99% 무채색, 강조색(accent)은 앱 전체에서 단 하나만, 포인트로만 사용한다.
/// (판단 기준: docs/DESIGN_SYSTEM.md)
///
/// 무채색 톤(paper/surface/ink 등)은 다크모드에서 반전되어야 해서 getter로
/// 만들어 [darkModeNotifier]를 참조한다 — 이 값이 바뀌면 [BrightnessScope]가
/// 앱 전체를 새로 그려서 화면에 반영한다. 강조색/파스텔 배지색은 두 모드에서
/// 동일하게 유지하는 게 자연스러워 그대로 static const로 남겨뒀다.
abstract final class AppColors {
  /// 현재 다크모드 여부. [BrightnessScope]가 시스템 설정 변경에 맞춰 갱신한다.
  static final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

  static bool get _dark => darkModeNotifier.value;

  static const Color _paperLight = Color(0xFFF2EFEA);
  static const Color _paperDark = Color(0xFF14120F);
  static Color get paper => _dark ? _paperDark : _paperLight;

  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF211E1A);
  static Color get surface => _dark ? _surfaceDark : _surfaceLight;

  static const Color _fieldBgLight = Color(0xFFF4F1EC);
  static const Color _fieldBgDark = Color(0xFF2A2621);
  static Color get fieldBg => _dark ? _fieldBgDark : _fieldBgLight;

  static const Color _inkLight = Color(0xFF1F1A16);
  static const Color _inkDark = Color(0xFFF2EEE8);
  static Color get ink => _dark ? _inkDark : _inkLight;

  static const Color _inkSecondaryLight = Color(0xFF8C857B);
  static const Color _inkSecondaryDark = Color(0xFFAFA89C);
  static Color get inkSecondary => _dark ? _inkSecondaryDark : _inkSecondaryLight;

  static const Color _inkTertiaryLight = Color(0xFFB3ADA2);
  static const Color _inkTertiaryDark = Color(0xFF716B62);
  static Color get inkTertiary => _dark ? _inkTertiaryDark : _inkTertiaryLight;

  static const Color _hairlineLight = Color(0xFFECE5DA);
  static const Color _hairlineDark = Color(0xFF3A352E);
  static Color get hairline => _dark ? _hairlineDark : _hairlineLight;

  static const Color _charcoalLight = Color(0xFF2B2826);
  static const Color _charcoalDark = Color(0xFFE8E4DE);
  static Color get charcoal => _dark ? _charcoalDark : _charcoalLight;

  // 강조색/파스텔 배지는 두 모드에서 동일 — 브랜드 아이덴티티 색이라 반전하지 않는다.
  static const Color accent = Color(0xFF6A452C);
  static const Color accentTint = Color(0xFFEFE4D9);
  static const Color accentDeep = Color(0xFF4A2F1D);

  // 카테고리 픽토그램 배지 전용 파스텔 팔레트 (docs/DESIGN_SYSTEM.md §1.3 참고).
  // 카드/화면 배경엔 절대 안 쓴다 — 원형 배지 안 아이콘 배경으로만, 화이트 카드
  // 위에서 "생기"를 주는 포인트. accent(브랜드색)는 그대로 버튼/선택상태 담당.
  static const Color pastelSky = Color(0xFFBEE3F0); // 둘러보기 / 관광지
  static const Color pastelPeach = Color(0xFFFFC9B3); // 역사 / 문화
  static const Color pastelMint = Color(0xFFC5E8D3); // 산책 / 자연
  static const Color pastelButter = Color(0xFFFCE8B8); // 미식
  static const Color pastelLavender = Color(0xFFDCCEF0); // 커뮤니티 / 친구찾기
}
