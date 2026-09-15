/// 모교 검색 결과 한 건 — 카카오 장소 검색을 그대로 감싼 것이라 사진/좌표는 없다.
class SchoolSearchResult {
  const SchoolSearchResult({required this.id, required this.name, required this.address});

  final String id;
  final String name;
  final String address;

  factory SchoolSearchResult.fromJson(Map<String, dynamic> json) {
    return SchoolSearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
    );
  }
}
