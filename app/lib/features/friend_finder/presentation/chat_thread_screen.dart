import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/direct_message.dart';
import '../../../data/repositories/repository_providers.dart';

/// 연결(수락)된 두 사용자 사이의 채팅방. 실시간 소켓이 아니라 폴링 방식 —
/// 화면 진입 시 조회하고, 메시지를 보낼 때마다 다시 조회해서 새로고침한다.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.connectionId});

  final int connectionId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  List<DirectMessage>? _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await ref.read(connectionRepositoryProvider).messages(widget.connectionId);
      if (mounted) setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _messages = []);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    _bodyController.clear();
    try {
      await ref.read(connectionRepositoryProvider).sendMessage(widget.connectionId, body);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('전송하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('메시지')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : messages.isEmpty
                      ? Center(
                          child: Text('첫 메시지를 보내보세요', style: AppTypography.subhead.copyWith(color: AppColors.inkTertiary)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.hairline))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bodyController,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: '메시지 보내기', counterText: ''),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send, color: AppColors.accentDeep),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final DirectMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.body,
          style: AppTypography.body.copyWith(color: message.isMine ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}
