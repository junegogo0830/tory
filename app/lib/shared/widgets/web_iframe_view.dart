// 인라인으로 iframe을 띄우는 `WebIframeView` 위젯.
// 실제 구현은 웹에서만 가능해서(dart:ui_web, package:web), 웹이 아닌 빌드
// (Android/iOS)에서도 컴파일되도록 conditional import로 플랫폼별 파일을 나눴다.
export 'web_iframe_view_stub.dart' if (dart.library.js_interop) 'web_iframe_view_web.dart';
