/// 홈 화면 히어로 배너 항목 — 사진 자체에 이미 제목/설명 문구가 들어있는
/// 완성된 배너 이미지라, 여기서는 어느 실제 장소로 연결할지(고정 ID)와 어떤
/// 파일을 쓸지만 관리한다. `assets/highlights/README.md`에 각 사진이 어느
/// 실제 장소인지 정리돼 있다.
///
/// hero-*는 서버가 검증된 장소 정보로 직접 조회한다. 검색 캐시에 의존하지 않는다.
class HeroHighlight {
  const HeroHighlight({required this.locationId, required this.imageAsset});

  final String locationId;
  final String imageAsset;
}

const List<HeroHighlight> heroHighlights = [
  HeroHighlight(locationId: 'hero-gangneung-namsan', imageAsset: 'assets/highlights/gangneung_namsan.jpg'),
  HeroHighlight(locationId: 'hero-gogunsan', imageAsset: 'assets/highlights/gogunsan.jpg'),
  HeroHighlight(locationId: 'hero-gwanmunsa', imageAsset: 'assets/highlights/gwanmunsa.jpg'),
  HeroHighlight(locationId: 'hero-gwaneumsa-busan', imageAsset: 'assets/highlights/gwaneumsa_busan.jpg'),
  HeroHighlight(locationId: 'hero-seokcheonsa', imageAsset: 'assets/highlights/seokcheonsa.jpg'),
  HeroHighlight(locationId: 'hero-yonghwasa', imageAsset: 'assets/highlights/yonghwasa.jpg'),
];
