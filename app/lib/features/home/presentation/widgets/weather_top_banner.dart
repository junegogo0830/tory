import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/weather_info.dart';
import '../../../../shared/widgets/yetgil_mark.dart';
import '../../data/home_providers.dart';
import 'top_attractions_ticker.dart';
import 'weather_animations.dart';

/// 로고 + 작은 검색창(+프로필)을 날씨 애니메이션 배경 위에 얹은 홈 상단 배너.
/// 검색창 힌트 텍스트가 날씨/시간 기반 인사말이고, 텍스트를 입력하면 Flutter
/// TextField 기본 동작으로 자동으로 사라진다(별도 로직 불필요).
class WeatherTopBanner extends ConsumerStatefulWidget {
  const WeatherTopBanner({super.key, required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<WeatherTopBanner> createState() => _WeatherTopBannerState();
}

class _WeatherTopBannerState extends ConsumerState<WeatherTopBanner> {
  Position? _position;

  @override
  void initState() {
    super.initState();
    // 배경으로 조용히 시도한다 — 거부/실패해도 스낵바 등으로 방해하지 않고
    // 그냥 날씨 무관 기본 배너로 남는다(사용자가 직접 누른 액션이 아니라서).
    _resolvePosition();
  }

  Future<void> _resolvePosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      // 조용히 포기 — 기본 배너로 남는다.
    }
  }

  @override
  Widget build(BuildContext context) {
    // 소수점 2자리로 반올림한 좌표를 provider family 키로 써서, GPS 미세 지터로
    // 매번 새 키가 생겨 재호출되는 걸 막는다.
    final weatherAsync = _position == null
        ? const AsyncValue<WeatherInfo?>.data(null)
        : ref.watch(
            weatherProvider((
              lat: double.parse(_position!.latitude.toStringAsFixed(2)),
              lng: double.parse(_position!.longitude.toStringAsFixed(2)),
            )),
          );
    final weather = weatherAsync.value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 138,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WeatherAnimatedBackground(condition: weather?.condition),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const YetgilMark(size: 22),
                        const SizedBox(width: 7),
                        Text('옛길', style: AppTypography.title.copyWith(fontSize: 19)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _CompactSearchField(
                          controller: widget.controller,
                          onSubmitted: widget.onSubmitted,
                          hintText: _greetingFor(weather, DateTime.now()),
                        )),
                        const SizedBox(width: 8),
                        const _ProfileButton(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const HotTicker(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSearchField extends StatelessWidget {
  const _CompactSearchField({
    required this.controller,
    required this.onSubmitted,
    required this.hintText,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String hintText;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    // 흰색 배경과 갈색 테두리를 반드시 "같은" BoxDecoration 한 곳에서 그려야
    // 정확히 같은 외곽선을 공유한다 — 이전엔 흰 배경은 이 Container(radius 20)가,
    // 테두리는 앱 전역 InputDecorationTheme의 focusedBorder(포커스 시 자동 표시,
    // radius는 AppRadius.field=13)가 각각 따로 그려서 서로 다른 반지름의 두 겹으로
    // 어긋나 보였다. TextField 쪽 테두리는 전부 꺼서 이 컨테이너의 테두리만 남긴다.
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSubmitted(),
          style: AppTypography.subhead,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: hintText,
            hintStyle: AppTypography.subhead.copyWith(color: AppColors.inkTertiary),
            hintMaxLines: 1,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: AppColors.inkSecondary, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/profile'),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: AppColors.accentDeep, size: 20),
      ),
    );
  }
}

/// 날씨+시간대로 "선선한 오후예요, 어디로 떠나볼까요?" 같은 인사말을 만든다.
String _greetingFor(WeatherInfo? weather, DateTime now) {
  final hour = now.hour;
  final String timeOfDay;
  if (hour < 6) {
    timeOfDay = '새벽';
  } else if (hour < 11) {
    timeOfDay = '아침';
  } else if (hour < 14) {
    timeOfDay = '점심';
  } else if (hour < 18) {
    timeOfDay = '오후';
  } else if (hour < 21) {
    timeOfDay = '저녁';
  } else {
    timeOfDay = '밤';
  }

  String? mood;
  // condition은 "rain_day"/"rain_night"처럼 낮/밤 접미사가 붙어 있어 접두사로 본다.
  if (weather?.condition.startsWith('rain') ?? false) {
    mood = '비 내리는';
  } else if (weather?.condition.startsWith('snow') ?? false) {
    mood = '눈 내리는';
  } else if (weather != null) {
    final t = weather.temperature;
    if (t < 5) {
      mood = '추운';
    } else if (t < 12) {
      mood = '쌀쌀한';
    } else if (t < 20) {
      mood = '선선한';
    } else if (t < 27) {
      mood = '포근한';
    } else {
      mood = '더운';
    }
  }

  final prefix = mood == null ? timeOfDay : '$mood $timeOfDay';
  // "밤예요"(X) / "밤이에요"(O) — 받침 있는 음절 뒤엔 "이에요", 없으면 "예요".
  // 조사가 붙는 마지막 단어는 항상 timeOfDay라 그 끝음절 받침만 보면 된다.
  final copula = _hasFinalConsonant(timeOfDay) ? '이에요' : '예요';
  return '$prefix$copula, 어디로 떠나볼까요?';
}

/// 한글 완성형 음절(가~힣)의 마지막 글자에 받침이 있는지 본다.
/// 유니코드 한글 음절 블록은 (코드 - 0xAC00) % 28 == 0이면 받침이 없다.
bool _hasFinalConsonant(String word) {
  if (word.isEmpty) return false;
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}
