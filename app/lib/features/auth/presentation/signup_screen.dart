import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../data/auth_error.dart';
import '../data/auth_providers.dart';
import 'terms_detail_screen.dart';
import 'terms_text.dart';

const _kMinPasswordLength = 8;

/// 자체 회원가입 화면 — 아이디/비밀번호, 약관 동의를 한 화면에서 순서대로
/// 진행한다. 성공하면 로그인 상태로 홈에 진입한다.
///
/// 휴대폰 본인확인은 뺐다 — SMS 발송 업체(NCP SENS 등)가 전부 사업자 등록을
/// 요구해서 개인 프로젝트 단계에서는 막혀 있다. AuthRepository의
/// sendPhoneVerificationCode/verifyPhoneVerificationCode는 나중에 업체를
/// 구하면 이 화면에 다시 연결할 수 있게 그대로 남아있다.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Timer? _debounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;

  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _usernameFormatValid => RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(_usernameController.text.trim());

  void _onUsernameChanged() {
    _debounce?.cancel();
    setState(() => _usernameAvailable = null);
    if (!_usernameFormatValid) return;
    _debounce = Timer(const Duration(milliseconds: 400), _checkUsername);
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();
    setState(() => _checkingUsername = true);
    try {
      final available = await ref.read(authRepositoryProvider).isUsernameAvailable(username);
      if (mounted && _usernameController.text.trim() == username) {
        setState(() => _usernameAvailable = available);
      }
    } catch (_) {
      // 조용히 실패 — 최종 제출 시 백엔드가 다시 확인해준다.
    } finally {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  bool get _canSubmit =>
      _usernameFormatValid &&
      _usernameAvailable != false &&
      _passwordController.text.length >= _kMinPasswordLength &&
      _passwordController.text == _confirmController.text &&
      _agreeTerms &&
      _agreePrivacy &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    await ref.read(authStateProvider.notifier).signup(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          agreeTerms: _agreeTerms,
          agreePrivacy: _agreePrivacy,
          agreeMarketing: _agreeMarketing,
        );
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    setState(() => _submitting = false);
    if (authState.value == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('환영해요! 가입이 완료됐어요')));
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeAuthError(authState.error))));
    }
  }

  void _showTerms(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TermsDetailScreen(title: title, body: body)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text('아이디', style: AppTypography.headline),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: '영문/숫자/밑줄(_) 4~20자',
                    counterText: '',
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                          )
                        : _usernameAvailable == null
                            ? null
                            : Icon(
                                _usernameAvailable! ? Icons.check_circle : Icons.cancel,
                                color: _usernameAvailable! ? Colors.green : Colors.red,
                              ),
                  ),
                ),
                if (_usernameController.text.isNotEmpty && !_usernameFormatValid) ...[
                  const SizedBox(height: 4),
                  Text('영문/숫자/밑줄 4~20자로 입력해주세요', style: AppTypography.caption.copyWith(color: Colors.red)),
                ] else if (_usernameAvailable == false) ...[
                  const SizedBox(height: 4),
                  Text('이미 사용 중인 아이디예요', style: AppTypography.caption.copyWith(color: Colors.red)),
                ],
                const SizedBox(height: 18),
                Text('비밀번호', style: AppTypography.headline),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '8자 이상'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '비밀번호 확인'),
                ),
                if (_confirmController.text.isNotEmpty && _confirmController.text != _passwordController.text) ...[
                  const SizedBox(height: 4),
                  Text('비밀번호가 일치하지 않아요', style: AppTypography.caption.copyWith(color: Colors.red)),
                ],
                const SizedBox(height: 22),
                Text('약관 동의', style: AppTypography.headline),
                const SizedBox(height: 6),
                _AllAgreeRow(
                  checked: _agreeTerms && _agreePrivacy && _agreeMarketing,
                  onChanged: (value) => setState(() {
                    _agreeTerms = value;
                    _agreePrivacy = value;
                    _agreeMarketing = value;
                  }),
                ),
                Divider(color: AppColors.hairline),
                _AgreementRow(
                  label: '[필수] 서비스 이용약관',
                  checked: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v),
                  onView: () => _showTerms('서비스 이용약관', kTermsOfServiceText),
                ),
                _AgreementRow(
                  label: '[필수] 개인정보처리방침',
                  checked: _agreePrivacy,
                  onChanged: (v) => setState(() => _agreePrivacy = v),
                  onView: () => _showTerms('개인정보처리방침', kPrivacyPolicyText),
                ),
                _AgreementRow(
                  label: '[선택] 마케팅 정보 수신 동의',
                  checked: _agreeMarketing,
                  onChanged: (v) => setState(() => _agreeMarketing = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('가입하기'),
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

class _AllAgreeRow extends StatelessWidget {
  const _AllAgreeRow({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false), activeColor: AppColors.accent),
            Text('전체 동의', style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.label, required this.checked, required this.onChanged, this.onView});

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => onChanged(!checked),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false), activeColor: AppColors.accent),
                Text(label, style: AppTypography.body),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (onView != null)
          TextButton(
            onPressed: onView,
            child: Text('보기', style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
          ),
      ],
    );
  }
}
