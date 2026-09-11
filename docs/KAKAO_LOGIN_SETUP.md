# 카카오 로그인 — 네이티브 설정 가이드

백엔드(`/api/auth/kakao/login`)와 Flutter 쪽 코드(`AuthRepository`, `authStateProvider`,
프로필 화면의 "카카오로 시작하기" 버튼)는 이미 준비되어 있습니다. 아래는 실제 기기에서
로그인이 동작하게 만들기 위해 **사용자님이 Kakao Developers 콘솔 + 로컬 파일에서**
직접 해야 하는 부분입니다.

## 1. Kakao Developers 콘솔 설정 확인

1. [Kakao Developers](https://developers.kakao.com) → 내 애플리케이션 → 해당 앱
2. **제품 설정 → 카카오 로그인** → 활성화 ON
3. **플랫폼 → Android 플랫폼 등록**:
   - 패키지명: `com.yetgil.yetgil_app` (현재 `android/app/build.gradle.kts`의 `applicationId`와 정확히 일치해야 함)
   - 마켓 URL은 나중에 Play 스토어 등록 후 채워도 됨
4. **키 해시 등록** (Android 플랫폼 등록 화면에 입력란 있음):
   - 디버그 키 해시 생성:
     ```bash
     keytool -exportcert -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
     ```
     (Windows에 openssl이 없으면 Git Bash에 포함된 openssl 사용, 또는 Flutter가 설치한 JDK의 `keytool` 사용)
   - **릴리스 키 해시도 나중에 반드시 추가**해야 함 — Play 스토어 배포용 서명 키를 만들면 그 키로도 위 명령을 다시 실행해서 해시를 하나 더 등록해야 실제 배포판에서 로그인이 동작합니다. (디버그 키 해시만 등록하면 `flutter run`은 되는데 릴리스 APK/AAB는 로그인이 막힙니다.)

## 2. 네이티브 앱 키를 로컬 파일에 넣기

앱 자체 시크릿이 아니라 앱에 내장되는 공개 식별자이지만, 이 프로젝트는 어떤 키도
소스에 직접 적지 않는 원칙(`PROJECT_BRIEF.md` 7장)을 지킵니다. 그래서 두 곳 모두
**커밋되지 않는 로컬 파일**에 넣습니다.

**`app/android/local.properties`** (이미 존재하는, gitignore된 파일)에 한 줄 추가:
```properties
kakao.nativeAppKey=여기에_네이티브_앱_키
```
→ `android/app/build.gradle.kts`가 이 값을 읽어 매니페스트의 리다이렉트 스킴
(`kakao{네이티브앱키}://oauth`)에 자동으로 채워 넣습니다.

**Dart 쪽**은 실행/빌드할 때 `--dart-define`으로 같은 값을 전달합니다:
```bash
flutter run --dart-define=KAKAO_NATIVE_APP_KEY=여기에_네이티브_앱_키
```
매번 치기 귀찮으면 `app/`에 `.vscode/launch.json`이나 로컬 스크립트에 넣어두는 걸 권장합니다
(이 파일도 개인 설정이라 커밋 대상이 아닙니다).

> 두 군데(local.properties, --dart-define)에 **같은 네이티브 앱 키**를 넣어야 합니다.
> 하나라도 다르면 카카오 로그인 리다이렉트가 실패합니다.

## 3. 백엔드 `.env`

```bash
KAKAO_REST_API_KEY=여기에_REST_API_키
```
현재 로그인 플로우(SDK 방식)에서는 실제로 호출되진 않지만, 나중에 관리자 API
(연결 끊기 등)를 붙일 때 필요하므로 미리 채워둡니다.

## 4. 동작 확인

```bash
cd app
flutter run --dart-define=API_BASE_URL=http://<백엔드_주소>:8000 \
            --dart-define=KAKAO_NATIVE_APP_KEY=여기에_네이티브_앱_키
```

프로필 탭 → "카카오로 시작하기" 클릭 → 카카오톡 설치 기기면 카카오톡 앱으로,
아니면 카카오계정 웹 로그인 화면으로 전환되면 정상입니다. 로그인 성공 후
프로필 화면에 실제 카카오 닉네임이 뜨면 백엔드까지 연결이 끝난 것입니다.

## 5. 자주 막히는 지점

- **키 해시 불일치**: 콘솔에 등록한 해시와 실제 서명 키 해시가 다르면 `KOE010` 오류.
  디버그/릴리스 키 각각 해시를 등록했는지 확인.
- **패키지명 불일치**: 콘솔에 등록한 패키지명과 `applicationId`가 정확히 같아야 함.
- **리다이렉트 스킴 불일치**: `local.properties`와 `--dart-define`의 네이티브 앱 키가
  다르면 로그인 웹뷰에서 앱으로 돌아오지 못하고 멈춤.
- **카카오톡 미설치 기기**: 코드가 자동으로 카카오계정 웹 로그인으로 폴백하므로 별도 처리 불필요.
