/// 카카오맵 기반 맛집 — 카카오 로컬 API 응답엔 사진 필드가 없어 imageUrl이 없다.
class KakaoRestaurant {
  const KakaoRestaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    this.distanceM,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final int? distanceM;

  factory KakaoRestaurant.fromJson(Map<String, dynamic> json) {
    return KakaoRestaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      address: json['address'] as String,
      distanceM: json['distance_m'] as int?,
    );
  }
}
