import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yetgil_app/core/theme/app_theme.dart';
import 'package:yetgil_app/data/api/api_client.dart';
import 'package:yetgil_app/data/models/custom_course.dart';
import 'package:yetgil_app/data/models/memory_attribute.dart';
import 'package:yetgil_app/data/models/profile.dart';
import 'package:yetgil_app/data/models/saved_course.dart';
import 'package:yetgil_app/data/repositories/community_repository.dart';
import 'package:yetgil_app/data/repositories/memory_repository.dart';
import 'package:yetgil_app/data/repositories/repository_providers.dart';
import 'package:yetgil_app/features/custom_course/data/custom_course_providers.dart';
import 'package:yetgil_app/features/profile/data/profile_providers.dart';
import 'package:yetgil_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:yetgil_app/features/profile/presentation/my_custom_courses_screen.dart';
import 'package:yetgil_app/features/profile/presentation/profile_info_edit_screen.dart';
import 'package:yetgil_app/features/profile/presentation/saved_courses_screen.dart';

const _profile = Profile(
  userId: 1,
  displayName: '테스터',
  tagline: '나의 추억 여행을 기록하고 있어요',
  registeredCourseCount: 2,
  savedCourseCount: 1,
  postCount: 5,
  savedLocations: [],
  homeRegion: '경기 수원시',
  ageGroup: '20대',
  gender: '여성',
  fullName: '김철수',
  phoneNumber: '01012345678',
  onboardingCompleted: true,
  hasPassword: true,
);

class _FakeCommunityRepository extends CommunityRepository {
  _FakeCommunityRepository() : super(ApiClient());
  @override
  Future<List<String>> myRegions() async => ['경기 수원시', '학교·옛길고등학교'];
}

class _EmptyMemoryRepository extends MemoryRepository {
  _EmptyMemoryRepository() : super(ApiClient());
  @override
  Future<List<MemoryAttribute>> myAttributes() async => [];
}

void main() {
  testWidgets('프로필 수정 화면이 가입한 커뮤니티/정보 수정 진입점을 보여준다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => _profile),
          communityRepositoryProvider.overrideWithValue(_FakeCommunityRepository()),
        ],
        child: const MaterialApp(theme: null, home: EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('현재 가입한 커뮤니티'), findsOneWidget);
    expect(find.text('경기 수원시'), findsWidgets);
    expect(find.text('학교·옛길고등학교'), findsOneWidget);
    expect(find.text('정보 수정'), findsOneWidget);
    expect(find.text('내 계정 관리'), findsOneWidget);
    // 연령대 칩은 이 화면에서 빠지고 정보 수정 화면으로 옮겨갔다.
    expect(find.text('연령대'), findsNothing);
    expect(find.text('사는 지역'), findsNothing);
  });

  testWidgets('정보 수정 화면이 예외 없이 렌더링되고 저장된 값을 채운다', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => _profile),
          memoryRepositoryProvider.overrideWithValue(_EmptyMemoryRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ProfileInfoEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('나이'), findsOneWidget);
    expect(find.text('사는 곳'), findsOneWidget);
    expect(find.text('성별'), findsOneWidget);
    expect(find.text('모교'), findsOneWidget);
    expect(find.text('살았던 곳'), findsOneWidget);
    expect(find.widgetWithText(TextField, '김철수'), findsOneWidget);
  });

  testWidgets('등록한 코스 화면이 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myCustomCoursesProvider.overrideWith((ref) async => <CustomCourseSummary>[]),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MyCustomCoursesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('등록한 코스'), findsOneWidget);
    expect(find.text('아직 등록한 코스가 없어요'), findsOneWidget);
  });

  testWidgets('저장한 코스 화면이 목록을 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCoursesProvider.overrideWith(
            (ref) async => [
              SavedCourse(
                courseType: 'custom',
                courseId: '1',
                title: '나만의 코스',
                category: '산책',
                placeCount: 3,
                savedAt: DateTime(2026, 9, 15),
              ),
            ],
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedCoursesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('저장한 코스'), findsOneWidget);
    expect(find.text('나만의 코스'), findsOneWidget);
  });
}
