/// 아직 서버에 올리지 않은, 로컬에서 고른 사진 한 장(바이트 형태).
///
/// 바이트로 들고 다니는 이유: `MultipartFile.fromFile`은 `dart:io`를 쓰기 때문에
/// 웹 빌드에선 동작하지 않는다 — `XFile.readAsBytes()`로 읽은 바이트를 넘기면
/// 웹/네이티브 어디서나 동일하게 동작한다.
class PendingPhoto {
  const PendingPhoto({required this.bytes, required this.filename, this.mimeType = 'image/jpeg'});

  final List<int> bytes;
  final String filename;
  final String mimeType;
}
