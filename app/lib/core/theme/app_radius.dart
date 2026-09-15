/// 옛길 디자인 시스템 코너 라운딩.
///
/// 상용 앱(카카오T·NOL 등) 기준으로 카드 12~16, 작은 태그 6 정도가 자연스럽다 —
/// 이전 18~22는 화면 전체가 "다 둥글둥글한" 템플릿 느낌을 줘서 한 단계 줄였다.
abstract final class AppRadius {
  static const double card = 12;
  static const double button = 12;
  static const double field = 12;
  static const double pill = 18;
  static const double tile = 12;
  // 카테고리/연도처럼 작은 라벨 태그. 필(pill) 대신 살짝만 깎는다.
  static const double tag = 6;
}
