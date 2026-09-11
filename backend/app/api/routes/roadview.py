import html

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from ...core.config import settings
from ...core.text import simplify_place_name
from ...services.kakao_local import KakaoLocalService
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/roadview", tags=["roadview"])
_tour_api_service = TourApiService()
_kakao_local_service = KakaoLocalService()


def _message_page(message: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  html,body{{margin:0;height:100%;background:#1F1A16;
    display:flex;align-items:center;justify-content:center;
    font-family:-apple-system,sans-serif;color:#F2EFEA;text-align:center;padding:24px;
    box-sizing:border-box;}}
</style></head>
<body><div>{html.escape(message)}</div></body></html>"""


def _roadview_page(*, lat: float, lng: float, label: str, js_key: str) -> str:
    safe_label = html.escape(label)
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html,body,#roadview{{margin:0;padding:0;width:100%;height:100%;background:#1F1A16;}}
  #fallback{{display:none;height:100%;align-items:center;justify-content:center;
    font-family:-apple-system,sans-serif;color:#F2EFEA;text-align:center;padding:24px;
    box-sizing:border-box;}}
  #label{{position:absolute;left:14px;top:14px;z-index:10;background:rgba(31,26,22,0.72);
    color:#fff;padding:8px 14px;border-radius:10px;font-family:-apple-system,sans-serif;
    font-size:14px;}}
</style></head>
<body>
  <div id="label">{safe_label}</div>
  <div id="roadview"></div>
  <div id="fallback">
    <div>이 지역은 아직 로드뷰가 제공되지 않거나<br>지도를 불러오지 못했어요</div>
  </div>
  <script
    src="https://dapi.kakao.com/v2/maps/sdk.js?appkey={js_key}"
    onerror="document.getElementById('roadview').style.display='none';document.getElementById('fallback').style.display='flex';"
  ></script>
  <script>
    try {{
      if (typeof kakao === 'undefined' || !kakao.maps) {{
        throw new Error('Kakao Maps SDK failed to load');
      }}
      var position = new kakao.maps.LatLng({lat}, {lng});
      var roadviewContainer = document.getElementById('roadview');
      var roadview = new kakao.maps.Roadview(roadviewContainer);
      var roadviewClient = new kakao.maps.RoadviewClient();
      roadviewClient.getNearestPanoId(position, 50, function(panoId) {{
        if (panoId === null) {{
          roadviewContainer.style.display = 'none';
          document.getElementById('fallback').style.display = 'flex';
        }} else {{
          roadview.setPanoId(panoId, position);
        }}
      }});
    }} catch (e) {{
      document.getElementById('roadview').style.display = 'none';
      document.getElementById('fallback').style.display = 'flex';
    }}
  </script>
</body></html>"""


@router.get("/{location_id}", response_class=HTMLResponse)
async def get_roadview_page(location_id: str) -> HTMLResponse:
    """WebView(webview_flutter)가 직접 로드하는 로드뷰 페이지.

    JSON API가 아니라 완결된 HTML을 반환한다 — 카카오맵 JS SDK는 로드된 페이지의
    도메인을 카카오 개발자 콘솔에 등록된 플랫폼과 대조하므로, 앱 안에서 만든
    HTML 문자열을 그냥 렌더링하는 대신 이 백엔드 도메인에서 서빙해야 한다.
    """
    if not settings.kakao_map_js_key:
        return HTMLResponse(_message_page("카카오맵 키가 설정되지 않았어요"))

    location = await _tour_api_service.get_location_by_id(location_id)
    if location is None:
        return HTMLResponse(_message_page("장소 정보를 찾을 수 없어요"), status_code=404)

    # 검색/상세 조회 단계에서 이미 정확한 좌표를 구해뒀으면(카카오 검색 결과,
    # 또는 큐레이션 장소의 보강된 좌표) 그걸 그대로 쓴다. "수원 래미안광교아파트"처럼
    # 지명+장소명 앞부분만 뽑아 다시 지오코딩하면 도로명/번지가 날아가 엉뚱한 곳으로
    # 튀거나 아예 못 찾는 경우가 많아, 이미 아는 좌표를 버리고 재검색할 이유가 없다.
    if location.latitude is not None and location.longitude is not None:
        lat, lng = location.latitude, location.longitude
    else:
        query = simplify_place_name(location.region, location.name)
        coords = await _kakao_local_service.geocode(query)
        if coords is None:
            return HTMLResponse(_message_page(f"'{location.name}'의 위치를 찾지 못했어요"))
        lat, lng = coords
    return HTMLResponse(
        _roadview_page(lat=lat, lng=lng, label=location.name, js_key=settings.kakao_map_js_key)
    )
