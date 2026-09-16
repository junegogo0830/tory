# 홈 화면 히어로 배너 이미지

AI로 생성한 실제 장소 사진 6장 — `hero_highlight_banner.dart`가 순서대로 돌아가며 보여준다.
"자세히 보기"는 `core/data/hero_highlights.dart`의 고정 `hero-*` ID로
`/compare/:id`(장소 상세)에 바로 이동한다. 서버의 `services/hero_locations.py`가
2026-09-16 카카오 Local에서 확인한 이름·주소·좌표를 반환하므로 기본 장소 조회는
외부 검색이나 Redis 캐시, 워커 프로세스에 의존하지 않는다.

(예전엔 `kakao-{id}` 값을 고정으로 박아뒀었는데, 카카오는 REST로 "id 상세
재조회"가 안 돼서 그 id가 실제로 검색된 적이 없으면 캐시가 비어 영영
"장소 정보를 찾을 수 없음"이 났다. 검색어 기반으로 바꿔도 외부 검색과 캐시에
의존했으므로, 고정 배너에는 서버가 직접 해석할 수 있는 ID를 사용한다.)

| 파일 | 실제 장소 |
|---|---|
| gangneung_namsan.jpg | 강릉 남산공원 |
| gogunsan.jpg | 고군산군도 |
| gwanmunsa.jpg | 관문사(서울 서초구) |
| gwaneumsa_busan.jpg | 관음사(부산 사하구) |
| seokcheonsa.jpg | 석천사(전남 여수시) |
| yonghwasa.jpg | 용화사(충남 논산시) |

원본은 1938x811 PNG(2.4~3MB)였고, 1200px 폭 JPEG(85% 품질)로 리사이즈해 용량을 줄였다.
