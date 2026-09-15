import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/features/custom_course/presentation/custom_course_create_screen.dart';

void main() {
  testWidgets('코스 공유 만들기 화면이 예외/오버플로우 없이 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          theme: null,
          home: CustomCourseCreateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('코스 공유 만들기', skipOffstage: false), findsOneWidget);
    expect(find.text('코스 등록하기', skipOffstage: false), findsOneWidget);
    expect(find.text('장소 추가', skipOffstage: false), findsOneWidget);
    expect(find.text('커스텀 코스에서 가져오기', skipOffstage: false), findsOneWidget);

    // 회귀 방지: bottomNavigationBar 안 Center가 세로로도 "가능한 한 크게"
    // 확장해버려서(Center 기본 동작) 남은 body(ListView) 높이가 0으로 짜부라진
    // 적이 있다 — 화면엔 하단 바만 둥둥 뜨고 나머지가 통째로 안 보였다. 이
    // 화면 크기(844)의 절반은 넘는 실제 높이를 갖는지로 재발을 잡는다.
    final listViewSize = tester.getSize(find.byType(ListView));
    expect(listViewSize.height, greaterThan(400));
  });

  testWidgets('AppTheme.light로도 예외 없이 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CustomCourseCreateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
