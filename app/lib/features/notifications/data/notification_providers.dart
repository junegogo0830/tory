import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/repository_providers.dart';

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.list();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});

final notificationSettingsProvider = FutureProvider<NotificationSettings>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getSettings();
});
