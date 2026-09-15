/// 홈 화면 히어로 배너 항목 — 사진 자체에 이미 제목/설명 문구가 들어있는
/// 완성된 배너 이미지라, 여기서는 어느 실제 장소로 연결할지(location id)와
/// 어떤 파일을 쓸지만 관리한다. `assets/highlights/README.md`에 각 사진이
/// 어느 실제 장소인지 정리돼 있다.
class HeroHighlight {
  const HeroHighlight({required this.locationId, required this.imageAsset});

  final String locationId;
  final String imageAsset;
}

const List<HeroHighlight> heroHighlights = [
  HeroHighlight(locationId: 'kakao-17384830', imageAsset: 'assets/highlights/gangneung_namsan.jpg'),
  HeroHighlight(locationId: 'kakao-8682467', imageAsset: 'assets/highlights/gogunsan.jpg'),
  HeroHighlight(locationId: 'kakao-7828107', imageAsset: 'assets/highlights/gwanmunsa.jpg'),
  HeroHighlight(locationId: 'kakao-8753135', imageAsset: 'assets/highlights/gwaneumsa_busan.jpg'),
  HeroHighlight(locationId: 'kakao-8431958', imageAsset: 'assets/highlights/seokcheonsa.jpg'),
  HeroHighlight(locationId: 'kakao-8463828', imageAsset: 'assets/highlights/yonghwasa.jpg'),
];
