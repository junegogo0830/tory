/// 카카오맵 기반 맛집.
///
/// 카카오 로컬 API 응답 자체엔 평점·리뷰 수·사진이 없다 — [imageUrl]은 같은
/// 이름으로 TourAPI에 등록된 곳이 있을 때만 채워지는 보강 값이고(없으면 null),
/// 실제 평점·리뷰는 [placeUrl]로 카카오맵 원본 페이지를 열어서 보여준다.
class KakaoRestaurant {
  const KakaoRestaurant({
    required this.id,
    required this.name,
    required this.category,
    this.cuisine = '기타',
    required this.address,
    this.distanceM,
    this.imageUrl,
    this.phone,
    this.placeUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String category;
  // 한식/중식/일식/양식/디저트/기타 — 지역 캐러셀 카테고리 토글용 큰 분류.
  final String cuisine;
  final String address;
  final int? distanceM;
  final String? imageUrl;
  final String? phone;
  final String? placeUrl;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory KakaoRestaurant.fromJson(Map<String, dynamic> json) {
    return KakaoRestaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      cuisine: json['cuisine'] as String? ?? '기타',
      address: json['address'] as String,
      distanceM: json['distance_m'] as int?,
      imageUrl: json['image_url'] as String?,
      phone: json['phone'] as String?,
      placeUrl: json['place_url'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
