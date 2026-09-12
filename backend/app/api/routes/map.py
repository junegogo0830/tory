import html
import json

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from ...core.config import settings
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/map", tags=["map"])
_tour_api_service = TourApiService()

_SEARCH_RADIUS_M = 3000
_MAX_PLACES = 20


def _message_page(message: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  html,body{{margin:0;height:100%;background:#F2EFEA;
    display:flex;align-items:center;justify-content:center;
    font-family:-apple-system,sans-serif;color:#1F1A16;text-align:center;padding:24px;
    box-sizing:border-box;}}
</style></head>
<body><div>{html.escape(message)}</div></body></html>"""


def _map_page(*, lat: float, lng: float, places: list[dict], js_key: str) -> str:
    # JSON을 <script> 안에 그대로 심을 때 문자열에 "</"가 섞여 있으면 스크립트
    # 태그가 조기 종료될 수 있어(예: 장소명에 "</script>"가 들어있는 극단적인
    # 경우) 방어적으로 이스케이프한다.
    places_json = json.dumps(places, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html,body,#map{{margin:0;padding:0;width:100%;height:100%;background:#F2EFEA;}}
  #fallback{{display:none;height:100%;align-items:center;justify-content:center;
    font-family:-apple-system,sans-serif;color:#1F1A16;text-align:center;padding:24px;
    box-sizing:border-box;}}
</style></head>
<body>
  <div id="map"></div>
  <div id="fallback">
    <div>지도를 불러오지 못했어요</div>
  </div>
  <script
    src="https://dapi.kakao.com/v2/maps/sdk.js?appkey={js_key}"
    onerror="document.getElementById('map').style.display='none';document.getElementById('fallback').style.display='flex';"
  ></script>
  <script>
    try {{
      if (typeof kakao === 'undefined' || !kakao.maps) {{
        throw new Error('Kakao Maps SDK failed to load');
      }}
      var center = new kakao.maps.LatLng({lat}, {lng});
      var map = new kakao.maps.Map(document.getElementById('map'), {{ center: center, level: 5 }});

      new kakao.maps.Marker({{
        map: map, position: center,
        image: new kakao.maps.MarkerImage(
          'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyMCIgaGVpZ2h0PSIyMCI+PGNpcmNsZSBjeD0iMTAiIGN5PSIxMCIgcj0iOCIgZmlsbD0iIzZBNDUyQyIgc3Ryb2tlPSIjZmZmIiBzdHJva2Utd2lkdGg9IjMiLz48L3N2Zz4=',
          new kakao.maps.Size(20, 20)
        ),
      }});

      var places = {places_json};
      var infoWindow = new kakao.maps.InfoWindow({{ zIndex: 1 }});
      places.forEach(function(place) {{
        var marker = new kakao.maps.Marker({{
          map: map,
          position: new kakao.maps.LatLng(place.lat, place.lng),
        }});
        kakao.maps.event.addListener(marker, 'click', function() {{
          infoWindow.setContent(
            '<div style="padding:6px 10px;font-size:13px;white-space:nowrap;">' +
            place.name.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>'
          );
          infoWindow.open(map, marker);
        }});
      }});
    }} catch (e) {{
      document.getElementById('map').style.display = 'none';
      document.getElementById('fallback').style.display = 'flex';
    }}
  </script>
</body></html>"""


@router.get("/nearby", response_class=HTMLResponse)
async def get_nearby_map_page(lat: float, lng: float) -> HTMLResponse:
    """WebView가 직접 로드하는 "내 주변 관광지" 지도 페이지 (roadview.py와 동일한
    이유로 HTML을 백엔드에서 직접 서빙 — 카카오맵 JS SDK 도메인 검증 때문)."""
    if not settings.kakao_map_js_key:
        return HTMLResponse(_message_page("카카오맵 키가 설정되지 않았어요"))

    raw_places = await _tour_api_service.find_nearby_places(
        latitude=lat, longitude=lng, radius_m=_SEARCH_RADIUS_M,
        num_rows=_MAX_PLACES, content_type_id="12",
    )
    places = [
        {"name": p["title"], "lat": p["latitude"], "lng": p["longitude"]}
        for p in raw_places
        if p.get("latitude") is not None and p.get("longitude") is not None
    ]

    return HTMLResponse(
        _map_page(lat=lat, lng=lng, places=places, js_key=settings.kakao_map_js_key)
    )
