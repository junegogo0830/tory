/// 저장(북마크)한 코스 하나 — AI 생성 코스/커스텀 코스를 한 모양으로 보여준다.
class SavedCourse {
  const SavedCourse({
    required this.courseType,
    required this.courseId,
    required this.title,
    this.category,
    this.thumbnailUrl,
    required this.placeCount,
    required this.savedAt,
  });

  // 'generated' | 'custom'
  final String courseType;
  final String courseId;
  final String title;
  final String? category;
  final String? thumbnailUrl;
  final int placeCount;
  final DateTime savedAt;

  bool get isCustom => courseType == 'custom';

  // AppNetworkImage가 resolveImageUrl로 상대경로("/uploads/...")/절대경로(TourAPI 등)를
  // 알아서 처리하므로 여기서는 원본 문자열을 그대로 들고 있는다.
  factory SavedCourse.fromJson(Map<String, dynamic> json) {
    return SavedCourse(
      courseType: json['course_type'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      placeCount: json['place_count'] as int,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }
}
