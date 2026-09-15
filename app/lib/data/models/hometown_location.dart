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
    this.imageSourceName,
    this.savedByCount,
    this.latitude,
    this.longitude,
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

  /// [imageUrl]이 이 장소 자신의 사진이 아니라 주변/대표 관광지 사진으로 대체된
  /// 경우에만 채워지는 그 관광지 이름. 있으면 화면에 "OO 사진이 없어 가까운
  /// XX 사진을 보여드려요" 같은 안내를 보여줘야 한다.
  final String? imageSourceName;

  /// "다른 사람들이 둘러본 골목"(둘러보기 탭)에서만 채워지는, 이 장소를 찜한 사용자 수.
  final int? savedByCount;

  /// 위치 기반 코스 추천/코스 커스텀 장소 추가에 쓰는 좌표. 없을 수 있다.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// 백엔드 `LocationResponse`(또는 이를 확장한 `PopularLocationResponse`) 스키마
  /// (snake_case)를 파싱한다.
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
      imageSourceName: json['image_source_name'] as String?,
      savedByCount: json['saved_by_count'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
