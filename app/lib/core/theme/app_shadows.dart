import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 엘리베이션.
///
/// 이전 값(카드 0.04~0.06 alpha)은 대부분 화면에서 거의 안 보일 정도로 옅어서
/// "AI가 대충 만든 것 같은 밋밋한 느낌"이라는 피드백을 받았다 — 여전히
/// 자극적이지 않되(과하면 촌스러워진다) 실제로 눈에 띄는 정도로 올렸다.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.06), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.11), blurRadius: 26, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> tile = [
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.06), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color.fromRGBO(31, 26, 22, 0.10), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
