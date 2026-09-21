import 'package:flutter/material.dart';
import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import '../../core/theme/app_colors.dart';

/// 유저 프로필 사진 공용 위젯 — 커뮤니티 게시글/댓글, 프로필 등에서 통일된
/// 아바타를 보여준다. 사진이 없으면 항상 같은 모습의 기본 아이콘으로 폴백해서
/// "빈 화면"처럼 보이지 않게 한다.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.imageUrl, this.size = 40});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _fallback()
            : AppNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => _fallback(),
                errorWidget: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: AppColors.iconChipBg,
      child: Icon(Icons.person, color: AppColors.iconChipFg, size: size * 0.55),
    );
  }
}
