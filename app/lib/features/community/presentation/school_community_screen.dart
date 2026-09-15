import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/community_board.dart';
import 'school_search_sheet.dart';

/// 모교 커뮤니티 게시판 목록 — 지역 커뮤니티와 똑같은 5개 게시판(자유/추억/주민/
/// 관광정보/타임캡슐)을 그대로 재사용한다. region 문자열이 "학교·OO고등학교"
/// 형태라는 것 빼고는 CommunityBoardScreen 등 나머지 인프라를 전부 그대로 쓴다.
class SchoolCommunityScreen extends StatelessWidget {
  const SchoolCommunityScreen({super.key, required this.schoolRegion});

  final String schoolRegion;

  @override
  Widget build(BuildContext context) {
    final schoolName = schoolNameFrom(schoolRegion);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(schoolName)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined, color: AppColors.accentDeep, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(schoolName, style: AppTypography.headline, overflow: TextOverflow.ellipsis),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/classmates/${Uri.encodeComponent(schoolRegion)}'),
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('동창찾기'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('게시판', style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    boxShadow: AppShadows.tile,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < communityBoards.length; i++) ...[
                        ListTile(
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: communityBoards[i].color, shape: BoxShape.circle),
                            child: Icon(communityBoards[i].icon, color: AppColors.ink, size: 14),
                          ),
                          title: Text(communityBoards[i].label, style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(communityBoards[i].description, style: AppTypography.caption),
                          trailing: Icon(Icons.chevron_right, color: AppColors.inkTertiary),
                          onTap: () => context.push(
                            '/community/${Uri.encodeComponent(schoolRegion)}/${communityBoards[i].id}',
                          ),
                        ),
                        if (i != communityBoards.length - 1)
                          Divider(height: 1, color: AppColors.hairline, indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
