import '../models/hometown_location.dart';

/// 장소 조회 레포지토리. 현재는 목 데이터를 반환하며,
/// 추후 [ApiClient]를 주입받아 TourAPI 연동 백엔드를 호출하도록 교체한다.
class LocationRepository {
  static final List<HometownLocation> _mockLocations = [
    const HometownLocation(
      id: 'suncheon-jeonpo',
      name: '전포동 골목',
      region: '전라남도 순천시',
      description: '초등학교 등굣길이었던 골목길',
      pastYear: 1998,
      currentYear: 2026,
    ),
    const HometownLocation(
      id: 'gunsan-jungang',
      name: '중앙로 상가',
      region: '전라북도 군산시',
      description: '방과 후 친구들과 떡볶이를 먹던 거리',
      pastYear: 2003,
      currentYear: 2026,
    ),
    const HometownLocation(
      id: 'yeongwol-jang',
      name: '영월장 인근',
      region: '강원도 영월군',
      description: '할머니 손 잡고 다니던 오일장 골목',
      pastYear: 1995,
      currentYear: 2026,
      isColdSpot: true,
    ),
  ];

  Future<List<HometownLocation>> getRecentLocations() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _mockLocations;
  }

  Future<HometownLocation?> getLocationById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final location in _mockLocations) {
      if (location.id == id) return location;
    }
    return null;
  }

  /// 자유 입력(주소/학교/아파트 텍스트)에 대응하는 장소를 찾는다.
  /// 실제 구현에서는 백엔드의 지오코딩 + TourAPI 매칭 결과를 사용한다.
  Future<HometownLocation> resolveFromQuery(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mockLocations.first;
  }
}
