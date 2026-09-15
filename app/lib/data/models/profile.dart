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
    required this.userId,
    required this.displayName,
    required this.tagline,
    this.profileImageUrl,
    required this.registeredCourseCount,
    required this.savedCourseCount,
    required this.postCount,
    required this.savedLocations,
    this.homeRegion,
    this.ageGroup,
    this.gender,
    this.fullName,
    this.phoneNumber,
    this.onboardingCompleted = false,
    this.hasPassword = false,
  });

  final int userId;
  final String displayName;
  final String tagline;
  // 카카오 로그인 사진이거나 프로필 수정에서 직접 올린 사진. 절대 URL(카카오 CDN)일
  // 수도, 우리 서버 상대경로("/uploads/profile/...")일 수도 있어 AppNetworkImage의
  // resolveImageUrl이 알아서 처리하게 그대로 둔다(여기서 apiBaseUrl을 붙이지 않는다).
  final String? profileImageUrl;
  // 통계 3칸 — 등록한 코스 커스텀 / 저장(북마크)한 코스 / 게시판 무관 내가 쓴 글.
  final int registeredCourseCount;
  final int savedCourseCount;
  final int postCount;
  final List<SavedLocationSummary> savedLocations;
  // 커뮤니티 탭에서 설정한 "내 동네". 아직 설정 전이면 null.
  final String? homeRegion;
  final String? ageGroup;
  final String? gender;
  final String? fullName;
  final String? phoneNumber;
  // 첫 로그인 온보딩(연령대/거주지/살았던 곳)을 완료했거나 건너뛰었으면 true.
  // false면 AppShell이 온보딩 화면을 띄운다.
  final bool onboardingCompleted;
  // 자체 회원가입(아이디+비밀번호) 계정이면 true. 카카오 로그인 계정은 false —
  // 비밀번호 변경 메뉴는 이 값이 true일 때만 보여준다.
  final bool hasPassword;

  /// 백엔드 `ProfileResponse` 스키마(snake_case)를 파싱한다.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as int,
      displayName: json['display_name'] as String,
      tagline: json['tagline'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      registeredCourseCount: json['registered_course_count'] as int,
      savedCourseCount: json['saved_course_count'] as int,
      postCount: json['post_count'] as int,
      savedLocations: (json['saved_locations'] as List)
          .map((json) => SavedLocationSummary.fromJson(json as Map<String, dynamic>))
          .toList(),
      homeRegion: json['home_region'] as String?,
      ageGroup: json['age_group'] as String?,
      gender: json['gender'] as String?,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? false,
    );
  }
}
