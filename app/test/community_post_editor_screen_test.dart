import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/features/community/domain/community_board.dart';
import 'package:yetgil_app/features/community/presentation/community_post_editor_screen.dart';

Future<void> _pump(WidgetTester tester, CommunityPostEditorArgs args) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: CommunityPostEditorScreen(args: args),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('자유 게시판 글쓰기 화면이 예외 없이 렌더링된다', (tester) async {
    await _pump(tester, CommunityPostEditorArgs(region: '서울 종로구', board: communityBoardById('free')));

    expect(tester.takeException(), isNull);
    expect(find.text('자유 게시판'), findsOneWidget);
    expect(find.text('등록'), findsOneWidget);
    // 초기 상태엔 빈 텍스트 블록이 하나 있어야 계속 이어 쓸 수 있다.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('주민 게시판은 중고거래/자유글 토글을 보여준다', (tester) async {
    await _pump(tester, CommunityPostEditorArgs(region: '서울 종로구', board: communityBoardById('resident')));

    expect(tester.takeException(), isNull);
    expect(find.text('중고거래'), findsOneWidget);
    expect(find.text('자유글'), findsOneWidget);
    // 기본값은 중고거래라 가격/거래상태 필드가 바로 보여야 한다.
    expect(find.text('가격 (비우면 나눔)'), findsOneWidget);
  });

  testWidgets('추억 게시판은 사진 없이 등록하면 안내를 띄운다', (tester) async {
    await _pump(tester, CommunityPostEditorArgs(region: '서울 종로구', board: communityBoardById('memory')));

    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('사진을 첨부해주세요'), findsOneWidget);
  });

  testWidgets('관광정보 게시판은 장소 검색 필드를 보여준다', (tester) async {
    await _pump(tester, CommunityPostEditorArgs(region: '서울 종로구', board: communityBoardById('info')));

    expect(tester.takeException(), isNull);
    expect(find.text('이 이야기의 장소를 검색해보세요 (선택)'), findsOneWidget);
  });
}
