import 'package:flutter/material.dart';

/// 신고 사유를 입력받는 공용 다이얼로그. 취소하면 null, 입력하면 그 사유 문자열을 돌려준다.
Future<String?> showReportDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('신고하기'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        maxLines: 3,
        decoration: const InputDecoration(hintText: '신고 사유를 알려주세요'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () {
            final reason = controller.text.trim();
            if (reason.isNotEmpty) Navigator.pop(context, reason);
          },
          child: const Text('신고'),
        ),
      ],
    ),
  );
}

/// 사용자 차단 확인 다이얼로그. 확인하면 true를 돌려준다.
Future<bool> showBlockConfirmDialog(BuildContext context, String nickname) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$nickname님을 차단할까요?'),
      content: const Text('차단하면 이 사용자의 글과 댓글이 더 이상 보이지 않아요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('차단')),
      ],
    ),
  );
  return confirmed ?? false;
}
