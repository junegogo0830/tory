/// 홈 화면 카드 캐러셀에 쓰는 TourAPI 기반 인기 장소 카드.
class HighlightCard {
  const HighlightCard({
    required this.id,
    required this.title,
    required this.region,
    required this.imageUrl,
    required this.category,
  });

  final String id;
  final String title;
  final String region;
  final String imageUrl;
  final String category;

  factory HighlightCard.fromJson(Map<String, dynamic> json) {
    return HighlightCard(
      id: json['id'] as String,
      title: json['title'] as String,
      region: json['region'] as String,
      imageUrl: json['image_url'] as String,
      category: json['category'] as String,
    );
  }
}
