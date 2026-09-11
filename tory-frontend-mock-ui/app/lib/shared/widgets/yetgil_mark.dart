import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 옛길 단순화 마크의 코드 기반 placeholder.
/// 실제 트레이싱된 SVG(assets/logo/mark_simple.svg)로 교체되기 전까지 헤더/탭 아이콘에 사용한다.
class YetgilMark extends StatelessWidget {
  const YetgilMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()..color = AppColors.charcoal;
    canvas.drawCircle(center, radius, circlePaint);

    final seamPaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = size.width * 0.03;
    canvas.drawLine(
      Offset(center.dx, size.height * 0.1),
      Offset(center.dx, size.height * 0.9),
      seamPaint,
    );

    final pinPaint = Paint()..color = AppColors.gold;
    canvas.drawCircle(Offset(center.dx, size.height * 0.4), size.width * 0.1, pinPaint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}
