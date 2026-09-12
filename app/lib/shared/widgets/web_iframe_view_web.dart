import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 카카오맵 페이지처럼 백엔드가 서빙하는 완결된 HTML을 Flutter Web 안에
/// iframe으로 그대로 심는다. webview_flutter는 웹 구현체가 없어서(공식
/// 미지원) 대신 dart:ui_web의 platformViewRegistry로 직접 iframe을 등록한다.
class WebIframeView extends StatefulWidget {
  const WebIframeView({super.key, required this.url});

  final String url;

  @override
  State<WebIframeView> createState() => _WebIframeViewState();
}

class _WebIframeViewState extends State<WebIframeView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // 위젯 인스턴스마다 고유한 viewType이어야 registerViewFactory 중복 등록
    // 오류가 안 난다.
    _viewType = 'web-iframe-view-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
