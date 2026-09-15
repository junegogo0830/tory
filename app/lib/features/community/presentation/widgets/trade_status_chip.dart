import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// 주민 게시판(중고거래 스타일) 글의 거래 상태 배지 — 게시판 목록·글 목록·
/// 상세 화면에서 다 같은 모양으로 쓴다.
class TradeStatusChip extends StatelessWidget {
  const TradeStatusChip({super.key, required this.status});

  final String status;

  static Color colorFor(String status) => switch (status) {
        '거래완료' => AppColors.inkTertiary,
        '예약중' => const Color(0xFFCC8B2E),
        _ => const Color(0xFF3F9142),
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.tag)),
      child: Text(
        status,
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10.5),
      ),
    );
  }
}

const tradeStatuses = ['판매중', '예약중', '거래완료'];

/// 글쓴이가 상세 화면에서 거래 상태를 바로 바꿀 수 있는 드롭다운 — 눌린
/// 모양은 [TradeStatusChip]과 똑같이 보이게 만들었다.
class TradeStatusDropdown extends StatelessWidget {
  const TradeStatusDropdown({super.key, required this.status, required this.onChanged});

  final String status;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = TradeStatusChip.colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.tag)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: color, size: 18),
          style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10.5),
          dropdownColor: AppColors.surface,
          items: [
            for (final s in tradeStatuses) DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: onChanged == null ? null : (value) => value == null ? null : onChanged!(value),
        ),
      ),
    );
  }
}

/// "30000" → "30,000"
String formatPrice(int price) {
  final text = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
