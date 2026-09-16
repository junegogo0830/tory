/// 카테고리별 맛집 발견 카드 한 장에 들어가는 맛집 하나.
class RestaurantItem {
  const RestaurantItem({
    required this.id,
    required this.name,
    required this.region,
    this.imageUrl,
    this.photoAttributionName,
    this.photoAttributionUrl,
  });

  final String id;
  final String name;
  final String region;
  final String? imageUrl;
  // imageUrl이 구글 플레이스 사진일 때만 채워진다 — 구글 이용약관상 사진을
  // 보여줄 땐 기여자 출처 표기를 같이 보여줘야 한다.
  final String? photoAttributionName;
  final String? photoAttributionUrl;

  factory RestaurantItem.fromJson(Map<String, dynamic> json) {
    return RestaurantItem(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      imageUrl: json['image_url'] as String?,
      photoAttributionName: json['photo_attribution_name'] as String?,
      photoAttributionUrl: json['photo_attribution_url'] as String?,
    );
  }
}

/// 홈 화면 "카테고리별 맛집" 캐러셀의 카드 한 장(예: 한식, 카페 등).
class RestaurantCategory {
  const RestaurantCategory({required this.category, required this.headline, required this.items});

  final String category;
  final String headline;
  final List<RestaurantItem> items;

  factory RestaurantCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantCategory(
      category: json['category'] as String,
      headline: json['headline'] as String,
      items: (json['items'] as List)
          .map((item) => RestaurantItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
