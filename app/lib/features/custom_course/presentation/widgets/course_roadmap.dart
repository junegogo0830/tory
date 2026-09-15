import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/photo_fallback.dart';

/// 코스 로드맵 한 칸.
class CourseRoadmapItem {
  const CourseRoadmapItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.onRemove,
    this.onEditPhoto,
    this.side,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  // null이면(상세 보기 모드) 삭제 버튼을 안 보여준다.
  final VoidCallback? onRemove;
  // null이 아니면(작성/수정 모드) 썸네일에 카메라 배지가 붙어 직접 사진을 등록할 수 있다.
  final VoidCallback? onEditPhoto;
  // 장소 카드 오른쪽에 나란히 붙는 위젯 — 장소별 코멘트 입력/표시에 쓴다.
  final Widget? side;
}

/// 장소들을 번호 매긴 세로 로드맵으로 보여주는 위젯 — 코스 커스텀 작성/상세
/// 화면이 공유한다. 왼쪽 레일에 번호 배지 + 연결선을 그리고, 각 장소는
/// 사진+이름+주소 카드로, 코멘트가 있으면 그 옆에 나란히 붙는다.
/// [trailingAdd]를 주면(작성 화면) 마지막에 점선으로 이어지는 "+" 칸이
/// 하나 더 붙어서 다음 장소를 추가할 수 있다.
class CourseRoadmap extends StatelessWidget {
  const CourseRoadmap({super.key, required this.items, this.trailingAdd});

  final List<CourseRoadmapItem> items;
  final VoidCallback? trailingAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _RoadmapRow(
            rail: _RoadmapRail(
              number: i + 1,
              lineStyle: i == items.length - 1
                  ? (trailingAdd != null ? _LineStyle.dashed : _LineStyle.none)
                  : _LineStyle.solid,
            ),
            item: items[i],
          ),
        if (trailingAdd != null) _RoadmapAddRow(onTap: trailingAdd!),
      ],
    );
  }
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow({required this.rail, required this.item});

  final Widget rail;
  final CourseRoadmapItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            rail,
            const SizedBox(width: 10),
            Expanded(flex: item.side != null ? 11 : 20, child: _PlaceCard(item: item)),
            if (item.side != null) ...[
              const SizedBox(width: 8),
              Expanded(flex: 9, child: item.side!),
            ],
          ],
        ),
      ),
    );
  }
}

enum _LineStyle { none, solid, dashed }

/// 로드맵 왼쪽 레일 한 칸 — 번호 배지 + 다음 칸으로 이어지는 세로선.
class _RoadmapRail extends StatelessWidget {
  const _RoadmapRail({required this.number, required this.lineStyle});

  final int number;
  final _LineStyle lineStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Column(
        children: [
          _NumberBadge(number: number),
          if (lineStyle != _LineStyle.none)
            Expanded(
              child: lineStyle == _LineStyle.dashed
                  ? const _DashedVerticalLine()
                  : Container(width: 2, color: AppColors.accent),
            ),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, this.hollow = false});

  final int number;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hollow ? AppColors.surface : AppColors.accent,
        shape: BoxShape.circle,
        border: hollow ? Border.all(color: AppColors.accent, width: 1.6) : null,
      ),
      child: hollow
          ? null
          : Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _DashedVerticalLine extends StatelessWidget {
  const _DashedVerticalLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(2, double.infinity), painter: _DashLinePainter());
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(1, y), Offset(1, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashLinePainter oldDelegate) => false;
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.item});

  final CourseRoadmapItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: item.imageUrl == null
                        ? const PhotoFallback()
                        : AppNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const PhotoFallback(),
                            errorWidget: (_, _, _) => const PhotoFallback(),
                          ),
                  ),
                ),
                if (item.onEditPhoto != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: GestureDetector(
                      onTap: item.onEditPhoto,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (item.onRemove != null) ...[
              const SizedBox(width: 2),
              InkWell(
                onTap: item.onRemove,
                child: Icon(Icons.close, size: 15, color: AppColors.inkTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 마지막 칸 — 점선 원(다음 번호) + 점선 테두리 "다음 장소 추가" 버튼.
class _RoadmapAddRow extends StatelessWidget {
  const _RoadmapAddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 24, child: _NumberBadge(number: 0, hollow: true)),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CustomPaint(
                painter: _DashedRRectPainter(radius: AppRadius.card, color: AppColors.accent),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 17, color: AppColors.accentDeep),
                      const SizedBox(width: 6),
                      Text(
                        '다음 장소 추가',
                        style: AppTypography.footnote.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next.toDouble()), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
