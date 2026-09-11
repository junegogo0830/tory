import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 엘리베이션. 연하게 유지한다 — 진하면 촌스러워진다.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.04), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.06), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> tile = [
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.04), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.06), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
