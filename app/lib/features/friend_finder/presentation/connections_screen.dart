import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/connection_request.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';

/// 연결된(수락된) 친구 목록. 탭하면 채팅방으로 이동한다.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  List<ConnectionRequestModel>? _connections;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final connections = await ref.read(connectionRepositoryProvider).connections();
      if (mounted) setState(() => _connections = connections);
    } catch (_) {
      if (mounted) setState(() => _connections = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = _connections;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('친구 목록'),
        actions: [
          IconButton(
            onPressed: () => context.push('/friends/requests'),
            icon: const Icon(Icons.mail_outline),
            tooltip: '연결 요청',
          ),
        ],
      ),
      body: SafeArea(
        child: connections == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : connections.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(
                        icon: Icons.people_outline,
                        title: '아직 연결된 친구가 없어요',
                        message: '친구 찾기에서 추억이 겹치는 사람에게 연결 요청을 보내보세요.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: connections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final connection = connections[index];
                      return InkWell(
                        onTap: () => context.push('/friends/chat/${connection.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.accentTint,
                                backgroundImage: connection.otherProfileImageUrl != null
                                    ? NetworkImage(connection.otherProfileImageUrl!)
                                    : null,
                                child: connection.otherProfileImageUrl == null
                                    ? const Icon(Icons.person, size: 20, color: AppColors.accentDeep)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  connection.otherNickname,
                                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
