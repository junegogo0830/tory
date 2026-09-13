/// 이 동네의 최근 소식(뉴스) 항목.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.year,
    required this.title,
    required this.source,
    required this.summary,
    this.publishedAt,
    this.url,
  });

  final String id;
  final int year;
  final String title;
  final String source;
  final String summary;

  /// 정확한 발행일. 연도만 아는 큐레이션 데이터는 null — 화면은 이때 [year]로 폴백한다.
  final DateTime? publishedAt;

  /// 원문 기사 링크. 있으면 탭해서 열 수 있다.
  final String? url;

  /// 백엔드 `NewsItemResponse` 스키마를 파싱한다.
  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final publishedAtRaw = json['published_at'] as String?;
    return NewsItem(
      id: json['id'] as String,
      year: json['year'] as int,
      title: json['title'] as String,
      source: json['source'] as String,
      summary: json['summary'] as String,
      publishedAt: publishedAtRaw != null ? DateTime.tryParse(publishedAtRaw) : null,
      url: json['url'] as String?,
    );
  }
}
