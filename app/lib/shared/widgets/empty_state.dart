import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// TourAPI 데이터가 희박한 콜드스팟 등에서 사용하는 공용 빈 상태 폴백.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.goldTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.goldDeep, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTypography.subhead,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
