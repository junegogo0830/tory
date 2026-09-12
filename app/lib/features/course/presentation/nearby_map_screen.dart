import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/web_iframe_view.dart';

/// "내 주변 관광지" 지도. 백엔드가 서빙하는 카카오맵 페이지(`/map/nearby`)를
/// 그대로 띄운다 — roadview_screen.dart와 같은 이유로 백엔드 도메인에서 서빙해야
/// 한다(카카오맵 JS SDK가 페이지 도메인을 검사함).
class NearbyMapScreen extends StatelessWidget {
  const NearbyMapScreen({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    final url = '${AppConstants.apiBaseUrl}/map/nearby?lat=$lat&lng=$lng';
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('내 주변 관광지')),
      // webview_flutter는 웹 구현체가 없어서, 웹에서는 새 탭 대신 iframe으로
      // 바로 이 화면 안에 지도를 심는다(WebIframeView, dart:ui_web 기반).
      body: kIsWeb ? WebIframeView(url: url) : _NativeMap(lat: lat, lng: lng),
    );
  }
}

class _NativeMap extends StatefulWidget {
  const _NativeMap({required this.lat, required this.lng});

  final double lat;
  final double lng;

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
      ..loadRequest(
        Uri.parse('${AppConstants.apiBaseUrl}/map/nearby?lat=${widget.lat}&lng=${widget.lng}'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const ColoredBox(
            color: AppColors.paper,
            child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
      ],
    );
  }
}
