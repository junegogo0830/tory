/// "코스 커스텀"에서 검색해 담은 장소 하나. [source]는 어느 검색(TourAPI/카카오맵)에서
/// 왔는지만 표시하고, 나머지는 검색 결과를 그대로 스냅샷한다.
class CustomCoursePlace {
  const CustomCoursePlace({
    required this.source,
    required this.placeId,
    required this.name,
    this.address = '',
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.photoAttributionName,
    this.photoAttributionUrl,
    this.note,
  });

  final String source; // 'tour' | 'kakao'
  final String placeId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  // imageUrl이 구글 플레이스 사진일 때만(서버가 저장 시점에 자동 보강한 경우) 채워진다.
  final String? photoAttributionName;
  final String? photoAttributionUrl;
  // 이 장소에 대한 작성자의 짧은 코멘트.
  final String? note;

  bool get hasCoordinates => latitude != null && longitude != null;

  // note/imageUrl은 생략하면(호출부가 안 넘기면) 원래 값을 지운다 — 지금 유일한
  // 호출부(코스 작성 화면)가 늘 명시적으로 넘겨서 문제가 없었지만, imageUrl을
  // 새로 추가하면서 두 값 다 "안 넘기면 유지"가 아니라 "안 넘기면 null"인 걸
  // 헷갈리지 않게 이 주석으로 남겨둔다. 사진만 바꿀 땐 note도 같이 넘겨야 한다.
  CustomCoursePlace copyWith({String? note, String? imageUrl}) => CustomCoursePlace(
        source: source,
        placeId: placeId,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
        // 새 imageUrl(직접 업로드 등)로 바꾸는 거라 예전 구글 출처 표기는 같이 지운다.
        note: note,
      );

  factory CustomCoursePlace.fromJson(Map<String, dynamic> json) {
    return CustomCoursePlace(
      source: json['source'] as String,
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      photoAttributionName: json['photo_attribution_name'] as String?,
      photoAttributionUrl: json['photo_attribution_url'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'place_id': placeId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'photo_attribution_name': photoAttributionName,
        'photo_attribution_url': photoAttributionUrl,
        'note': note,
      };
}

/// 코스 커스텀 목록 화면용 요약.
class CustomCourseSummary {
  const CustomCourseSummary({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.title,
    required this.category,
    required this.placeCount,
    this.thumbnailUrl,
    this.score = 0,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorNickname;
  final String title;
  final String category;
  final int placeCount;
  final String? thumbnailUrl;
  final int score;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final DateTime createdAt;

  factory CustomCourseSummary.fromJson(Map<String, dynamic> json) {
    return CustomCourseSummary(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorNickname: json['author_nickname'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      placeCount: json['place_count'] as int,
      thumbnailUrl: json['thumbnail_url'] as String?,
      score: json['score'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      dislikeCount: json['dislike_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 코스 커스텀 상세.
class CustomCourse {
  const CustomCourse({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.title,
    required this.category,
    this.description,
    required this.places,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.isMine = false,
    this.isPublic = true,
    this.myVote = 0,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorNickname;
  final String title;
  final String category;
  final String? description;
  final List<CustomCoursePlace> places;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final bool isMine;
  final bool isPublic;
  final int myVote; // -1, 0, 1

  final DateTime createdAt;

  factory CustomCourse.fromJson(Map<String, dynamic> json) {
    return CustomCourse(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorNickname: json['author_nickname'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      places: (json['places'] as List)
          .map((p) => CustomCoursePlace.fromJson(p as Map<String, dynamic>))
          .toList(),
      likeCount: json['like_count'] as int? ?? 0,
      dislikeCount: json['dislike_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isMine: json['is_mine'] as bool? ?? false,
      isPublic: json['is_public'] as bool? ?? true,
      myVote: json['my_vote'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 코스 커스텀 화면에서 "카카오맵 기반"으로 장소를 검색할 때 쓰는 결과.
class KakaoPlaceSearchResult {
  const KakaoPlaceSearchResult({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  factory KakaoPlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return KakaoPlaceSearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class CustomCourseComment {
  const CustomCourseComment({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.body,
    this.isMine = false,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorNickname;
  final String body;
  final bool isMine;
  final DateTime createdAt;

  factory CustomCourseComment.fromJson(Map<String, dynamic> json) {
    return CustomCourseComment(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorNickname: json['author_nickname'] as String,
      body: json['body'] as String,
      isMine: json['is_mine'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 코스 커스텀에서 고를 수 있는 카테고리 — 기존 추천 코스와 같은 체계
/// (backend `CUSTOM_COURSE_CATEGORIES` / `CourseCategory`와 동일하게 유지).
const List<String> customCourseCategories = ['산책', '역사', '미식', '문화', '자연', '가족'];
