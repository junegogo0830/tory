import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../data/repositories/repository_providers.dart';
import '../data/community_providers.dart';

/// 차단 관리 — 차단한 사용자 목록을 보고 해제할 수 있다.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('차단 관리')),
      body: SafeArea(
        child: blockedAsync.when(
          data: (blocked) {
            if (blocked.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.block_outlined,
                    title: '차단한 사용자가 없어요',
                    message: '게시글이나 댓글에서 차단할 수 있어요.',
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: blocked.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = blocked[index];
                return AppCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(user.nickname, style: AppTypography.headline)),
                      TextButton(
                        onPressed: () async {
                          await ref.read(communityRepositoryProvider).unblockUser(user.userId);
                          ref.invalidate(blockedUsersProvider);
                        },
                        child: const Text('차단 해제'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}
