import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/auth_error.dart';
import '../data/auth_providers.dart';
import '../data/kakao_login_error.dart';

/// 아이디/비밀번호 로그인 화면. 카카오 로그인도 대안으로 남겨둔다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요')));
      return;
    }
    setState(() => _submitting = true);
    await ref.read(authStateProvider.notifier).loginWithPassword(username, password);
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    setState(() => _submitting = false);
    if (authState.value == true) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeAuthError(authState.error))));
    }
  }

  Future<void> _loginWithKakao() async {
    await ref.read(authStateProvider.notifier).loginWithKakao();
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.value == true) {
      context.go('/');
    } else if (authState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeKakaoLoginError(authState.error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('로그인')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(hintText: '아이디'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(hintText: '비밀번호'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _login,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('아직 계정이 없으신가요? 회원가입'),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.hairline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('또는', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                    ),
                    Expanded(child: Divider(color: AppColors.hairline)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loginWithKakao,
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('카카오로 시작하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
