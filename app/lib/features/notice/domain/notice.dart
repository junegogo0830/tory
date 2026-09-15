import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 공지사항 — 관리자 화면이 따로 없는 스코프라 앱에 정적으로 내장한다(서버
/// 콘텐츠가 아니라 앱 업데이트로만 바뀌는 안내문이라 이 편이 더 단순하다).
/// 앱 사용법 + 게시판별로 달라진 기능을 소개하는 용도.
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
    required this.badgeColor,
    required this.date,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final IconData icon;
  final Color badgeColor;
  // 홈 화면 공지사항 카드의 날짜 표시용 — "2026. 09. 14" 형식.
  final String date;
}

const List<Notice> notices = [
  Notice(
    id: 'getting-started',
    title: '옛길, 이렇게 시작해보세요',
    summary: '고향 검색부터 동네 커뮤니티 가입까지 한눈에',
    icon: Icons.explore_outlined,
    badgeColor: AppColors.pastelSky,
    date: '2026. 09. 14',
    body: '''
옛길은 그 시절 우리 동네와 오늘의 모습을 비교하고, 같은 동네 사람들과 추억을
나누는 앱이에요.

1. 홈 화면 검색창에 고향 주소나 장소 이름을 입력하면 그때와 지금 사진을
   나란히 비교할 수 있어요.
2. 프로필 탭에서 회원가입하거나 카카오로 로그인하면 추억을 저장하고 댓글을
   남길 수 있어요.
3. 커뮤니티 탭에서 동네를 하나 골라 가입하면 그 동네 게시판(자유·추억·주민·
   관광정보·타임캡슐)에 글을 쓸 수 있어요. 살았던 곳이 여러 곳이면 나중에
   더 추가해서 토글로 오갈 수 있어요.
4. 코스 탭에서는 추천 코스를 보거나, 직접 장소를 골라 나만의 코스를 만들어
   공유할 수 있어요.

궁금한 점은 프로필 탭 하단의 "옛길 소개"에서 더 볼 수 있어요.''',
  ),
  Notice(
    id: 'board-resident',
    title: '주민 게시판이 중고거래 게시판으로 바뀌었어요',
    summary: '가격·거래상태와 함께 동네 중고거래를 해보세요',
    icon: Icons.storefront_outlined,
    badgeColor: AppColors.pastelMint,
    date: '2026. 09. 10',
    body: '''
주민 게시판이 동네 중고거래·나눔 게시판으로 새로워졌어요.

- 글을 쓸 때 가격을 입력하면 목록과 상세 화면에 바로 보여요. 가격을 비워두면
  "나눔"으로 표시돼요.
- 거래상태는 판매중 → 예약중 → 거래완료 순서로, 글쓴이가 상세 화면에서
  언제든 바꿀 수 있어요.
- 게시판 목록에서도 최신 글의 가격과 거래상태를 바로 확인할 수 있어요.

직거래 시 안전을 위해 공공장소에서 만나는 걸 권장해요.''',
  ),
  Notice(
    id: 'board-info',
    title: '관광정보 게시판을 지도로도 볼 수 있어요',
    summary: '장소를 첨부하면 지도에서 한눈에 모아볼 수 있어요',
    icon: Icons.map_outlined,
    badgeColor: AppColors.pastelButter,
    date: '2026. 09. 06',
    body: '''
관광정보 게시판에 글을 쓸 때 이제 실제 장소를 검색해서 첨부할 수 있어요.

- 글쓰기 화면에서 "장소를 검색해보세요"에 가볼 만한 곳을 검색해 골라주세요.
- 게시판 화면 오른쪽 위 지도 아이콘을 누르면, 장소가 첨부된 글들을 지도
  위 마커로 한눈에 볼 수 있어요.
- 마커를 눌러 "게시글 보기"를 누르면 그 글 상세로 바로 이동해요.

장소 없이 글만 올려도 괜찮아요 — 지도에는 장소가 있는 글만 표시돼요.''',
  ),
  Notice(
    id: 'board-memory-timecapsule',
    title: '추억 게시판 · 타임캡슐 편지, 이렇게 달라요',
    summary: '사진과 연도로 그 시절을, 편지로 미래를 남겨보세요',
    icon: Icons.photo_camera_back_outlined,
    badgeColor: AppColors.pastelPeach,
    date: '2026. 09. 02',
    body: '''
추억 게시판은 사진과 함께 그 시절 이야기를 남기는 곳이에요. 연도를 함께
적으면 "연도별 타임라인"(게시판 오른쪽 위 아이콘)에서 시간순으로 모아볼 수
있고, 홈 화면 "오늘의 추억"에도 하루에 하나씩 소개돼요.

타임캡슐 편지는 미래의 우리 동네 사람들에게 보내는 편지예요. 봉인을 풀 날짜를
정해두면, 그날이 오기 전까지는 아무도(글쓴이 포함) 내용을 볼 수 없어요.''',
  ),
];
