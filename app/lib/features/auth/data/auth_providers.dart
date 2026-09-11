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

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
