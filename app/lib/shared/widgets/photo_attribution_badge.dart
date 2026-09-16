import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 구글 플레이스 사진에 필요한 기여자 출처 표기. [name]이 없으면 아무것도
/// 안 그린다(TourAPI/관광사진 API 등 출처 표기가 필요 없는 사진).
///
/// 사진을 감싸는 [Stack] 안에서 `Positioned`로 쓰라고 만들었다 — 그 자체는
/// 위치를 안 잡으니 호출부가 Positioned(right:, bottom:, child: 이 위젯)로 둔다.
class PhotoAttributionBadge extends StatelessWidget {
  const PhotoAttributionBadge({super.key, this.name, this.url});

  final String? name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: url == null
          ? null
          : () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '사진: $name (Google)',
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
    );
  }
}
