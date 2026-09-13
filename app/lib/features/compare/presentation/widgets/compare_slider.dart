import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/inline_roadview.dart';
import '../../../../shared/widgets/photo_fallback.dart';

/// 과거↔현재 거리 비교의 시그니처 위젯.
/// "과거"는 사용자가 등록한 추억 사진이 있으면 그걸 쓰고, 없으면 아이콘 폴백만
/// 보여준다(가짜 사진으로 실제 그 시절 사진처럼 보이게 하지 않는다). "현재"는
/// [useLiveRoadview]면 실시간 로드뷰를, 아니면 TourAPI 실사진([currentImageUrl])이나
/// 같은 아이콘 폴백을 쓴다.
class CompareSlider extends StatefulWidget {
  const CompareSlider({
    super.key,
    required this.pastYear,
    required this.currentYear,
    this.currentImageUrl,
    this.height = 360,
    this.useLiveRoadview = false,
    this.locationId,
  }) : assert(
         !useLiveRoadview || locationId != null,
         'useLiveRoadview면 locationId가 필요해요',
       );

  final int pastYear;
  final int currentYear;
  final String? currentImageUrl;
  final double height;
  // 홈 화면 캐러셀처럼 3초마다 위치가 바뀌는 곳에서 매번 웹뷰+카카오 SDK를 새로
  // 띄우면 무겁다 — 사용자가 의도적으로 들어온 compare_screen에서만 켠다.
  final bool useLiveRoadview;
  final String? locationId;

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
                    networkImageUrl: widget.currentImageUrl,
                    liveContent: widget.useLiveRoadview
                        ? InlineRoadview(locationId: widget.locationId!)
                        : null,
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
                      sepia: true,
                    ),
                  ),
                  // 이음새(seam) 모티프: 브라운 세로선 + 드래그 핸들.
                  Positioned(
                    left: seamX - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.accent),
                  ),
                  Positioned(
                    left: seamX - 16,
                    top: widget.height / 2 - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: Colors.white,
                      ),
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
  const _ImageLayer({
    required this.label,
    required this.background,
    required this.icon,
    this.networkImageUrl,
    this.sepia = false,
    this.liveContent,
  });

  final String label;
  final Gradient background;
  final IconData icon;
  final String? networkImageUrl;
  final bool sepia;
  // 있으면(실시간 로드뷰 등) 사진 대신 이 위젯을 그대로 보여준다.
  final Widget? liveContent;

  @override
  Widget build(BuildContext context) {
    const fallback = PhotoFallback();
    final image =
        liveContent ??
        (networkImageUrl != null
            ? AppNetworkImage(
                imageUrl: networkImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: BoxDecoration(gradient: background)),
        if (sepia)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.55,
              0.43,
              0.12,
              0,
              0,
              0.45,
              0.38,
              0.10,
              0,
              0,
              0.30,
              0.25,
              0.08,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: image,
          )
        else
          image,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0x99000000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.55, 1],
            ),
          ),
        ),
        Positioned(
          left: 14,
          bottom: 14,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.footnote.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.seamX);

  final double seamX;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, seamX, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.seamX != seamX;
}
