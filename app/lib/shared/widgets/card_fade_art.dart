import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// 카드 오른쪽 끝에 은은하게 페이드되며 걸리는 배경 사진 — 카드 안 실제
/// 내용(Row 등) 뒤에 겹쳐 쓴다.
///
/// 사용법: `Stack(children: [CardFadeArt(imageAsset: ...), Row(...실제 내용...)])`
/// 처럼 장식을 먼저, 내용을 나중에 넣는다 — Stack은 나중 것이 위에 그려진다.
class CardFadeArt extends StatelessWidget {
  const CardFadeArt({super.key, required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 원본 사진(가로로 긴 배너)이 이 카드보다 훨씬 넓은 비율이라 BoxFit.cover가
            // 세로로 꽤 잘라낸다 — 가운데 정렬(centerRight)이면 하늘 대신 지붕/해처럼
            // 사진에서 정작 중요한 윗부분이 잘려나가 어색해 보였다. 사진들이 전부
            // 위쪽에 볼거리(지붕, 산, 해)가 있고 아래쪽은 나무/길처럼 잘려도 무난한
            // 구도라 topRight로 위쪽 내용을 우선 보존한다.
            Image.asset(imageAsset, fit: BoxFit.cover, alignment: Alignment.topRight),
            // 왼쪽(글자가 있는 쪽)은 카드 배경색으로 완전히 덮고, 오른쪽으로
            // 갈수록 투명해지며 사진이 드러나게 한다.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.0, 0.42, 0.85],
                  colors: [
                    AppColors.surface,
                    AppColors.surface,
                    AppColors.surface.withValues(alpha: 0),
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
