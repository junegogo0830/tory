"""카카오맵 마커 웹뷰 페이지를 만드는 공용 HTML 조각.

roadview.py/community_map.py가 쓰던 "완결된 HTML을 직접 서빙"하는 패턴(카카오맵
JS SDK가 로드된 페이지의 도메인을 콘솔 등록 플랫폼과 대조하기 때문에 JSON이
아니라 실제 HTML을 서빙해야 한다)을 그대로 재사용한다. 마커를 눌렀을 때 이동할
링크는 호출부가 원하는 커스텀 스킴(yetgil-post://, yetgil-course-place:// 등)을
그대로 넘기면 되고, 프론트의 WebView NavigationDelegate가 가로채 앱 안에서
처리한다.
"""

import json


def render_message_page(message: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  html,body{{margin:0;height:100%;background:#F2EFEA;
    display:flex;align-items:center;justify-content:center;
    font-family:-apple-system,sans-serif;color:#1F1A16;text-align:center;padding:24px;
    box-sizing:border-box;}}
</style></head>
<body><div>{message}</div></body></html>"""


def render_map_page(*, markers: list[dict], js_key: str) -> str:
    """markers: [{"lat", "lng", "title", "place", "linkUrl"}] — linkUrl은 인포윈도우의
    "보기" 링크 href로, 프론트가 가로챌 커스텀 스킴을 그대로 넘긴다."""
    center_lat = sum(m["lat"] for m in markers) / len(markers)
    center_lng = sum(m["lng"] for m in markers) / len(markers)
    # </script> 같은 문자열이 마커 텍스트(제목 등)에 섞여 있어도 HTML 파서가
    # <script> 블록을 조기 종료하지 않도록 "</"를 이스케이프해서 심는다.
    markers_json = json.dumps(markers, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html,body,#map{{margin:0;padding:0;width:100%;height:100%;background:#F2EFEA;}}
</style></head>
<body>
  <div id="map"></div>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey={js_key}"></script>
  <script>
    try {{
      var map = new kakao.maps.Map(document.getElementById('map'), {{
        center: new kakao.maps.LatLng({center_lat}, {center_lng}),
        level: 6
      }});
      var bounds = new kakao.maps.LatLngBounds();
      var markersData = {markers_json};
      markersData.forEach(function(m, i) {{
        var pos = new kakao.maps.LatLng(m.lat, m.lng);
        bounds.extend(pos);
        var marker = new kakao.maps.Marker({{ position: pos, map: map }});
        var label = new kakao.maps.CustomOverlay({{
          position: pos, yAnchor: 2.6,
          content: '<div style="background:#6A452C;color:#fff;border-radius:99px;' +
            'width:20px;height:20px;display:flex;align-items:center;justify-content:center;' +
            'font-size:11px;font-weight:700;">' + (i + 1) + '</div>'
        }});
        label.setMap(map);
        var content = '<div style="padding:8px 10px;font-size:13px;max-width:180px;line-height:1.4;">' +
          '<strong>' + m.title + '</strong><br/>' + m.place +
          (m.linkUrl ? '<br/><a href="' + m.linkUrl + '" style="color:#6A452C;">보기 &rarr;</a>' : '') +
          '</div>';
        var infowindow = new kakao.maps.InfoWindow({{ content: content, removable: true }});
        kakao.maps.event.addListener(marker, 'click', function() {{ infowindow.open(map, marker); }});
      }});
      if (markersData.length > 1) map.setBounds(bounds);
    }} catch (e) {{
      document.body.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100%;font-family:-apple-system,sans-serif;">지도를 불러오지 못했어요</div>';
    }}
  </script>
</body></html>"""
