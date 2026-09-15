# 홈 화면 히어로 배너 이미지

AI로 생성한 실제 장소 사진 6장 — `hero_highlight_banner.dart`가 순서대로 돌아가며 보여준다.
"자세히 보기"를 누르면 `core/data/hero_highlights.dart`에 적힌 실제 location id로
`/compare/:id`(관광정보 상세)로 이동한다.

| 파일 | 실제 장소 | location id |
|---|---|---|
| gangneung_namsan.jpg | 강릉 남산공원 | kakao-17384830 |
| gogunsan.jpg | 고군산군도 | kakao-8682467 |
| gwanmunsa.jpg | 관문사(서울 서초구) | kakao-7828107 |
| gwaneumsa_busan.jpg | 관음사(부산 사하구) | kakao-8753135 |
| seokcheonsa.jpg | 석천사(전남 여수시) | kakao-8431958 |
| yonghwasa.jpg | 용화사(충남 논산시) | kakao-8463828 |

원본은 1938x811 PNG(2.4~3MB)였고, 1200px 폭 JPEG(85% 품질)로 리사이즈해 용량을 줄였다.
