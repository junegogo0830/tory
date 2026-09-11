# 배포 런북 — Oracle Cloud Always Free VM

옛길 백엔드(FastAPI + Postgres + Redis)를 Oracle Cloud Infrastructure(OCI)
Always Free 티어 VM 한 대에 `docker compose`로 띄우는 절차입니다. 앱(Flutter)은
Google Play로 별도 배포되므로 이 문서는 API 서버만 다룹니다.

## 0. 사전 준비

- OCI 계정 (신용카드 등록 필요하지만 Always Free 리소스는 과금되지 않음)
- 이 저장소를 올려둘 Git 원격 저장소 (GitHub 등)
- 아래 "발급해야 할 키" 목록의 값들 (최소 `TOUR_API_KEY`, `JWT_SECRET_KEY`는 필수)

## 1. VM 생성

1. OCI 콘솔 → **Compute → Instances → Create Instance**
2. Image: **Ubuntu 22.04**, Shape: **VM.Standard.A1.Flex** (Always Free — ARM, 최대 4 OCPU/24GB까지 무료)
3. SSH 키 페어 생성 후 다운로드 (개인키 보관)
4. 생성 후 **Public IP** 확인

## 2. 방화벽 (Security List / NSG)

VM의 서브넷 Security List에 인그레스 규칙 추가:

| 포트 | 용도 |
|---|---|
| 22 | SSH |
| 80 | HTTP (추후 Caddy/nginx용) |
| 443 | HTTPS (추후) |
| 8000 | 임시로 API 직접 확인용 (도메인 붙이면 막아도 됨) |

Ubuntu 자체 방화벽(`ufw`)도 쓴다면 같은 포트를 열어야 합니다:
```bash
sudo ufw allow 22,80,443,8000/tcp
sudo ufw enable
```

## 3. Docker 설치

```bash
ssh -i <개인키> ubuntu@<PUBLIC_IP>

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
docker --version && docker compose version
```

## 4. 저장소 배치 + 환경변수

```bash
git clone <레포_URL> yetgil
cd yetgil
cp .env.example .env
nano .env   # 아래 "발급해야 할 키" 채우기
```

`.env`에서 **반드시** 채워야 하는 값:

```bash
DEBUG=false                                   # 프로덕션은 반드시 false
JWT_SECRET_KEY=$(openssl rand -hex 32)        # 아래 명령으로 직접 생성해서 붙여넣기
TOUR_API_KEY=...
NAVER_NEWS_CLIENT_ID=...
NAVER_NEWS_CLIENT_SECRET=...
KAKAO_MAP_JS_KEY=...
KAKAO_REST_API_KEY=...
POSTGRES_PASSWORD=<changeme 대신 실제 비밀번호>
```

> `DEBUG=false`인데 `JWT_SECRET_KEY`가 비어 있거나 기본값이면 서버가 기동을 거부합니다
> (`backend/app/main.py`의 안전장치). 반드시 `openssl rand -hex 32`로 새로 생성하세요.

## 5. 기동

```bash
cd infra
docker compose up -d --build
docker compose ps        # 세 컨테이너 모두 healthy/running 확인
docker compose logs -f backend   # alembic upgrade head 로그 확인
```

`backend` 컨테이너는 시작할 때마다 `alembic upgrade head`를 먼저 실행한 뒤
uvicorn을 띄웁니다 — 최초 기동 시 이 로그에서 테이블 생성 여부를 확인하세요.

## 6. 확인

```bash
curl http://<PUBLIC_IP>:8000/health
# {"status":"ok"}
```

Flutter 앱의 `--dart-define=API_BASE_URL=http://<PUBLIC_IP>:8000`으로 실기기 테스트 가능.

## 7. 도메인 + HTTPS (도메인 구매 후)

도메인을 구입해 VM의 Public IP로 A 레코드를 연결한 뒤, `infra/`에 Caddy 리버스
프록시를 하나 추가하면 인증서 발급까지 자동입니다:

```yaml
# infra/docker-compose.yml에 추가
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    depends_on:
      - backend

volumes:
  caddy_data:
```

```
# infra/Caddyfile
api.example.com {
  reverse_proxy backend:8000
}
```

이후 `backend` 서비스의 `ports: 8000:8000` 노출은 제거하고 Caddy를 통해서만
접근하도록 막는 것을 권장합니다. 도메인이 정해지면 다시 요청해주세요 — Caddyfile까지
채워서 반영하겠습니다.

## 8. 업데이트 배포

```bash
cd yetgil
git pull
cd infra
docker compose up -d --build
```

## 9. 발급해야 할 키 요약

이전 대화에서 정리한 전체 목록 중, **이 VM 배포에 실제로 필요한 것만** 다시 정리:

| 키 | 필수 여부 | 비고 |
|---|---|---|
| `TOUR_API_KEY` | 필수 | data.go.kr |
| `NAVER_NEWS_CLIENT_ID/_SECRET` | 필수 | developers.naver.com |
| `KAKAO_MAP_JS_KEY` | 필수 | developers.kakao.com |
| `KAKAO_REST_API_KEY` | 카카오 로그인 쓰면 필수 | 위와 같은 Kakao 앱에서 "카카오 로그인" 활성화 후 발급 |
| `JWT_SECRET_KEY` | 필수 | 직접 생성 (`openssl rand -hex 32`), 외부 발급 아님 |
| `POSTGRES_PASSWORD` | 필수 | 직접 정하기, 기본값(`changeme`) 그대로 쓰지 말 것 |
