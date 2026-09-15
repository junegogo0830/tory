import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/features/friend_finder/presentation/friend_finder_flow_screen.dart';

void main() {
  testWidgets('친구 찾기 화면이 예외 없이 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FriendFinderFlowScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('같은 추억을 가진 사람 찾기'), findsOneWidget);
    expect(find.text('추억 조건 추가'), findsOneWidget);
    expect(find.text('이런 추억을 가진 사람 찾기'), findsOneWidget);
  });

  testWidgets('조건 없이 찾기를 누르면 안내를 띄운다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FriendFinderFlowScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('이런 추억을 가진 사람 찾기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('추억 조건을 하나 이상 추가해주세요'), findsOneWidget);
  });
}
