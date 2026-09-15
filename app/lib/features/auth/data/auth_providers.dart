import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/token_storage.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/repository_providers.dart';

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

  Future<void> loginWithKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).loginWithKakao();
      return true;
    });
  }

  /// 웹 전용 — 카카오 인증 서버 리다이렉트로 돌아온 뒤 main.dart가 호출한다.
  Future<void> completeKakaoWebLogin(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).completeKakaoWebLogin(code);
      return true;
    });
  }

  Future<void> loginWithPassword(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).loginWithPassword(username, password);
      return true;
    });
  }

  Future<void> signup({
    required String username,
    required String password,
    required bool agreeTerms,
    required bool agreePrivacy,
    bool agreeMarketing = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signup(
            username: username,
            password: password,
            agreeTerms: agreeTerms,
            agreePrivacy: agreePrivacy,
            agreeMarketing: agreeMarketing,
          );
      return true;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
