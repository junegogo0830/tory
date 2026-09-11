import re

_SUFFIX_RE = re.compile(r"(시|군|구)$")
_TAG_RE = re.compile(r"<[^>]+>")
_CITY_RE = re.compile(r"\S*[시군]\b")


def extract_city(address: str) -> str | None:
    """"경기 수원시 영통구 이의동 1304" 같은 주소에서 시/군 단위 지명만 뽑는다
    ("수원시"). 시/군 대표 사진을 찾을 때 쓴다 — 못 찾으면 None."""
    match = _CITY_RE.search(address)
    return match.group() if match else None


def strip_html(text: str) -> str:
    """네이버 뉴스/TourAPI overview 등 외부 API가 주는 리치 텍스트에서
    태그를 지우고 HTML 엔티티를 사람이 읽을 문자로 되돌린다."""
    text = _TAG_RE.sub("", text)
    return (
        text.replace("&quot;", '"')
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&#39;", "'")
    )


def simplify_place_name(region: str, name: str) -> str:
    """"전라남도 순천시" + "저전동 골목" 같은 큐레이션 풀네임을 외부 검색 API에
    넣기 좋은 짧은 질의로 줄인다.

    네이버 뉴스 검색과 카카오 로컬 주소 검색 둘 다, "골목"/"상가"/"인근" 같은
    서술어까지 붙은 풀네임을 그대로 넣으면 매칭이 0건이 되는 걸 확인했다 —
    시/군 단위 지명 + 동네 이름의 핵심 단어만 남긴다.
    """
    city = region.split()[-1] if region.split() else region
    city = _SUFFIX_RE.sub("", city)
    core_name = name.split()[0] if name.split() else name
    return f"{city} {core_name}".strip()
