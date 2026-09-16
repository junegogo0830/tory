/// 홈 화면 검색창 밑 "인기 관광지 TOP 10" 티커에 쓰는 순위 항목.
class TopAttraction {
  const TopAttraction({
    required this.rank,
    required this.id,
    required this.name,
    required this.region,
    this.imageUrl,
    this.photoAttributionName,
    this.photoAttributionUrl,
  });

  final int rank;
  final String id;
  final String name;
  final String region;
  final String? imageUrl;
  // imageUrl이 구글 플레이스 사진일 때만 채워진다 — 구글 이용약관상 사진을
  // 보여줄 땐 기여자 출처 표기를 같이 보여줘야 한다.
  final String? photoAttributionName;
  final String? photoAttributionUrl;

  factory TopAttraction.fromJson(Map<String, dynamic> json) {
    return TopAttraction(
      rank: json['rank'] as int,
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      imageUrl: json['image_url'] as String?,
      photoAttributionName: json['photo_attribution_name'] as String?,
      photoAttributionUrl: json['photo_attribution_url'] as String?,
    );
  }
}
