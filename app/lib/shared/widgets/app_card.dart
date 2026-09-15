import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';

/// 옛길 디자인 시스템의 기본 단위: 얇은 브라운 계열 테두리 + 살짝 붙는
/// 그림자를 쓰는 "Standard Card". 크게 퍼지는 그림자로 붕 떠 보이게 하지
/// 않는다 — 카드가 아니라 실제 GUI 컴포넌트처럼 보이는 게 목적.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  // true면 Interactive/Selected Card 스타일(진한 테두리·그림자)을 쓴다.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: selected ? AppShadows.cardSelected : AppShadows.card,
      ),
      // border는 foregroundDecoration에 그린다 — decoration에 두면 Container가
      // border 두께만큼 [padding]에 더해 안쪽을 그만큼 더 좁혀버린다(여기 쓰이는
      // padding 값이 실제로는 항상 1px씩 더 좁게 적용된다는 뜻). 레이아웃에
      // 관여하지 않는 foregroundDecoration을 쓰면 [padding]이 선언한 그대로 적용된다.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: selected ? AppColors.accentBorder : AppColors.border),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
