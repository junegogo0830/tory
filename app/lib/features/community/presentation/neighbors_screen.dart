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
                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: neighbors.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _NeighborRow(neighbor: neighbors[index], region: region),
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
  const _NeighborRow({required this.neighbor, required this.region});

  final Neighbor neighbor;
  final String region;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(
        '/neighbors/${Uri.encodeComponent(region)}/${neighbor.userId}'
        '?nickname=${Uri.encodeComponent(neighbor.nickname)}',
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.accentTint,
            backgroundImage: neighbor.profileImageUrl != null
                ? NetworkImage(neighbor.profileImageUrl!)
                : null,
            child: neighbor.profileImageUrl == null
                ? const Icon(Icons.person, color: AppColors.accentDeep)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(neighbor.nickname, style: AppTypography.headline),
                const SizedBox(height: 2),
                Text(
                  neighbor.postCount > 0 ? '이 동네 글 ${neighbor.postCount}개' : '아직 쓴 글이 없어요',
                  style: AppTypography.footnote,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
