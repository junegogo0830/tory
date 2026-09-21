import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 기본 [MaterialScrollBehavior]는 마우스 드래그를 스크롤/시트 크기 조절
/// 제스처로 인정하지 않는다(touch/stylus만 허용) — 그래서 웹/데스크톱에서
/// 마우스로 아무리 끌어도 DraggableScrollableSheet가 반응하지 않았다.
/// 마우스를 드래그 가능한 포인터 종류에 추가해 터치와 동일하게 동작하게 한다.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
