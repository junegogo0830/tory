import 'package:flutter/material.dart';

/// 웹이 아닌 플랫폼(Android/iOS)용 스텁 — 이 위젯은 kIsWeb이 true일 때만
/// 쓰이므로 네이티브 빌드에서 실제로 렌더링될 일은 없다(컴파일만 되면 됨).
class WebIframeView extends StatelessWidget {
  const WebIframeView({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
