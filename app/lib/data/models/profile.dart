/// 프로필 화면에 노출되는 저장한 골목 요약.
class SavedLocationSummary {
  const SavedLocationSummary({
    required this.id,
    required this.name,
    required this.region,
  });

  final String id;
  final String name;
  final String region;

  factory SavedLocationSummary.fromJson(Map<String, dynamic> json) {
    return SavedLocationSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
    );
  }
}

/// 로그인 없이 단일 디바이스 기준으로 제공되는 프로필.
class Profile {
  const Profile({
    required this.displayName,
    required this.tagline,
    this.profileImageUrl,
    required this.savedLocationsCount,
    required this.completedCoursesCount,
    required this.memoryPhotoCount,
    required this.savedLocations,
    this.homeRegion,
  });

  final String displayName;
  final String tagline;
  // 카카오 로그인 사진이거나 프로필 수정에서 직접 올린 사진. 절대 URL(카카오 CDN)일
  // 수도, 우리 서버 상대경로("/uploads/profile/...")일 수도 있어 AppNetworkImage의
  // resolveImageUrl이 알아서 처리하게 그대로 둔다(여기서 apiBaseUrl을 붙이지 않는다).
  final String? profileImageUrl;
  final int savedLocationsCount;
  final int completedCoursesCount;
  final int memoryPhotoCount;
  final List<SavedLocationSummary> savedLocations;
  // 커뮤니티 탭에서 설정한 "내 동네". 아직 설정 전이면 null.
  final String? homeRegion;

  /// 백엔드 `ProfileResponse` 스키마(snake_case)를 파싱한다.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['display_name'] as String,
      tagline: json['tagline'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      savedLocationsCount: json['saved_locations_count'] as int,
      completedCoursesCount: json['completed_courses_count'] as int,
      memoryPhotoCount: json['memory_photo_count'] as int,
      savedLocations: (json['saved_locations'] as List)
          .map((json) => SavedLocationSummary.fromJson(json as Map<String, dynamic>))
          .toList(),
      homeRegion: json['home_region'] as String?,
    );
  }
}
