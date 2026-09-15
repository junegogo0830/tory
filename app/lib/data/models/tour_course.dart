/// 코스의 한 정류지. 실제 등록된 장소와 매칭됐을 때만 좌표가 채워진다 —
/// 있으면 카카오맵 길찾기 딥링크를 만들 수 있고, 없으면 이름만 보여준다.
class CourseStop {
  const CourseStop({
    required this.name,
    this.latitude,
    this.longitude,
    this.category = '',
    this.address = '',
    this.stayMinutes = 30,
    this.imageUrl,
  });

  final String name;
  final double? latitude;
  final double? longitude;
  final String category;
  final String address;
  final int stayMinutes;
  // TourAPI 검색으로 보강된 정류지 사진 — 없으면 화면에서 폴백 아이콘을 쓴다.
  final String? imageUrl;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory CourseStop.fromJson(Map<String, dynamic> json) {
    return CourseStop(
      name: json['name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String? ?? '',
      address: json['address'] as String? ?? '',
      stayMinutes: json['stay_minutes'] as int? ?? 30,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// 감성분석 점수 기반 추천 관광 코스.
class TourCourse {
  const TourCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.sentimentScore,
    required this.stops,
    required this.durationLabel,
    required this.category,
    this.imageUrl,
    this.locationId = '',
    this.weatherLabel = '',
    this.distanceKm,
    this.notes = const [],
  });

  final String id;
  final String title;
  final String description;

  /// 0.0 ~ 1.0 사이 감성 점수 (높을수록 긍정적 후기 비중이 큼).
  final double sentimentScore;
  final List<CourseStop> stops;
  final String durationLabel;

  /// 코스 성격 분류 (예: 산책/역사/미식).
  final String category;

  /// TourAPI에 등록된 정류지와 매칭됐을 때만 채워지는 실제 사진. 없으면 null —
  /// 화면에서는 보유 정적 이미지로 폴백한다.
  final String? imageUrl;

  /// 이 코스가 속한 장소 id. "주변 맛집" 등 장소 기반 부가 정보를 조회할 때 쓴다.
  final String locationId;
  final String weatherLabel;
  final double? distanceKm;
  final List<String> notes;

  /// 백엔드 `CourseResponse` 스키마(snake_case)를 파싱한다.
  factory TourCourse.fromJson(Map<String, dynamic> json) {
    return TourCourse(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      sentimentScore: (json['sentiment_score'] as num).toDouble(),
      stops: (json['stops'] as List)
          .map((s) => CourseStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      durationLabel: json['duration_label'] as String,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String?,
      locationId: json['location_id'] as String? ?? '',
      weatherLabel: json['weather_label'] as String? ?? '',
      distanceKm: (json['estimated_distance_km'] as num?)?.toDouble(),
      notes: (json['notes'] as List? ?? []).cast<String>(),
    );
  }
}
