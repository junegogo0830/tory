import 'package:url_launcher/url_launcher.dart';

/// 카카오맵 길찾기 웹/앱 딥링크를 연다. 카카오맵 앱이 깔려있으면 앱으로,
/// 아니면 브라우저로 열린다 (공식 딥링크 스킴, 별도 키 불필요).
Future<void> openKakaoMapDirections({
  required String name,
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse(
    'https://map.kakao.com/link/to/${Uri.encodeComponent(name)},$latitude,$longitude',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}
