import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/community_board.dart';
import 'community_post_editor_screen.dart';

/// compare_screen(특정 장소 상세)의 "추억 등록" 카드가 쓰는 얇은 래퍼 — 항상
/// 추억 게시판에 사진과 함께 올린다.
Future<void> showMemoryUploadFlow(
  BuildContext context,
  WidgetRef ref, {
  required String region,
  String? locationId,
}) {
  return showCommunityPostFlow(
    context,
    ref,
    region: region,
    board: communityBoardById('memory'),
    locationId: locationId,
  );
}

/// 게시판별 글쓰기 진입점. 로그인 확인 후 블로그 스타일 풀페이지 에디터
/// (community_post_editor_screen.dart)로 넘어간다. 4개 게시판(자유/추억/주민/
/// 관광정보)이 전부 같은 화면을 쓰되, 게시판별 필드(사진 필수/가격/장소 첨부
/// 등)는 그 화면 안에서 board 값에 따라 갈린다.
Future<void> showCommunityPostFlow(
  BuildContext context,
  WidgetRef ref, {
  required String region,
  required CommunityBoard board,
  String? locationId,
}) async {
  final isLoggedIn = ref.read(authStateProvider).value ?? false;
  if (!isLoggedIn) {
    // 회원만 가능한 액션 — 안내만 하고 끝내는 대신 바로 가입 화면(프로필 탭의
    // 로그인 카드)으로 보낸다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${board.label}에 글을 쓰려면 먼저 로그인해주세요')),
    );
    // '/profile'은 StatefulShellRoute 브랜치라 push로 들어가면 셸이 중복
    // 생성돼 Page key 충돌 assertion이 난다(실제로 재현 확인) — go로 전환한다.
    context.go('/profile');
    return;
  }

  context.push(
    '/community/write',
    extra: CommunityPostEditorArgs(region: region, board: board, locationId: locationId),
  );
}
