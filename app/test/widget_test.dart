import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yetgil_app/main.dart';

void main() {
  testWidgets('홈 화면이 옛길 타이틀과 진입 카드를 보여준다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: YetgilApp()));
    await tester.pumpAndSettle();

    expect(find.text('옛길'), findsOneWidget);
    expect(find.text('그 시절 거리로 떠나기'), findsOneWidget);
  });
}
