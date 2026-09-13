import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 시스템 다크모드 설정 변경을 감지해 [AppColors.darkModeNotifier]에 반영하고,
/// 그 값이 바뀔 때마다 [builder]를 다시 호출해 앱 전체를 새로 그린다.
///
/// [AppColors]/[AppTypography]의 색은 매 build마다 다시 평가되는 getter라,
/// 이 스코프가 없으면 시스템 설정이 바뀌어도 이미 그려진 위젯들은 갱신되지
/// 않는다 — MaterialApp을 매번 새 인스턴스로 다시 만들어야 그 아래 전체
/// 트리가 실제로 재빌드된다(같은 인스턴스를 재사용하면 프레임워크가 변경
/// 없음으로 판단해 재빌드를 건너뛴다).
class BrightnessScope extends StatefulWidget {
  const BrightnessScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<BrightnessScope> createState() => _BrightnessScopeState();
}

class _BrightnessScopeState extends State<BrightnessScope> with WidgetsBindingObserver {
  bool get _platformIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppColors.darkModeNotifier.value = _platformIsDark;
  }

  @override
  void didChangePlatformBrightness() {
    AppColors.darkModeNotifier.value = _platformIsDark;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.darkModeNotifier,
      builder: (context, _, _) => widget.builder(context),
    );
  }
}
