import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/connection_request.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';

/// 받은/보낸 연결 요청 인박스. 받은 요청은 수락/거절할 수 있다.
class ConnectionRequestsScreen extends ConsumerStatefulWidget {
  const ConnectionRequestsScreen({super.key});

  @override
  ConsumerState<ConnectionRequestsScreen> createState() => _ConnectionRequestsScreenState();
}

class _ConnectionRequestsScreenState extends ConsumerState<ConnectionRequestsScreen> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  List<ConnectionRequestModel>? _received;
  List<ConnectionRequestModel>? _sent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(connectionRepositoryProvider);
    try {
      final received = await repo.requests(direction: 'received', status: 'pending');
      final sent = await repo.requests(direction: 'sent');
      if (mounted) setState(() { _received = received; _sent = sent; });
    } catch (_) {
      if (mounted) setState(() { _received = []; _sent = []; });
    }
  }

  Future<void> _respond(ConnectionRequestModel request, bool accept) async {
    setState(() => _busy = true);
    try {
      await ref.read(connectionRepositoryProvider).respond(request.id, accept);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? '연결을 수락했어요' : '요청을 거절했어요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('처리하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('연결 요청'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentDeep,
          unselectedLabelColor: AppColors.inkTertiary,
          indicatorColor: AppColors.accent,
          tabs: const [Tab(text: '받은 요청'), Tab(text: '보낸 요청')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _RequestList(
              requests: _received,
              emptyMessage: '받은 연결 요청이 없어요',
              trailingBuilder: (request) => _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => _respond(request, false), child: const Text('거절')),
                        ElevatedButton(onPressed: () => _respond(request, true), child: const Text('수락')),
                      ],
                    ),
            ),
            _RequestList(requests: _sent, emptyMessage: '보낸 연결 요청이 없어요'),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.emptyMessage, this.trailingBuilder});

  final List<ConnectionRequestModel>? requests;
  final String emptyMessage;
  final Widget Function(ConnectionRequestModel)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final list = requests;
    if (list == null) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(icon: Icons.mail_outline, title: emptyMessage, message: ''),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final request = list[index];
        return InkWell(
          onTap: () => context.push('/memory-profile/${request.otherUserId}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentTint,
                  backgroundImage: request.otherProfileImageUrl != null
                      ? NetworkImage(request.otherProfileImageUrl!)
                      : null,
                  child: request.otherProfileImageUrl == null
                      ? const Icon(Icons.person, size: 20, color: AppColors.accentDeep)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.otherNickname, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
                      if (request.message != null && request.message!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(request.message!, style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (trailingBuilder != null) trailingBuilder!(request),
              ],
            ),
          ),
        );
      },
    );
  }
}
