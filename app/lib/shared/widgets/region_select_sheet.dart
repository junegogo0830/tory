import 'package:flutter/material.dart';
import '../../core/data/korea_regions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

/// 도 → 시군구 2단계 지역 선택 바텀시트. "경기도 수원시"처럼 "도 시군구" 문자열을
/// 반환한다(취소하면 null). 코스 탭 지역 선택과 커뮤니티 지역 전환이 함께 쓴다.
Future<String?> showRegionSelectSheet(BuildContext context, {String prompt = '어느 지역인가요?'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => _RegionSelectContent(prompt: prompt),
  );
}

class _RegionSelectContent extends StatefulWidget {
  const _RegionSelectContent({required this.prompt});

  final String prompt;

  @override
  State<_RegionSelectContent> createState() => _RegionSelectContentState();
}

class _RegionSelectContentState extends State<_RegionSelectContent> {
  String? _selectedProvince;

  @override
  Widget build(BuildContext context) {
    final province = _selectedProvince;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (province != null)
                    IconButton(
                      onPressed: () => setState(() => _selectedProvince = null),
                      icon: Icon(Icons.arrow_back, color: AppColors.ink),
                    ),
                  Expanded(
                    child: Text(
                      province ?? widget.prompt,
                      style: AppTypography.headline,
                      textAlign: province == null ? TextAlign.start : TextAlign.center,
                    ),
                  ),
                  if (province != null) const SizedBox(width: 48),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.hairline),
            Expanded(
              child: province == null
                  ? ListView(
                      children: [
                        for (final entry in koreaRegions.keys)
                          ListTile(
                            title: Text(entry, style: AppTypography.body),
                            trailing: Icon(Icons.chevron_right, color: AppColors.inkTertiary),
                            onTap: () => setState(() => _selectedProvince = entry),
                          ),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final city in koreaRegions[province]!)
                          ListTile(
                            title: Text(city, style: AppTypography.body),
                            onTap: () => Navigator.of(context).pop('$province $city'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
