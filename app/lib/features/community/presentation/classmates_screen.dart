import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/neighbor.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/data/auth_providers.dart';
import '../data/community_providers.dart';
import 'neighbors_screen.dart' show RankNumber;
import 'school_search_sheet.dart';

/// "동창찾기" — 모교 커뮤니티엔 neighbors()가 쓰는 home_region 같은 "내 모교"
/// 저장 개념이 없어서, 대신 이 학교 게시판에 실제로 글을 쓴 사람들을 글 수
/// 순으로 보여준다(active_authors, community_screen의 NeighborsScreen과 UI만 같다).
class ClassmatesScreen extends ConsumerWidget {
  const ClassmatesScreen({super.key, required this.schoolRegion});

  final String schoolRegion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isLoggedIn = authAsync.value ?? false;
    final schoolName = schoolNameFrom(schoolRegion);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('$schoolName 동창')),
      body: SafeArea(
        child: !isLoggedIn
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: '로그인하면 동창을 볼 수 있어요',
                    message: '프로필 탭에서 카카오로 로그인해주세요.',
                  ),
                ),
              )
            : Consumer(
                builder: (context, ref, _) {
                  final classmatesAsync = ref.watch(activeAuthorsProvider(schoolRegion));
                  return classmatesAsync.when(
                    data: (classmates) {
                      if (classmates.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: EmptyState(
                              icon: Icons.person_search_outlined,
                              title: '아직 이 학교에 글쓴 사람이 없어요',
                              message: '먼저 글을 남기면 다른 동창이 여기서 찾을 수 있어요.',
                            ),
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Text(
                              '이 학교 글 많이 쓴 순',
                              style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                            ),
                          ),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < classmates.length; i++) ...[
                                  _ClassmateRow(rank: i + 1, classmate: classmates[i], schoolRegion: schoolRegion),
                                  if (i != classmates.length - 1)
                                    Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.hairline),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    error: (_, _) => Center(
                      child: Text('동창 목록을 불러오지 못했어요', style: AppTypography.subhead),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ClassmateRow extends StatelessWidget {
  const _ClassmateRow({required this.rank, required this.classmate, required this.schoolRegion});

  final int rank;
  final Neighbor classmate;
  final String schoolRegion;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/neighbors/${Uri.encodeComponent(schoolRegion)}/${classmate.userId}'
        '?nickname=${Uri.encodeComponent(classmate.nickname)}',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            RankNumber(rank: rank),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accentTint,
              backgroundImage:
                  classmate.profileImageUrl != null ? NetworkImage(classmate.profileImageUrl!) : null,
              child: classmate.profileImageUrl == null
                  ? const Icon(Icons.person, size: 22, color: AppColors.accentDeep)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classmate.nickname,
                    style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('이 학교 글 ${classmate.postCount}개', style: AppTypography.footnote),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}
