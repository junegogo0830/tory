import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// compare_screen의 "현재" 비교 패널에 바로 심는 실시간 로드뷰.
///
/// webview_flutter는 웹 구현체가 없으므로(roadview_screen.dart와 동일한 제약),
/// 웹에서는 인라인 임베드 대신 새 탭에서 여는 버튼으로 폴백한다.
class InlineRoadview extends StatelessWidget {
  const InlineRoadview({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _WebFallback(locationId: locationId);
    return _NativeInlineRoadview(locationId: locationId);
  }
}

class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.ink),
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            final uri = Uri.parse('${AppConstants.apiBaseUrl}/roadview/$locationId');
            launchUrl(uri, webOnlyWindowName: '_blank');
          },
          icon: const Icon(Icons.open_in_new, color: Colors.white),
          label: const Text('새 탭에서 로드뷰 보기', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _NativeInlineRoadview extends StatefulWidget {
  const _NativeInlineRoadview({required this.locationId});

  final String locationId;

  @override
  State<_NativeInlineRoadview> createState() => _NativeInlineRoadviewState();
}

class _NativeInlineRoadviewState extends State<_NativeInlineRoadview> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.ink)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => setState(() => _isLoading = false)),
      )
      ..loadRequest(Uri.parse('${AppConstants.apiBaseUrl}/roadview/${widget.locationId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const ColoredBox(
            color: AppColors.ink,
            child: Center(child: CircularProgressIndicator(color: AppColors.accentTint)),
          ),
      ],
    );
  }
}
