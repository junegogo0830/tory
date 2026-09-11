/// 장소 주변의 실제 등록된 곳(주로 음식점). TourAPI 좌표 기반 검색 결과.
class NearbyPlace {
  const NearbyPlace({
    required this.name,
    required this.category,
    required this.distanceM,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String category;
  final int? distanceM;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      name: json['name'] as String,
      category: json['category'] as String,
      distanceM: (json['distance_m'] as num?)?.toInt(),
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
