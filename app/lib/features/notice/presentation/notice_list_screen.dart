import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../domain/notice.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatelessWidget {
  const NoticeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('공지사항')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notice = notices[index];
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: notice.badgeColor, borderRadius: BorderRadius.circular(13)),
                        child: Icon(notice.icon, color: AppColors.accentDeep, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notice.title, style: AppTypography.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(notice.summary, style: AppTypography.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
