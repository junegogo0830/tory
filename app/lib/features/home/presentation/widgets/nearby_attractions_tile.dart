import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/card_fade_art.dart';

/// 홈 화면에서 커뮤니티 가입 카드와 같은 크기로 보여주는 "내 주변 관광지" 입구.
/// 탭하면 위치를 받아 앱 내 지도(`/nearby-map`)로 들어간다.
class NearbyAttractionsTile extends StatelessWidget {
  const NearbyAttractionsTile({super.key});

  Future<void> _open(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => _open(context),
      child: Stack(
        children: [
          const CardFadeArt(imageAsset: 'assets/logo/nearby_attractions.png'),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pastelSky,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.travel_explore_outlined, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 주변 관광지', style: AppTypography.headline),
                    const SizedBox(height: 2),
                    Text('지도에서 가까운 명소를 둘러보세요', style: AppTypography.footnote),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
