"""여러 코스 생성 서비스(CourseGeneratorService/CoursePlanner)가 공유하는,
TourAPI/카카오 로컬 후보에서 관광 목적이 아닌 일반 행정·생활 시설을 걸러내는
상호명 블랙리스트. TourAPI "관광지(contenttypeid=12)" 버킷 안에도 노인회
사무실·사우나처럼 관광과 무관한 등록 항목이 섞여 있는 걸 실측으로 확인했다
(cat1=A02 하위에 있으나 관심사와 무관) — 카테고리 필터만으로는 못 걸러서
상호명 패턴으로 한 번 더 걸러낸다.
"""

_NON_TOURISM_NAME_MARKERS = (
    "주민센터", "치안센터", "파출소", "지구대", "우체국", "농협", "수협", "새마을금고", "신협",
    "부동산", "공인중개사", "노인회", "부녀회", "자치회", "통장협의회", "지회", "협회", "조합",
    "사우나", "찜질방", "목욕탕", "미용실", "네일", "세탁소",
    "정형외과", "피부과", "치과", "한의원", "약국", "동물병원",
    "학원", "어린이집", "유치원", "독서실", "고시원",
    "장례식장", "상조", "주차장", "충전소", "주유소", "정비소", "타이어",
)


def looks_non_touristy(name: str) -> bool:
    return any(marker in name for marker in _NON_TOURISM_NAME_MARKERS)


# 최초 코스 생성(관광지 전용) 후보에서 식당/카페류를 걸러내는 데 쓴다 — 식사는
# 코스가 만들어진 뒤 별도 "식사 추가" 플로우(meal_planner.py)에서만 들어간다.
# TourAPI contenttypeid="39"(음식점)가 가장 확실한 신호라 우선 확인하고,
# 카테고리 라벨(국문 관광정보 API 매칭 결과)과 구글 Nearby Search의 원본
# types(관광지 후보에 섞여 들어올 수 있다)도 함께 본다.
_FOOD_CATEGORY_LABELS = {"음식점", "카페"}
_FOOD_TOUR_CONTENT_TYPE_IDS = {"39"}
_FOOD_GOOGLE_TYPES = {"restaurant", "cafe", "bakery", "meal_takeaway", "meal_delivery", "bar"}


def is_food_candidate(candidate: dict) -> bool:
    if candidate.get("content_type_id") in _FOOD_TOUR_CONTENT_TYPE_IDS:
        return True
    if candidate.get("category") in _FOOD_CATEGORY_LABELS:
        return True
    types = candidate.get("types") or ()
    return any(t in _FOOD_GOOGLE_TYPES for t in types)
