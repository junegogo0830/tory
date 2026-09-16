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

enum _PhoneStep { idle, codeSent, verified }

/// 자체 회원가입 화면 — 아이디/비밀번호, 휴대폰 인증(필수), 약관 동의를 한
/// 화면에서 순서대로 진행한다. 성공하면 로그인 상태로 홈에 진입한다.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  Timer? _debounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;

  _PhoneStep _phoneStep = _PhoneStep.idle;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  String? _phoneError;
  String? _phoneVerificationToken;

  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _phoneFormatValid => RegExp(r'^01[016789]\d{7,8}$').hasMatch(_phoneController.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _sendCode() async {
    if (!_phoneFormatValid || _sendingCode) return;
    setState(() {
      _sendingCode = true;
      _phoneError = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPhoneVerificationCode(_phoneController.text.trim());
      if (mounted) setState(() => _phoneStep = _PhoneStep.codeSent);
    } catch (_) {
      if (mounted) setState(() => _phoneError = '인증번호를 보내지 못했어요. 잠시 후 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6 || _verifyingCode || _sendingCode) return;
    setState(() {
      _verifyingCode = true;
      _phoneError = null;
    });
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyPhoneVerificationCode(_phoneController.text.trim(), _codeController.text.trim());
      if (mounted) {
        setState(() {
          _phoneVerificationToken = token;
          _phoneStep = _PhoneStep.verified;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _phoneError = '인증번호가 올바르지 않거나 만료됐어요');
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  void _resetPhone() {
    setState(() {
      _phoneStep = _PhoneStep.idle;
      _phoneVerificationToken = null;
      _phoneError = null;
      _codeController.clear();
    });
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
      _phoneStep == _PhoneStep.verified &&
      _phoneVerificationToken != null &&
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
          phoneVerificationToken: _phoneVerificationToken,
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
                Row(
                  children: [
                    Text('휴대폰 인증', style: AppTypography.headline),
                    const SizedBox(width: 6),
                    Text('(필수)', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                  ],
                ),
                const SizedBox(height: 8),
                _PhoneVerificationSection(
                  step: _phoneStep,
                  phoneController: _phoneController,
                  codeController: _codeController,
                  phoneFormatValid: _phoneFormatValid,
                  sendingCode: _sendingCode,
                  verifyingCode: _verifyingCode,
                  error: _phoneError,
                  onSendCode: _sendCode,
                  onVerifyCode: _verifyCode,
                  onReset: _resetPhone,
                ),
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

class _PhoneVerificationSection extends StatelessWidget {
  const _PhoneVerificationSection({
    required this.step,
    required this.phoneController,
    required this.codeController,
    required this.phoneFormatValid,
    required this.sendingCode,
    required this.verifyingCode,
    required this.error,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onReset,
  });

  final _PhoneStep step;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool phoneFormatValid;
  final bool sendingCode;
  final bool verifyingCode;
  final String? error;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (step == _PhoneStep.verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.pastelMint,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${phoneController.text} 인증 완료', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: onReset,
              child: Text('변경', style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
            ),
          ],
        ),
      );
    }

    final phoneStepBusy = step == _PhoneStep.codeSent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: phoneController,
                enabled: !phoneStepBusy && !sendingCode && !verifyingCode,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '01012345678'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: !phoneFormatValid || sendingCode || verifyingCode ? null : onSendCode,
                child: sendingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    : Text(phoneStepBusy ? '재전송' : '인증번호 받기'),
              ),
            ),
          ],
        ),
        if (phoneStepBusy) ...[
          TextButton(onPressed: sendingCode || verifyingCode ? null : onReset, child: const Text('번호 변경')),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => onVerifyCode(),
                  decoration: const InputDecoration(hintText: '인증번호 6자리'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: verifyingCode || sendingCode ? null : onVerifyCode,
                  child: verifyingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('확인'),
                ),
              ),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: AppTypography.caption.copyWith(color: Colors.red)),
        ],
        const SizedBox(height: 4),
        Text(
          '가입하려면 휴대폰 인증을 완료해주세요. 인증번호는 5분간 유효하며 재전송은 60초 후 가능해요.',
          style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
        ),
      ],
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
