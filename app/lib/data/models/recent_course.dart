/// 홈 "이어보기" — 마지막으로 열어본 코스 하나.
class RecentCourse {
  const RecentCourse({
    required this.courseType,
    required this.courseId,
    required this.title,
    this.category,
    this.thumbnailUrl,
    required this.placeCount,
    required this.viewedAt,
  });

  // 'generated' | 'custom'
  final String courseType;
  final String courseId;
  final String title;
  final String? category;
  final String? thumbnailUrl;
  final int placeCount;
  final DateTime viewedAt;

  bool get isCustom => courseType == 'custom';

  factory RecentCourse.fromJson(Map<String, dynamic> json) {
    return RecentCourse(
      courseType: json['course_type'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      placeCount: json['place_count'] as int,
      viewedAt: DateTime.parse(json['viewed_at'] as String),
    );
  }
}
