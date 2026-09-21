import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/chatbot_message.dart';
import '../../../data/repositories/repository_providers.dart';

const String _kFaqIntroReply = '무엇이 궁금하신가, 편하게 물어보시게. 옛길 어디든 아는 대로 알려주겠네.';
const String _kCourseIntroReply = '어느 고장으로 마실 나가시려나? 지역이랑 누구와 함께인지 편하게 이야기해보시게.';
const String _kErrorReply = '지금은 답을 드리기 어렵네요. 잠시 후 다시 물어봐 주시게.';

const double _kMinChildSize = 0.4;
const double _kMaxChildSize = 1;

/// 챗봇을 화면 전환이 아니라, 아래에서 90%까지 슬라이드 올라오는 시트로 연다.
/// 위로 더 끌면 전체 화면까지 커지고, 아래로 끌어 다시 내리면 닫힌다.
///
/// DraggableScrollableSheet의 "스크롤 위젯이 경계에 닿으면 리사이즈로 넘긴다"는
/// 자동 메커니즘은 showModalBottomSheet의 기본 닫기 제스처(enableDrag)와
/// 서로 드래그를 가로채려 경쟁하고, 어느 한쪽을 꺼도 나머지 한쪽이 온전히
/// 못 넘겨받는 경우가 있어 방향에 따라 되다 안되다 했다. 그래서 자동 메커니즘에
/// 기대지 않고, 상단 손잡이 하나를 [DraggableScrollableController]로 직접
/// 조작하는 명시적인 드래그로 바꿨다 — 항상 똑같이 동작한다.
Future<void> showChatbotSheet(BuildContext context) {
  final sheetController = DraggableScrollableController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
    builder: (context) => DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.9,
      minChildSize: _kMinChildSize,
      maxChildSize: _kMaxChildSize,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
          child: _ChatbotSheetBody(scrollController: scrollController, sheetController: sheetController),
        );
      },
    ),
  );
}

class _ChatbotSheetBody extends ConsumerStatefulWidget {
  const _ChatbotSheetBody({required this.scrollController, required this.sheetController});

  final ScrollController scrollController;
  final DraggableScrollableController sheetController;

  @override
  ConsumerState<_ChatbotSheetBody> createState() => _ChatbotSheetBodyState();
}

class _ChatbotSheetBodyState extends ConsumerState<_ChatbotSheetBody> {
  final _messages = <ChatbotMessage>[];
  final _controller = TextEditingController();
  String? _mode;
  bool _sending = false;
  bool _lastReplyFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectMode(String mode, String introReply) {
    setState(() {
      _mode = mode;
      _messages.add(ChatbotMessage(role: 'model', text: introReply));
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final mode = _mode;
    if (text.isEmpty || mode == null || _sending) return;

    setState(() {
      _messages.add(ChatbotMessage(role: 'user', text: text));
      _controller.clear();
      _sending = true;
      _lastReplyFailed = false;
    });
    _scrollToBottom();

    try {
      final reply = await ref.read(chatbotRepositoryProvider).sendMessage(
            mode: mode,
            history: _messages,
            message: text,
          );
      if (!mounted) return;
      setState(() => _messages.add(ChatbotMessage(role: 'model', text: reply)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const ChatbotMessage(role: 'model', text: _kErrorReply));
        _lastReplyFailed = true;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final next = (widget.sheetController.size - details.primaryDelta! / screenHeight)
        .clamp(_kMinChildSize, _kMaxChildSize);
    widget.sheetController.jumpTo(next);
  }

  void _onHandleDragEnd(DragEndDetails details) {
    // 놓았을 때 거의 최소 크기까지 내려와 있으면(끌어서 닫으려는 의도) 닫는다.
    if (widget.sheetController.size <= _kMinChildSize + 0.03) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onHandleDragUpdate,
          onVerticalDragEnd: _onHandleDragEnd,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('AI 챗봇', style: AppTypography.headline.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mode == null
              ? _IntroBody(scrollController: widget.scrollController, onSelectMode: _selectMode)
              : _buildChat(),
        ),
      ],
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) return const _TypingBubble();
              final message = _messages[index];
              final isLastModelTurn = !message.isUser && index == _messages.length - 1;
              final isFirstModelTurn = !message.isUser && index == 0;
              return _MessageBubble(
                message: message,
                avatarAsset: !message.isUser
                    ? (isLastModelTurn && _lastReplyFailed
                        ? 'assets/chat_bot/profile_sad.png'
                        : isFirstModelTurn
                            ? 'assets/chat_bot/profile_happy.png'
                            : 'assets/chat_bot/profile_qurious.png')
                    : null,
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '훈장님께 물어보세요',
                      filled: true,
                      fillColor: AppColors.fieldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.chatbotOrange,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : _send,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 처음 들어왔을 때 화면 — new_back.png 자체가 이미 "훈장님" 제목/설명 문구와
/// 아래쪽 여백까지 다 그려진 완성된 그림이다. 이미지는 위쪽부터 고정 높이로
/// 꽉 채워 보여주고(가로 전체 폭 기준으로 인물·문구가 전부 들어오는 높이라
/// 위에서부터 잘려도 여백만 잘린다), 버튼은 그 아래 별도 공간에 둬서 시트가
/// 90%든 전체화면이든 이미지 크기는 그대로, 버튼 영역 여유만 늘어난다.
///
/// scrollController를 여기서도 써야 한다 — DraggableScrollableSheet는 드래그를
/// "이 컨트롤러가 달린 스크롤 위젯" 위에서만 시트 크기 변경으로 받아들인다.
/// 채팅 화면은 ListView가 그 역할을 하는데, 인트로 화면엔 스크롤 위젯이 아예
/// 없어서 여기서 위로 끝까지 끌어도 전체화면으로 안 커졌다 — 그게 원인이었다.
class _IntroBody extends StatelessWidget {
  const _IntroBody({required this.scrollController, required this.onSelectMode});

  final ScrollController scrollController;
  final void Function(String mode, String introReply) onSelectMode;

  static const double _imageHeight = 460;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: [
          SizedBox(
            height: _imageHeight,
            width: double.infinity,
            child: Image.asset('assets/chat_bot/new_back.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onSelectMode('faq', _kFaqIntroReply),
                    style: OutlinedButton.styleFrom(backgroundColor: AppColors.surface),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('앱의 기능이 궁금하신가요?'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onSelectMode('course', _kCourseIntroReply),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.chatbotOrange, foregroundColor: Colors.white),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('옛길 앱 바탕으로 코스를 짜드릴까요?'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.avatarAsset});

  final ChatbotMessage message;
  final String? avatarAsset;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && avatarAsset != null) ...[
            ClipOval(child: Image.asset(avatarAsset!, width: 32, height: 32, fit: BoxFit.cover)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.chatbotOrange : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                message.text,
                style: AppTypography.body.copyWith(color: isUser ? Colors.white : AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipOval(child: Image.asset('assets/chat_bot/profile_qurious.png', width: 32, height: 32, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

/// AI가 답을 생성하는 동안 보여줄 표시 — 동그란 로딩 스피너 대신, 점 세 개가
/// 파도치듯 순서대로 올라갔다 내려오는 "..." 타이핑 표시.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++) _buildDot(i),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(int index) {
    final t = (_controller.value - index * 0.2) % 1.0;
    final lift = t < 0.5 ? Curves.easeOut.transform(t * 2) : Curves.easeIn.transform(1 - (t - 0.5) * 2);
    return Transform.translate(
      offset: Offset(0, -4 * lift),
      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
    );
  }
}
