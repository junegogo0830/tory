import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_providers.dart';
import '../../data/kakao_login_error.dart';
import '../../data/naver_login_error.dart';

/// 각 공식 로그인 버튼 이미지의 실제 가로세로 비율 — AspectRatio로 고정해야
/// Image.asset이 원본 해상도 그대로 렌더링되며 넘치는 걸 막는다.
const double _kNaverButtonAspectRatio = 1472 / 224;
const double _kKakaoButtonAspectRatio = 300 / 45;

/// 카카오 버튼 원본이 300x45로 해상도가 낮아, "아이디로 로그인"과 같은 전체
/// 폭으로 늘리면 확대되며 흐려진다 — 원본 해상도에 가깝게 폭을 제한하고
/// 가운데 정렬한다(네이버 쪽도 톤을 맞춰 같은 폭으로).
const double _kSocialButtonMaxWidth = 300;

/// 로그인/커뮤니티/프로필 게스트 카드 세 곳이 각자 복제해 쓰던 소셜 로그인
/// 버튼을 하나로 모았다 — 문구·스타일·노출 전환을 한 군데서만 바꾸면 모든
/// 화면에 반영되게 하려는 목적. [AppConstants.showKakaoLogin]/[showNaverLogin]이
/// false면 스스로 아무것도 그리지 않는다(SizedBox.shrink) — 호출부가 따로
/// if로 감쌀 필요가 없어서, 화면 하나에서 숨김 처리를 빠뜨리는 일이 구조적으로
/// 없어진다(카카오→네이버 전환 때 실제로 한 화면을 빠뜨렸던 문제).
class NaverLoginButton extends ConsumerWidget {
  const NaverLoginButton({super.key, this.onLoggedIn});

  /// 로그인 성공 후 추가로 할 일(예: 화면 이동). 로그인 상태를 지켜보다 알아서
  /// 다시 그리는 화면(커뮤니티/프로필)은 안 넘겨도 된다.
  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConstants.showNaverLogin) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSocialButtonMaxWidth),
        child: AspectRatio(
          aspectRatio: _kNaverButtonAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () async {
                await ref.read(authStateProvider.notifier).loginWithNaver();
                if (!context.mounted) return;
                final authState = ref.read(authStateProvider);
                if (authState.value == true) {
                  onLoggedIn?.call();
                } else if (authState.hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(describeNaverLoginError(authState.error))),
                  );
                }
              },
              child: Image.asset('assets/logo/naver_login.png', fit: BoxFit.cover, filterQuality: FilterQuality.high),
            ),
          ),
        ),
      ),
    );
  }
}

/// 카카오 로그인 버튼 — 카카오가 지정한 공식 버튼 이미지를 그대로 쓴다.
class KakaoLoginButton extends ConsumerWidget {
  const KakaoLoginButton({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConstants.showKakaoLogin) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSocialButtonMaxWidth),
        child: AspectRatio(
          aspectRatio: _kKakaoButtonAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () async {
                await ref.read(authStateProvider.notifier).loginWithKakao();
                if (!context.mounted) return;
                final authState = ref.read(authStateProvider);
                if (authState.value == true) {
                  onLoggedIn?.call();
                } else if (authState.hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(describeKakaoLoginError(authState.error))),
                  );
                }
              },
              child: Image.asset(
                'assets/logo/kakao_login_medium_wide.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
