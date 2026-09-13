import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext context) onTap;
}

Future<void> _openNearbyMap(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
    ),
  );

  void closeLoading() {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void showMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      closeLoading();
      showMessage('위치 권한이 필요해요');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      closeLoading();
      showMessage('기기의 위치 서비스를 켜주세요');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
    );
    closeLoading();
    if (context.mounted) {
      context.push('/nearby-map?lat=${position.latitude}&lng=${position.longitude}');
    }
  } catch (_) {
    closeLoading();
    showMessage('위치를 가져오지 못했어요. 다시 시도해주세요');
  }
}

final List<_QuickAction> _quickActions = [
  _QuickAction(
    icon: Icons.route_outlined,
    label: '추천 코스',
    color: AppColors.pastelMint,
    onTap: (context) => context.go('/course'),
  ),
  _QuickAction(
    icon: Icons.explore_outlined,
    label: '둘러보기',
    color: AppColors.pastelSky,
    onTap: (context) => context.push('/explore'),
  ),
  _QuickAction(
    icon: Icons.near_me_outlined,
    label: '내 주변',
    color: AppColors.pastelPeach,
    onTap: _openNearbyMap,
  ),
  _QuickAction(
    icon: Icons.groups_outlined,
    label: '커뮤니티',
    color: AppColors.pastelLavender,
    onTap: (context) => context.go('/community'),
  ),
  _QuickAction(
    icon: Icons.restaurant_outlined,
    label: '맛집 추천',
    color: AppColors.pastelButter,
    onTap: (context) => context.push('/kakao-restaurants'),
  ),
  _QuickAction(
    icon: Icons.person_outline,
    label: '프로필',
    color: AppColors.accentTint,
    onTap: (context) => context.go('/profile'),
  ),
];

/// "관광지 추천"과 "관광공사 Pick" 사이의 홈 화면 바로가기 그리드 — 야놀자/NOL류
/// 앱의 아이콘 그리드를 참고했다. 3열×2행(GridView)으로 두면 칸 하나가 너무
/// 넓어져 아이콘이 커 보인다는 피드백으로, 한 줄에 6개를 다 넣는 Row로
/// 바꿨다 — 참고 화면처럼 칸 폭 자체를 좁혀야 아이콘도 비율에 맞게 작아진다.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [for (final action in _quickActions) Expanded(child: _QuickActionTile(action: action))],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => action.onTap(context),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: action.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.tile,
            ),
            child: Icon(action.icon, color: AppColors.ink, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: AppTypography.caption.copyWith(color: AppColors.ink, fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
