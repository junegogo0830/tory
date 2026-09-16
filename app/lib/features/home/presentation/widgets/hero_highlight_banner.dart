import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hero_highlights.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// 홈 화면 큰 히어로 배너 — 사진 자체에 이미 제목/설명이 다 들어있는 완성된
/// 배너 이미지를 원본 비율 그대로(잘리거나 늘어나지 않게) 보여주고, 실제
/// 장소 상세로 넘어가는 "자세히 보기"만 얹는다. 여러 장을 순서대로 자동
/// 회전(+손으로 넘기기)한다.
class HeroHighlightBanner extends StatefulWidget {
  const HeroHighlightBanner({super.key});

  @override
  State<HeroHighlightBanner> createState() => _HeroHighlightBannerState();
}

class _HeroHighlightBannerState extends State<HeroHighlightBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  // 원본 사진 실제 비율(1938x811 → 리사이즈한 1200x502도 같은 비율) — 이 값이
  // 아니면 BoxFit이 사진을 자르거나 늘여서 사진 안에 이미 그려진 글자가
  // 잘려나간다(실제로 그래서 한 번 사고 남).
  static const _imageAspectRatio = 1200 / 502;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final next = (_index + 1) % heroHighlights.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(
        aspectRatio: _imageAspectRatio,
        child: PageView.builder(
          controller: _controller,
          itemCount: heroHighlights.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _HeroSlide(highlight: heroHighlights[i]),
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.highlight});

  final HeroHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 원본 비율 그대로라 contain이든 cover든 결과는 같지만, 혹시 리사이즈
        // 과정에서 아주 조금 어긋나더라도 사진이 잘리지 않도록 contain을 쓴다.
        Positioned.fill(child: Image.asset(highlight.imageAsset, fit: BoxFit.contain)),
        Positioned(
          right: 10,
          bottom: 10,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => context.push('/compare/${highlight.locationId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '자세히 보기',
                          style: AppTypography.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                        ),
                        Icon(Icons.chevron_right, size: 14, color: AppColors.ink),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
