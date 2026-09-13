import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/notification_providers.dart';

/// 프로필 탭 "알림 설정" — 알림 켜고 끄는 토글 + 실제 알림함을 한 화면에 담는다.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SettingsCard(),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => context.push('/blocked-users'),
              icon: const Icon(Icons.block_outlined, size: 18),
              label: const Text('차단 관리'),
            ),
            const SizedBox(height: 8),
            Text('알림함', style: AppTypography.headline),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final notificationsAsync = ref.watch(notificationsProvider);
                return notificationsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.notifications_none,
                        title: '아직 알림이 없어요',
                        message: '내 글에 댓글이나 좋아요가 달리면 여기 보여요.',
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _NotificationRow(item: items[i]),
                        ],
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (_, _) => Text('불러오지 못했어요', style: AppTypography.subhead),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return AppCard(
      child: settingsAsync.when(
        data: (settings) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('알림 설정', style: AppTypography.headline),
            const SizedBox(height: 4),
            Text('꺼두면 그 종류의 알림 자체가 안 쌓여요.', style: AppTypography.footnote),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('댓글 알림'),
              value: settings.notifyOnComment,
              activeThumbColor: AppColors.accent,
              onChanged: (value) async {
                await ref
                    .read(notificationRepositoryProvider)
                    .updateSettings(notifyOnComment: value, notifyOnLike: settings.notifyOnLike);
                ref.invalidate(notificationSettingsProvider);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('좋아요 알림'),
              value: settings.notifyOnLike,
              activeThumbColor: AppColors.accent,
              onChanged: (value) async {
                await ref
                    .read(notificationRepositoryProvider)
                    .updateSettings(notifyOnComment: settings.notifyOnComment, notifyOnLike: value);
                ref.invalidate(notificationSettingsProvider);
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, _) => Text('설정을 불러오지 못했어요', style: AppTypography.subhead),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        if (!item.isRead) {
          await ref.read(notificationRepositoryProvider).markRead(item.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);
        }
        if (context.mounted) context.push('/post/${item.postId}');
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.isRead ? AppColors.paper : AppColors.accentTint,
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            child: Icon(
              item.type == 'comment' ? Icons.mode_comment_outlined : Icons.favorite_border,
              size: 18,
              color: AppColors.accentDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.message,
              style: AppTypography.subhead.copyWith(
                fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
