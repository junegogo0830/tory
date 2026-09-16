"""Fixed banner destinations, verified against Kakao Local on 2026-09-16.

Basic details must survive cache eviction and upstream search outages. These are
place identities and coordinates, not live opening hours or generated photographs.
"""
import datetime

from ..models.location import LocationResponse


HERO_LOCATIONS = {
    "gangneung-namsan": ("남산공원", "강원특별자치도 강릉시 노암동 643", 37.74688508069992, 128.8933588063867),
    "gogunsan": ("고군산군도", "전북특별자치도 군산시 옥도면 선유도리 482", 35.8136043084018, 126.425147420764),
    "gwanmunsa": ("대한불교천태종 관문사", "서울 서초구 바우뫼로7길 111", 37.47365673515821, 127.0221724802618),
    "gwaneumsa-busan": ("관음사", "부산 사하구 제석로79번길 33", 35.1091566324436, 128.975980967585),
    "seokcheonsa": ("석천사", "여수시 충민사길 52-21", 34.7581702535766, 127.734442315262),
    "yonghwasa": ("용화사", "충남 논산시 상월면 상도리", 36.3296651729221, 127.186940240289),
}


def get_hero_location(location_id: str) -> LocationResponse | None:
    place = HERO_LOCATIONS.get(location_id.removeprefix("hero-"))
    if place is None:
        return None
    name, address, latitude, longitude = place
    year = datetime.date.today().year
    return LocationResponse(
        id=location_id, name=name, region=address,
        description="옛길에서 소개하는 장소예요. 위치를 지도와 로드뷰로 확인해보세요.",
        past_year=year, current_year=year, source="kakao",
        latitude=latitude, longitude=longitude,
    )
