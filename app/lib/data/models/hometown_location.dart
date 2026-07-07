/// 사용자가 입력한 고향 주소/학교/아파트에 매핑되는 장소.
class HometownLocation {
  const HometownLocation({
    required this.id,
    required this.name,
    required this.region,
    required this.description,
    required this.pastYear,
    required this.currentYear,
    this.isColdSpot = false,
  });

  final String id;
  final String name;
  final String region;
  final String description;
  final int pastYear;
  final int currentYear;

  /// 인구감소지역(콜드스팟) 여부 — true면 관광 데이터가 희박할 수 있어
  /// 화면 전반에서 빈 상태 폴백을 고려해야 한다.
  final bool isColdSpot;
}
