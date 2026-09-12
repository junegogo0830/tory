import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

class FeatureShortcutTile extends StatelessWidget {
  const FeatureShortcutTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeColor = AppColors.accentTint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  // 카테고리 픽토그램 배지 색 (docs/DESIGN_SYSTEM.md §1.3) — 기본값은 기존
  // accentTint라 지정 안 하면 이전과 동일하게 보인다.
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            boxShadow: AppShadows.tile,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.accentDeep, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppTypography.footnote.copyWith(color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
