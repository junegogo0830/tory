import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/token_storage.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../community/data/community_providers.dart';
import '../../course/data/recent_course_providers.dart';
import '../../custom_course/data/custom_course_providers.dart';
import '../../notifications/data/notification_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/presentation/saved_courses_screen.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

/// 로그인 여부만 들고 있는 가벼운 상태. 실제 사용자 데이터는 로그인 후
/// profileProvider(GET /api/profile)가 담당한다.
class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(authRepositoryProvider).hasSession();
  }

  /// 로그인 계정이 바뀔 때마다(로그인/로그아웃 모두) 이전 계정 데이터를 캐싱해둔
  /// 사용자 전용 provider들을 전부 무효화한다 — 안 그러면 A로 로그인해서 한 번
  /// 읽힌 profileProvider 등이 B로 다시 로그인해도 A의 캐시된 값을 그대로
  /// 보여줘서, 서로 다른 계정인데 화면엔 "같은 사람"처럼 보이는 버그가 생긴다
  /// (실제로 발생했던 문제 — family 없는 provider는 계정별로 자동 분리되지 않는다).
  void _invalidateUserScopedProviders() {
    ref.invalidate(profileProvider);
    ref.invalidate(myMemoriesProvider);
    ref.invalidate(myCoursesProvider);
    ref.invalidate(myRegionsProvider);
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(myCustomCoursesProvider);
    ref.invalidate(recentCourseProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(notificationSettingsProvider);
    ref.invalidate(savedCoursesProvider);
  }

  Future<void> loginWithKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).loginWithKakao();
      return true;
    });
    _invalidateUserScopedProviders();
  }

  /// 웹 전용 — 카카오 인증 서버 리다이렉트로 돌아온 뒤 main.dart가 호출한다.
  Future<void> completeKakaoWebLogin(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).completeKakaoWebLogin(code);
      return true;
    });
    _invalidateUserScopedProviders();
  }

  Future<void> loginWithNaver() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).loginWithNaver();
      return true;
    });
    _invalidateUserScopedProviders();
  }

  /// 웹 전용 — 네이버 인증 서버 리다이렉트로 돌아온 뒤 main.dart가 호출한다.
  Future<void> completeNaverWebLogin(String code, String state) async {
    this.state = const AsyncLoading();
    this.state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).completeNaverWebLogin(code, state);
      return true;
    });
    _invalidateUserScopedProviders();
  }

  Future<void> loginWithPassword(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).loginWithPassword(username, password);
      return true;
    });
    _invalidateUserScopedProviders();
  }

  Future<void> signup({
    required String username,
    required String password,
    required bool agreeTerms,
    required bool agreePrivacy,
    bool agreeMarketing = false,
    String? phoneVerificationToken,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signup(
            username: username,
            password: password,
            agreeTerms: agreeTerms,
            agreePrivacy: agreePrivacy,
            agreeMarketing: agreeMarketing,
            phoneVerificationToken: phoneVerificationToken,
          );
      return true;
    });
    _invalidateUserScopedProviders();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
    _invalidateUserScopedProviders();
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
