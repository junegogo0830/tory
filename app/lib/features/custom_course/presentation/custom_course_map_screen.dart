import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// 코스 상세의 "지도 보기" — 담긴 장소들을 번호 마커로 보여주는 백엔드 서빙
/// 페이지(custom_course.py의 render_map)를 웹뷰로 띄운다. community_map_screen.dart와
/// 같은 패턴(웹은 webview_flutter 구현체가 없어 새 탭으로 폴백).
class CustomCourseMapScreen extends StatelessWidget {
  const CustomCourseMapScreen({super.key, required this.courseId});

  final int courseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('지도 보기')),
      body: kIsWeb ? _WebFallback(courseId: courseId) : _NativeMap(courseId: courseId),
    );
  }
}

String _mapUrl(int courseId) => '${AppConstants.apiBaseUrl}/api/custom-courses/$courseId/map';

class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.courseId});

  final int courseId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => launchUrl(Uri.parse(_mapUrl(courseId)), webOnlyWindowName: '_blank'),
        icon: const Icon(Icons.open_in_new),
        label: const Text('새 탭에서 지도 보기'),
      ),
    );
  }
}

class _NativeMap extends StatefulWidget {
  const _NativeMap({required this.courseId});

  final int courseId;

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
        NavigationDelegate(onPageFinished: (_) => setState(() => _isLoading = false)),
      )
      ..loadRequest(Uri.parse(_mapUrl(widget.courseId)));
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
