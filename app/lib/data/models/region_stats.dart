/// 새 지역 커뮤니티 가입 확인 화면에 보여주는 통계.
class RegionStats {
  const RegionStats({required this.region, required this.memberCount, required this.postCount});

  final String region;
  final int memberCount;
  final int postCount;

  factory RegionStats.fromJson(Map<String, dynamic> json) {
    return RegionStats(
      region: json['region'] as String,
      memberCount: json['member_count'] as int,
      postCount: json['post_count'] as int,
    );
  }
}
