import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/api/api_client.dart';
import 'package:yetgil_app/data/models/connection_request.dart';
import 'package:yetgil_app/data/models/memory_attribute.dart';
import 'package:yetgil_app/data/repositories/connection_repository.dart';
import 'package:yetgil_app/data/repositories/memory_repository.dart';
import 'package:yetgil_app/data/repositories/repository_providers.dart';
import 'package:yetgil_app/features/friend_finder/presentation/connections_screen.dart';
import 'package:yetgil_app/features/friend_finder/presentation/my_memory_attributes_screen.dart';

// 이 화면들은 initState에서 바로 레포지토리를 호출한다(FutureProvider가 아니라
// State 내부에서 직접 호출하는 구조). 실제 dio 소켓 연결은 테스트 환경에서
// 10초 커넥션 타임아웃을 실제로 기다리다 pumpAndSettle이 타임아웃 나므로,
// initState가 쓰는 메서드만 즉시 응답하도록 오버라이드해서 렌더링만 확인한다.
class _EmptyMemoryRepository extends MemoryRepository {
  _EmptyMemoryRepository() : super(ApiClient());
  @override
  Future<List<MemoryAttribute>> myAttributes() async => [];
}

class _EmptyConnectionRepository extends ConnectionRepository {
  _EmptyConnectionRepository() : super(ApiClient());
  @override
  Future<List<ConnectionRequestModel>> connections() async => [];
}

void main() {
  testWidgets('나의 추억 조건 관리 화면이 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryRepositoryProvider.overrideWithValue(_EmptyMemoryRepository())],
        child: MaterialApp(theme: AppTheme.light, home: const MyMemoryAttributesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('나의 추억 조건 관리'), findsOneWidget);
    expect(find.text('추억 조건 추가'), findsOneWidget);
  });

  testWidgets('친구 목록 화면이 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectionRepositoryProvider.overrideWithValue(_EmptyConnectionRepository())],
        child: MaterialApp(theme: AppTheme.light, home: const ConnectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('친구 목록'), findsOneWidget);
  });
}
