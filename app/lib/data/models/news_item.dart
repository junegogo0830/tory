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
}
