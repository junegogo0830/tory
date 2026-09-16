/// 홈 화면 히어로 배너 항목 — 사진 자체에 이미 제목/설명 문구가 들어있는
/// 완성된 배너 이미지라, 여기서는 어느 실제 장소로 연결할지(검색어)와 어떤
/// 파일을 쓸지만 관리한다. `assets/highlights/README.md`에 각 사진이 어느
/// 실제 장소인지 정리돼 있다.
///
/// 카카오는 REST로 "id 상세 재조회"가 안 돼서(tourapi.py의 get_location_by_id
/// 참고), 고정된 kakao-{id} 값을 여기 박아두면 그 id가 실제로 검색된 적이 없어
/// 캐시가 비어있는 채로 영영 404가 난다 — 그래서 id 대신 실제 장소명을 들고
/// 있다가, "자세히 보기"를 누르는 시점에 그 이름으로 새로 검색해 방금 막
/// 캐시된 진짜 id를 받아 이동한다.
class HeroHighlight {
  const HeroHighlight({required this.placeQuery, required this.imageAsset});

  final String placeQuery;
  final String imageAsset;
}

const List<HeroHighlight> heroHighlights = [
  HeroHighlight(placeQuery: '강릉 남산공원', imageAsset: 'assets/highlights/gangneung_namsan.jpg'),
  HeroHighlight(placeQuery: '고군산군도', imageAsset: 'assets/highlights/gogunsan.jpg'),
  HeroHighlight(placeQuery: '관문사 서초구', imageAsset: 'assets/highlights/gwanmunsa.jpg'),
  HeroHighlight(placeQuery: '관음사 사하구', imageAsset: 'assets/highlights/gwaneumsa_busan.jpg'),
  HeroHighlight(placeQuery: '석천사 여수시', imageAsset: 'assets/highlights/seokcheonsa.jpg'),
  HeroHighlight(placeQuery: '용화사 논산시', imageAsset: 'assets/highlights/yonghwasa.jpg'),
];
