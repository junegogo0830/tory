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
}
