import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// 과거↔현재 거리 비교의 시그니처 위젯.
/// 실제 큐레이션 이미지가 준비되면 [_ImageLayer]를 Image.asset/CachedNetworkImage로 교체한다.
class CompareSlider extends StatefulWidget {
  const CompareSlider({
    super.key,
    required this.pastYear,
    required this.currentYear,
    this.height = 360,
  });

  final int pastYear;
  final int currentYear;
  final double height;

  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider> {
  double _position = 0.5;

  void _updatePosition(double dx, double width) {
    setState(() {
      _position = (dx / width).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final seamX = _position * width;

          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);
              _updatePosition(local.dx, width);
            },
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);
              _updatePosition(local.dx, width);
            },
            child: SizedBox(
              height: widget.height,
              width: width,
              child: Stack(
                children: [
                  // 현재(뒤 레이어) — 항상 전체 표시.
                  _ImageLayer(
                    label: '현재 · ${widget.currentYear}',
                    background: const LinearGradient(
                      colors: [Color(0xFFDDD6C8), Color(0xFFEFE9DC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.photo_camera_outlined,
                  ),
                  // 과거(앞 레이어) — seam 위치만큼만 클립.
                  ClipRect(
                    clipper: _LeftClipper(seamX),
                    child: _ImageLayer(
                      label: '과거 · ${widget.pastYear}',
                      background: const LinearGradient(
                        colors: [Color(0xFF8C7A5F), Color(0xFFB9A47F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      icon: Icons.history,
                    ),
                  ),
                  // 이음새(seam) 모티프: 골드 세로선 + 드래그 핸들.
                  Positioned(
                    left: seamX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.gold),
                  ),
                  Positioned(
                    left: seamX - 16,
                    top: widget.height / 2 - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.drag_indicator, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({required this.label, required this.background, required this.icon});

  final String label;
  final Gradient background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: background),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.footnote.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.seamX);

  final double seamX;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, seamX, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) => oldClipper.seamX != seamX;
}
