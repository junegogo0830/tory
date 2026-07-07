/// 감성분석 점수 기반 추천 관광 코스.
class TourCourse {
  const TourCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.sentimentScore,
    required this.stops,
    required this.durationLabel,
  });

  final String id;
  final String title;
  final String description;

  /// 0.0 ~ 1.0 사이 감성 점수 (높을수록 긍정적 후기 비중이 큼).
  final double sentimentScore;
  final List<String> stops;
  final String durationLabel;
}
