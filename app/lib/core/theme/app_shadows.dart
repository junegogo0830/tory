import 'package:flutter/material.dart';

/// 옛길 디자인 시스템 엘리베이션.
///
/// 카드가 paper 배경 위에 "살짝 떠 있다" 정도만 느껴지게 한다. 이전 값(10~11%,
/// blur 26)은 모든 카드가 똑같이 무거운 그림자를 달고 있어 화면이 답답하고
/// 템플릿처럼 보였다 — 상용 앱은 배경/카드 명도 차로 구분하고 그림자는 거의
/// 안 쓴다. 그림자가 필요한 곳은 [card]/[tile]만 쓰고 직접 만들지 않는다.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color.fromRGBO(65, 47, 34, 0.07), blurRadius: 8, offset: Offset(0, 3)),
  ];

  // 선택/강조 상태의 카드 — card보다 살짝만 짙게.
  static const List<BoxShadow> cardSelected = [
    BoxShadow(color: Color.fromRGBO(65, 47, 34, 0.09), blurRadius: 8, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> tile = [
    BoxShadow(color: Color.fromRGBO(65, 47, 34, 0.06), blurRadius: 6, offset: Offset(0, 2)),
  ];
}
