import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yetgil_app/main.dart';

void main() {
  testWidgets('홈 화면이 옛길의 핵심 탐색 요소를 보여준다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: YetgilApp()));
    await tester.pumpAndSettle();

    expect(find.text('옛길'), findsOneWidget);
    expect(find.text('그리운 동네를 찾아보세요'), findsOneWidget);
    expect(find.text('과거와 지금'), findsWidgets);
  });

  testWidgets('하단 탭에서 네 개의 목업 화면으로 이동한다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: YetgilApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('이번 주 추천 골목'), findsOneWidget);

    await tester.tap(find.text('코스'));
    await tester.pumpAndSettle();
    expect(find.text('순천만 노을 산책 코스'), findsOneWidget);

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('나의 옛길'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('가족과 추억을 공유해보세요'),
      500,
    );
    expect(find.text('가족과 추억을 공유해보세요'), findsOneWidget);
  });
}
