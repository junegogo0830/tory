import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// 조건별(날씨×낮/밤) 배경 그라디언트 + 애니메이션 파티클.
///
/// "애플 날씨 앱처럼"이 요청이었지만, 이 앱은 거의 무채색+브라운 단일 강조색
/// 디자인이라(AppColors 참고) 실제 하늘색/짙은 회색을 그대로 쓰면 톤이 깨진다.
/// 그래서 세피아/브라운 팔레트 안에서만 변주하고, 밤에도 크게 어두워지지
/// 않게 해서 로고/검색창 글자 가독성을 항상 유지한다.
///
/// 조건은 항상 `{clear|cloudy|overcast|rain|snow}_{day|night}` 10가지 — "비 오는
/// 아침"과 "비 오는 밤"이 다른 애니메이션이어야 한다는 피드백으로 낮/밤을
/// clear뿐 아니라 전부에 적용했고, 처음 버전이 "덮여있는 줄" 알 정도로 흐렸다는
/// 피드백으로 불투명도/크기/개수를 전체적으로 크게 올렸다.
class WeatherAnimatedBackground extends StatefulWidget {
  const WeatherAnimatedBackground({super.key, required this.condition});

  final String? condition;

  @override
  State<WeatherAnimatedBackground> createState() => _WeatherAnimatedBackgroundState();
}

class _WeatherAnimatedBackgroundState extends State<WeatherAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _gradientFor(widget.condition)),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WeatherPainter(condition: widget.condition, progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

bool _isNight(String? condition) => condition != null && condition.endsWith('_night');

LinearGradient _gradientFor(String? condition) {
  const begin = Alignment.topLeft;
  const end = Alignment.bottomRight;
  List<Color> colors;
  switch (condition) {
    case 'clear_day':
      colors = const [Color(0xFFFBF3E0), Color(0xFFEAD5AC)];
    case 'clear_night':
      colors = const [Color(0xFFD8C7A8), Color(0xFFAD8F63)];
    case 'cloudy_day':
      colors = const [Color(0xFFEDE6D6), Color(0xFFD7CBAF)];
    case 'cloudy_night':
      colors = const [Color(0xFFCBBFA3), Color(0xFFA79878)];
    case 'overcast_day':
      colors = const [Color(0xFFDDD3BD), Color(0xFFC0B08C)];
    case 'overcast_night':
      colors = const [Color(0xFFC2B294), Color(0xFF998970)];
    case 'rain_day':
      colors = const [Color(0xFFD3C6AE), Color(0xFFA89676)];
    case 'rain_night':
      colors = const [Color(0xFFB6A688), Color(0xFF8C7A5C)];
    case 'snow_day':
      colors = const [Color(0xFFF6F0E2), Color(0xFFE0D3B4)];
    case 'snow_night':
      colors = const [Color(0xFFDACFB6), Color(0xFFB9A886)];
    default:
      colors = [AppColors.accentTint, AppColors.paper];
  }
  return LinearGradient(colors: colors, begin: begin, end: end);
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({required this.condition, required this.progress});

  final String? condition;
  final double progress; // 0..1, AnimationController.repeat()로 순환.

  @override
  void paint(Canvas canvas, Size size) {
    final night = _isNight(condition);
    final base = condition?.split('_').first;

    switch (base) {
      case 'clear':
        night ? _paintMoonAndStars(canvas, size) : _paintSunGlow(canvas, size);
      case 'cloudy':
        _paintClouds(canvas, size, count: 3, opacity: night ? 0.55 : 0.5);
      case 'overcast':
        _paintClouds(canvas, size, count: 5, opacity: night ? 0.7 : 0.62);
      case 'rain':
        _paintClouds(canvas, size, count: 4, opacity: night ? 0.6 : 0.5);
        _paintRain(canvas, size, night: night);
      case 'snow':
        _paintClouds(canvas, size, count: 3, opacity: night ? 0.45 : 0.35);
        _paintSnow(canvas, size, night: night);
      default:
        break;
    }
  }

  void _paintSunGlow(Canvas canvas, Size size) {
    final pulse = 0.82 + 0.18 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi));
    final center = Offset(size.width * 0.84, size.height * 0.3);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.accent.withValues(alpha: 0.42 * pulse), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: 110));
    canvas.drawCircle(center, 110, paint);

    final corePaint = Paint()..color = AppColors.surface.withValues(alpha: 0.55 * pulse);
    canvas.drawCircle(center, 20, corePaint);
  }

  void _paintMoonAndStars(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.84, size.height * 0.28);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.surface.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: 60));
    canvas.drawCircle(moonCenter, 60, glowPaint);
    canvas.drawCircle(moonCenter, 16, Paint()..color = AppColors.surface.withValues(alpha: 0.85));

    final random = math.Random(7);
    for (var i = 0; i < 22; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height * 0.7;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + i));
      final paint = Paint()..color = AppColors.surface.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(dx, dy), 1.9, paint);
    }
  }

  /// 좁은 배너(128px) 안에서 원 여러 개를 뚜렷하게 겹쳐 그리면 낱개 동그라미가
  /// 다 보여서 "조잡한 클립아트"처럼 보인다는 피드백이 있었다. 대신 넓적한 타원
  /// 2~3장을 강하게 블러(edge가 안 보일 정도)해서 하나의 부드러운 구름 덩어리로
  /// 뭉치고, 그림자도 전체 뭉치 밑에 한 장만 깔아 과하지 않게 입체감만 준다.
  void _paintClouds(Canvas canvas, Size size, {required int count, required double opacity}) {
    final fillPaint = Paint()
      ..color = AppColors.surface.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final shadePaint = Paint()
      ..color = AppColors.accentDeep.withValues(alpha: opacity * 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    for (var i = 0; i < count; i++) {
      final baseX = (i / count) * (size.width + 240) - 120;
      final drift = ((progress + i * 0.25) % 1.0) * (size.width + 240);
      final dx = (baseX + drift) % (size.width + 240) - 120;
      final dy = size.height * (0.18 + 0.16 * i);
      final scale = 0.9 + 0.25 * ((i * 37) % 5) / 4;

      final shadowRect = Rect.fromCenter(
        center: Offset(dx, dy + 5 * scale),
        width: 128 * scale,
        height: 34 * scale,
      );
      canvas.drawOval(shadowRect, shadePaint);

      for (final layer in const [
        (dxOff: 0.0, dyOff: 0.0, w: 100.0, h: 30.0),
        (dxOff: -26.0, dyOff: 4.0, w: 62.0, h: 26.0),
        (dxOff: 30.0, dyOff: 5.0, w: 56.0, h: 24.0),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dx + layer.dxOff * scale, dy + layer.dyOff * scale),
            width: layer.w * scale,
            height: layer.h * scale,
          ),
          fillPaint,
        );
      }
    }
  }

  void _paintRain(Canvas canvas, Size size, {required bool night}) {
    final paint = Paint()
      ..color = AppColors.accentDeep.withValues(alpha: night ? 0.5 : 0.4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final random = math.Random(3);
    const count = 26;
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final fall = (progress + i * 0.081) % 1.0;
      final y0 = fall * (size.height + 30) - 30;
      canvas.drawLine(Offset(x, y0), Offset(x - 8, y0 + 18), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size, {required bool night}) {
    final paint = Paint()..color = AppColors.accentDeep.withValues(alpha: night ? 0.5 : 0.4);
    final random = math.Random(5);
    const count = 22;
    for (var i = 0; i < count; i++) {
      final xSeed = random.nextDouble();
      final fall = (progress + i * 0.091) % 1.0;
      final sway = math.sin(fall * 2 * math.pi + i) * 10;
      final x = xSeed * size.width + sway;
      final y = fall * size.height;
      final radius = 1.4 + (i % 3) * 0.6;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.condition != condition;
}
