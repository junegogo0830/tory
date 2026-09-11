import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/inline_roadview.dart';

/// 실시간 카카오 로드뷰 풀페이지. 웹뷰 셋업 자체는 [InlineRoadview](compare_screen의
/// 비교 패널에도 인라인으로 심는 것과 동일한 위젯)에 있고, 여긴 AppBar를 씌운다.
class RoadviewScreen extends StatelessWidget {
  const RoadviewScreen({super.key, required this.locationId, required this.locationName});

  final String locationId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Text('$locationName · 실시간 로드뷰'),
      ),
      body: InlineRoadview(locationId: locationId),
    );
  }
}
