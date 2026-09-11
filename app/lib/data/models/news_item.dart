/// 그 시절 지역 뉴스 아카이브 항목.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.year,
    required this.title,
    required this.source,
    required this.summary,
  });

  final String id;
  final int year;
  final String title;
  final String source;
  final String summary;

  /// 백엔드 `NewsItemResponse` 스키마를 파싱한다.
  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String,
      year: json['year'] as int,
      title: json['title'] as String,
      source: json['source'] as String,
      summary: json['summary'] as String,
    );
  }
}
