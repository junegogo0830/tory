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
import 'community_screen.dart' show shortRegionLabel;

/// "친구찾기" — 카카오톡 친구 API는 별도 심사가 필요한 제한 API라 쓰지 않고,
/// 같은 "내 동네"로 설정한 다른 사용자들을 그 동네 게시글 수 순으로 보여준다.
class NeighborsScreen extends ConsumerWidget {
  const NeighborsScreen({super.key, required this.region});

  final String region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final isLoggedIn = authAsync.value ?? false;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('${shortRegionLabel(region)} 이웃')),
      body: SafeArea(
        child: !isLoggedIn
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: '로그인하면 동네 이웃을 볼 수 있어요',
                    message: '프로필 탭에서 카카오로 로그인해주세요.',
                  ),
                ),
              )
            : Consumer(
                builder: (context, ref, _) {
                  final neighborsAsync = ref.watch(neighborsProvider(region));
                  return neighborsAsync.when(
                    data: (neighbors) {
                      if (neighbors.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: EmptyState(
                              icon: Icons.person_search_outlined,
                              title: '아직 이 동네에 이웃이 없어요',
                              message: '같은 동네를 설정한 다른 사용자가 생기면 여기에 보여요.',
                            ),
                          ),
                        );
                      }
                      // 글 수 순 목록이라는 게 바로 보이도록 순위 숫자를 앞에 두고,
                      // 카드 반복 대신 흰 컨테이너 하나에 줄로 나열한다.
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Text(
                              '이 동네 글 많이 쓴 순',
                              style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                            ),
                          ),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < neighbors.length; i++) ...[
                                  _NeighborRow(rank: i + 1, neighbor: neighbors[i], region: region),
                                  if (i != neighbors.length - 1)
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
                      child: Text('이웃을 불러오지 못했어요', style: AppTypography.subhead),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NeighborRow extends StatelessWidget {
  const _NeighborRow({required this.rank, required this.neighbor, required this.region});

  final int rank;
  final Neighbor neighbor;
  final String region;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/neighbors/${Uri.encodeComponent(region)}/${neighbor.userId}'
        '?nickname=${Uri.encodeComponent(neighbor.nickname)}',
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
              backgroundImage: neighbor.profileImageUrl != null
                  ? NetworkImage(neighbor.profileImageUrl!)
                  : null,
              child: neighbor.profileImageUrl == null
                  ? const Icon(Icons.person, size: 22, color: AppColors.accentDeep)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    neighbor.nickname,
                    style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    neighbor.postCount > 0 ? '이 동네 글 ${neighbor.postCount}개' : '아직 쓴 글이 없어요',
                    style: AppTypography.footnote,
                  ),
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

/// 순위 숫자 — 상위 3명은 브랜드색으로, 그 밑은 옅게. 상용 앱 랭킹 목록처럼
/// 숫자가 먼저 읽히게 굵고 살짝 기울인다.
class RankNumber extends StatelessWidget {
  const RankNumber({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    return SizedBox(
      width: 24,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: top ? 20 : 16,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          height: 1,
          color: top ? AppColors.accent : AppColors.inkTertiary,
        ),
      ),
    );
  }
}
