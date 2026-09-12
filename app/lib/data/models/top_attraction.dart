/// 홈 화면 검색창 밑 "인기 관광지 TOP 10" 티커에 쓰는 순위 항목.
class TopAttraction {
  const TopAttraction({
    required this.rank,
    required this.id,
    required this.name,
    required this.region,
    this.imageUrl,
  });

  final int rank;
  final String id;
  final String name;
  final String region;
  final String? imageUrl;

  factory TopAttraction.fromJson(Map<String, dynamic> json) {
    return TopAttraction(
      rank: json['rank'] as int,
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}
