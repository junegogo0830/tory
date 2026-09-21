import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'chatbot_screen.dart';

/// 홈 화면 오른쪽 아래에 항상 떠 있는 챗봇 진입 풍선. 위에 "궁금한 사항을
/// 훈장님께 물어봐요" 말풍선 툴팁이 함께 뜨고, 작은 x로 툴팁만 끌 수 있다 —
/// 풍선 자체는 계속 떠 있는다.
class ChatbotFab extends StatefulWidget {
  const ChatbotFab({super.key});

  @override
  State<ChatbotFab> createState() => _ChatbotFabState();
}

class _ChatbotFabState extends State<ChatbotFab> {
  bool _tooltipDismissed = false;

  void _openChat() {
    showChatbotSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_tooltipDismissed) ...[
            _TooltipBubble(onClose: () => setState(() => _tooltipDismissed = true)),
            const SizedBox(height: 8),
          ],
          Material(
            color: AppColors.chatbotOrange,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openChat,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('궁금한 사항을 훈장님께 물어봐요', style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
