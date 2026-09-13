import '../constants/app_constants.dart';

/// TourAPI 이미지 CDN(tong.visitkorea.or.kr 등)은 CORS 헤더를 보내지 않아서,
/// Flutter Web의 CanvasKit 렌더러가 캔버스에 이미지를 디코드하지 못하고 조용히
/// 로드가 실패한다(카메라 아이콘 폴백 또는 CachedNetworkImage 기본 깨짐 아이콘으로
/// 나타남 — curl/서버 쪽 호출은 CORS가 적용 안 돼 정상으로 보여서 재현이 안 됐었다).
/// 우리 백엔드가 대신 받아 CORS 허용 응답으로 재서빙하는 프록시를 거치게 한다.
///
/// 이미 우리 백엔드가 서빙하는 이미지(커뮤니티 업로드 사진 등, apiBaseUrl로 시작)는
/// 같은 CORSMiddleware를 타서 이미 정상 동작하므로 그대로 둔다.
String resolveImageUrl(String url) {
  url = url.trim();
  if (url.startsWith('/')) return '${AppConstants.apiBaseUrl}$url';
  if (url.startsWith(AppConstants.apiBaseUrl)) return url;
  if (!url.startsWith('http://') && !url.startsWith('https://')) return url;
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host != 'visitkorea.or.kr' && !host.endsWith('.visitkorea.or.kr')) {
    return url;
  }
  return '${AppConstants.apiBaseUrl}/api/image/proxy?url=${Uri.encodeComponent(url)}';
}
