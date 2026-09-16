"""법적 고지 페이지(개인정보처리방침 등) — 정적 HTML을 그대로 서빙한다.
map.py/roadview.py와 같은 패턴으로 /api 밖의 공개 경로에 둔다(스토어 등록
폼에 그대로 붙여넣을 URL이 필요해서)."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/legal", tags=["legal"])

_PRIVACY_POLICY_HTML = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>옛길 개인정보처리방침</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", sans-serif;
    max-width: 720px; margin: 0 auto; padding: 32px 20px 80px; color: #1F1A16;
    line-height: 1.7; background: #FEFBF6; }
  h1 { font-size: 22px; margin-bottom: 4px; }
  .updated { color: #8A8078; font-size: 13px; margin-bottom: 28px; }
  h2 { font-size: 17px; margin-top: 32px; border-left: 4px solid #755039; padding-left: 10px; }
  table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 14px; }
  th, td { border: 1px solid #E5DED4; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #F2EFEA; white-space: nowrap; }
  ul { padding-left: 20px; }
  li { margin-bottom: 4px; }
  .contact { background: #F2EFEA; border-radius: 10px; padding: 16px; margin-top: 12px; font-size: 14px; }
</style>
</head>
<body>
  <h1>옛길 개인정보처리방침</h1>
  <div class="updated">시행일자: 2026년 9월 16일</div>

  <p>옛길(이하 "회사")은 이용자의 개인정보를 중요시하며, 「개인정보 보호법」 등 관련 법령을 준수합니다.
  회사는 본 개인정보처리방침을 통해 이용자가 제공하는 개인정보가 어떤 목적과 방식으로 이용되고 있으며,
  개인정보 보호를 위해 어떠한 조치가 취해지고 있는지 알려드립니다.</p>

  <h2>1. 수집하는 개인정보 항목 및 수집 방법</h2>
  <table>
    <tr><th>구분</th><th>수집 항목</th><th>수집 방법</th></tr>
    <tr><td>일반 회원가입</td><td>아이디, 비밀번호, 닉네임</td><td>이용자 직접 입력</td></tr>
    <tr><td>카카오 로그인</td><td>카카오 계정 고유 식별자, 닉네임, 프로필 사진</td><td>카카오 로그인 연동</td></tr>
    <tr><td>프로필 정보(선택)</td><td>성별, 이름, 전화번호, 연령대, 사는 지역, 모교·살았던 지역</td><td>이용자 직접 입력(정보 수정 화면)</td></tr>
    <tr><td>서비스 이용 과정</td><td>게시글·댓글·사진, 친구찾기 기능 이용 시 상대방과 주고받은 메시지, 저장한 장소·코스, 최근 열람한 코스</td><td>서비스 이용 중 자동/직접 생성</td></tr>
    <tr><td>위치 관련 정보</td><td>이용자가 검색창에 직접 입력한 지역·장소명</td><td>이용자 직접 입력(GPS 등 위치확인장치를 통한 자동 수집은 하지 않음)</td></tr>
  </table>

  <h2>2. 개인정보의 수집 및 이용 목적</h2>
  <ul>
    <li>회원 식별 및 로그인 등 회원제 서비스 제공</li>
    <li>동네 기반 커뮤니티, 코스 추천, 친구찾기 등 핵심 서비스 제공</li>
    <li>게시글·댓글·사진 등 이용자 생성 콘텐츠의 저장 및 표시</li>
    <li>부정 이용 방지 및 본인 확인(전화번호)</li>
    <li>공지사항 등 서비스 관련 안내</li>
  </ul>

  <h2>3. 개인정보의 보유 및 이용 기간</h2>
  <p>회원 탈퇴 시 지체 없이 파기합니다. 단, 관계 법령에 따라 보존할 필요가 있는 경우 해당 법령에서
  정한 기간 동안 보관합니다. 탈퇴 시 게시글·댓글·좋아요·저장 목록·친구찾기 연결 정보 등은 데이터베이스에서
  함께 삭제됩니다.</p>

  <h2>4. 개인정보의 제3자 제공</h2>
  <p>회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만 서비스 제공을 위해 카카오맵,
  한국관광공사 관광정보 API 등 외부 서비스를 이용해 정보를 "조회"하는 경우가 있으며, 이 과정에서
  이용자의 개인정보(계정 정보 등)가 해당 외부 서비스로 전달되지 않습니다.</p>

  <h2>5. 개인정보 처리의 위탁</h2>
  <table>
    <tr><th>수탁업체</th><th>위탁업무 내용</th></tr>
    <tr><td>Google Cloud Platform</td><td>서버 호스팅, 데이터베이스 운영, 사진 등 파일 저장</td></tr>
  </table>

  <h2>6. 이용자의 권리와 행사 방법</h2>
  <p>이용자는 언제든지 앱 내 "프로필 &gt; 정보 수정" 화면에서 본인의 개인정보를 조회·수정할 수 있으며,
  "회원 탈퇴"를 통해 수집된 개인정보의 삭제를 요청할 수 있습니다.</p>

  <h2>7. 개인정보의 안전성 확보 조치</h2>
  <ul>
    <li>비밀번호는 복호화 불가능한 방식으로 암호화하여 저장합니다.</li>
    <li>이용자와 서버 간 통신 구간은 HTTPS(TLS)로 암호화합니다.</li>
    <li>개인정보에 접근할 수 있는 인원을 최소화하고 접근권한을 관리합니다.</li>
  </ul>

  <h2>8. 개인정보 보호책임자</h2>
  <div class="contact">
    성명: 최병준<br>
    이메일: atrophyboy@naver.com<br>
    연락처: 010-4657-4893
  </div>

  <h2>9. 고지의 의무</h2>
  <p>본 개인정보처리방침은 법령·정책 또는 보안기술의 변경에 따라 내용이 추가·삭제 및 수정될 수 있으며,
  변경되는 경우 앱 공지사항 등을 통해 고지합니다.</p>
</body>
</html>"""


@router.get("/privacy", response_class=HTMLResponse)
async def privacy_policy() -> str:
    return _PRIVACY_POLICY_HTML
