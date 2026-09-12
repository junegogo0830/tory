import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/home_providers.dart';

/// "옛길" 배너(검색창 밑)에 그대로 얹는 인기 관광지 티커. 카드/배경 없이
/// 텍스트만 — 불 아이콘 + "HOT" 라벨 옆에 순위 없이 이름만 3초마다 넘어간다.
///
/// "실시간 검색 순위"라는 요청이었지만 실제 검색 로그 집계 인프라는 아직
/// 없어서, 전국 대표 명소 10곳을 하루 단위로 캐싱해 순환 노출하는 프록시다.
class HotTicker extends ConsumerStatefulWidget {
  const HotTicker({super.key});

  @override
  ConsumerState<HotTicker> createState() => _HotTickerState();
}

class _HotTickerState extends ConsumerState<HotTicker> {
  Timer? _timer;
  int _index = 0;
  int _itemCount = 0;

  void _ensureTimer(int itemCount) {
    if (itemCount == _itemCount && _timer != null) return;
    _itemCount = itemCount;
    _timer?.cancel();
    if (itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _itemCount);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attractionsAsync = ref.watch(topAttractionsProvider);
    final attractions = attractionsAsync.value;
    if (attractions == null || attractions.isEmpty) return const SizedBox.shrink();
    _ensureTimer(attractions.length);
    final current = attractions[_index % attractions.length];

    return Row(
      children: [
        const Icon(Icons.local_fire_department, size: 15, color: AppColors.accentDeep),
        const SizedBox(width: 3),
        Text(
          'HOT',
          style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              // AnimatedSwitcher 기본 layoutBuilder는 Stack을 가운데 정렬해서
              // 텍스트가 "HOT"에서 멀리 떨어져 붕 뜬 것처럼 보였다 — 왼쪽 정렬로 붙인다.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                current.name,
                key: ValueKey(current.id),
                style: AppTypography.footnote.copyWith(color: AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
