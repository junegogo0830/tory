import '../models/tour_course.dart';

/// 감성분석 결합 추천 코스 레포지토리 (목 데이터).
/// 실제 구현에서는 backend `/api/course` 응답(ONNX 감성 서빙 결과 결합)으로 대체한다.
class CourseRepository {
  static final Map<String, List<TourCourse>> _mockCourses = {
    'suncheon-jeonpo': [
      const TourCourse(
        id: 'c1',
        title: '순천만 노을 산책 코스',
        description: '어릴 적 놀던 골목에서 순천만 습지까지 이어지는 감성 코스',
        sentimentScore: 0.86,
        stops: ['전포동 골목', '순천만국가정원', '순천만습지 노을전망대'],
        durationLabel: '약 3시간',
      ),
      const TourCourse(
        id: 'c2',
        title: '옛 시장 미식 코스',
        description: '추억의 분식집부터 최근 인기 맛집까지',
        sentimentScore: 0.74,
        stops: ['전포동 골목시장', '아랫장 국밥거리'],
        durationLabel: '약 2시간',
      ),
    ],
    'gunsan-jungang': [
      const TourCourse(
        id: 'c3',
        title: '근대문화유산 골목 코스',
        description: '중앙로 상가에서 이어지는 군산 근대역사 탐방',
        sentimentScore: 0.81,
        stops: ['중앙로 상가', '군산근대역사박물관', '동국사'],
        durationLabel: '약 2.5시간',
      ),
    ],
    // 콜드스팟 예시: 추천 코스 데이터가 비어있어 빈 상태 폴백을 확인할 수 있다.
    'yeongwol-jang': [],
  };

  Future<List<TourCourse>> getCoursesByLocation(String locationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _mockCourses[locationId] ?? const [];
  }

  /// 코스 탭(전체 목록)에서 사용하는 통합 리스트.
  Future<List<TourCourse>> getAllCourses() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _mockCourses.values.expand((courses) => courses).toList();
  }

  Future<TourCourse?> getCourseById(String courseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final courses in _mockCourses.values) {
      for (final course in courses) {
        if (course.id == courseId) return course;
      }
    }
    return null;
  }
}
