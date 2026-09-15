import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../notice/domain/notice.dart';
import '../../../notice/presentation/notice_detail_screen.dart';
import '../../../notice/presentation/notice_list_screen.dart';

const _maxVisible = 5;

/// 홈 화면 공지사항 카드 — 최근 공지 최대 5개의 제목만 한 줄씩 보여준다(다른
/// 카드보다 글씨를 작게). "더보기"로 전체 목록(앱 사용법, 게시판별 달라진
/// 기능 소개)으로 이동한다.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    final visible = notices.take(_maxVisible).toList();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: AppColors.accentDeep),
              const SizedBox(width: 5),
              Text(
                '공지사항',
                style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NoticeListScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('더보기', style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                      Icon(Icons.chevron_right, size: 14, color: AppColors.inkTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          for (final notice in visible)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        notice.title,
                        style: AppTypography.caption.copyWith(color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(notice.date, style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
