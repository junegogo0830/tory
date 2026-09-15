import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// 관광정보 게시판 "지도로 보기" — 장소가 첨부된 글들을 카카오맵 마커로 보여주는
/// 백엔드 서빙 페이지(community_map.py)를 웹뷰로 띄운다. 마커의 "게시글 보기"
/// 링크는 커스텀 스킴(yetgil-post://{id})이라 실제로 이동하지 않고, 여기서
/// NavigationDelegate가 가로채 앱 안에서 게시글 상세로 이동시킨다.
class CommunityMapScreen extends StatelessWidget {
  const CommunityMapScreen({super.key, required this.region, required this.boardId});

  final String region;
  final String boardId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('지도로 보기')),
      body: kIsWeb ? _WebFallback(region: region, boardId: boardId) : _NativeMap(region: region, boardId: boardId),
    );
  }
}

String _mapUrl(String region, String boardId) =>
    '${AppConstants.apiBaseUrl}/community-map/${Uri.encodeComponent(region)}/${Uri.encodeComponent(boardId)}';

/// webview_flutter는 웹 구현체가 없다(roadview와 같은 제약) — 웹에서는 새 탭으로 연다.
class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.region, required this.boardId});

  final String region;
  final String boardId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => launchUrl(Uri.parse(_mapUrl(region, boardId)), webOnlyWindowName: '_blank'),
        icon: const Icon(Icons.open_in_new),
        label: const Text('새 탭에서 지도 보기'),
      ),
    );
  }
}

class _NativeMap extends StatefulWidget {
  const _NativeMap({required this.region, required this.boardId});

  final String region;
  final String boardId;

  @override
  State<_NativeMap> createState() => _NativeMapState();
}

class _NativeMapState extends State<_NativeMap> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.paper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            const scheme = 'yetgil-post://';
            if (request.url.startsWith(scheme)) {
              final postId = request.url.substring(scheme.length);
              context.push('/post/$postId');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_mapUrl(widget.region, widget.boardId)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          ColoredBox(
            color: AppColors.paper,
            child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
      ],
    );
  }
}
