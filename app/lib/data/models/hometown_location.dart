/// 사용자가 입력한 고향 주소/학교/아파트에 매핑되는 장소.
class HometownLocation {
  const HometownLocation({
    required this.id,
    required this.name,
    required this.region,
    required this.description,
    required this.pastYear,
    required this.currentYear,
    this.isColdSpot = false,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String region;
  final String description;
  final int pastYear;
  final int currentYear;

  /// 인구감소지역(콜드스팟) 여부 — true면 관광 데이터가 희박할 수 있어
  /// 화면 전반에서 빈 상태 폴백을 고려해야 한다.
  final bool isColdSpot;

  /// TourAPI에 등록된 관광지와 매칭됐을 때만 채워지는 실제 현재 사진. 없으면 null —
  /// 화면에서는 보유 정적 이미지로 폴백한다.
  final String? imageUrl;

  /// 백엔드 `LocationResponse` 스키마(snake_case)를 파싱한다.
  factory HometownLocation.fromJson(Map<String, dynamic> json) {
    return HometownLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      description: json['description'] as String,
      pastYear: json['past_year'] as int,
      currentYear: json['current_year'] as int,
      isColdSpot: json['is_cold_spot'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
    );
  }
}
