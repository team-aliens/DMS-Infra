# DMS docker-compose (인스턴스별 배포)

Terraform으로 만든 각 EC2 인스턴스에서 돌릴 컨테이너 정의. **인스턴스 1대 = 디렉토리 1개.**
부트스트랩이 Docker만 깔아두므로, 해당 디렉토리를 인스턴스로 복사 → `.env` 채우고
`docker compose up -d`.

| 디렉토리 | 인스턴스 | 컨테이너 | 공개 포트 |
|---|---|---|---|
| `gateway/` | Gateway(public) | nginx + dms-gateway + node_exporter | 80, 443, 9100 |
| `main/` | Main(private) | dms-main + node_exporter | 8081, 9100 |
| `notification/` | Notification(private) | dms-notification + node_exporter | 8082, 9100 |
| `infra/` | Infra(private) | mysql + redis + rabbitmq + node_exporter | 3306, 6379, 5672, 15672, 9100 |
| `monitoring/` | Monitoring(private) | prometheus + grafana + node_exporter | 9090, 3000, 9100 |

## 트래픽 흐름

```
Internet → nginx(80/443) → gateway:8080 ─┬→ MAIN_IP:8081  (dms-main)
                                          └→ NOTI_IP:8082  (dms-notification)
dms-main         → INFRA_IP:3306(mysql) / 6379(redis) / 5672(rabbitmq) / S3 / Gmail SMTP
dms-notification → INFRA_IP:3306(mysql) / 5672(rabbitmq) / FCM / Slack
prometheus       → 각 인스턴스 9100(node_exporter)
```

서비스 간 통신은 **프라이빗 IP**로 한다. `cd infra/environments/prod && terraform output`
으로 IP를 확인해 각 `.env` / `prometheus.yml` 에 채운다.

## 배포 순서

IP 의존성 때문에 **infra → main/notification → gateway → monitoring** 순서를 권장.

```bash
# (예: infra 인스턴스에서)
cp .env.example .env && vi .env      # 비밀번호 채우기
docker compose up -d
docker compose ps
```

ECR 이미지를 쓰는 경우 먼저 로그인:
```bash
aws ecr get-login-password --region ap-northeast-2 \
  | docker login --username AWS --password-stdin <ECR_REGISTRY>
```

## 주의

- **`.env` 는 커밋 금지** (`.gitignore` 처리됨). 시크릿은 SSM Parameter Store 권장.
- **`infra/`의 데이터**(mysql/redis/rabbitmq)는 루트 볼륨의 `/data`에 저장된다(별도 EBS 미사용).
  `mysql-init` 스크립트는 **최초 부팅(빈 /data)에만** 실행되므로, 이후 DB/유저
  변경은 직접 적용해야 한다.
- **DB 백업**: `db-backup` 사이드카가 `BACKUP_INTERVAL`마다 `mysqldump`를 떠
  `s3://$BACKUP_S3_BUCKET/$BACKUP_S3_PREFIX/...`로 올린다. 이미지는 다른 서비스와
  달리 `backup/`에서 **로컬 빌드**되므로, 처음 또는 스크립트 변경 시
  `docker compose up -d --build` 로 띄운다. AWS 키는 `.env`에 두지 말고 인스턴스
  프로파일(`iam_infra`)을 쓴다.
- **S3 자격증명**: Main 인스턴스엔 S3 IAM 역할이 붙어 있다. `.env`의
  `AWS_ACCESS`/`AWS_SECRET`을 비워 인스턴스 프로파일을 쓰는 게 이상적이지만,
  앱 기본값이 `access`/`secret` 문자열이라 빈 값 처리 동작을 한 번 확인할 것.
- **HTTPS**: 현재 nginx는 80(HTTP)만 프록시. 인증서 발급(certbot 등) 후
  `gateway/nginx/conf.d/dms.conf`의 443 블록 주석 해제.
- **이미지 빌드/푸시**: Dockerfile은 각 모듈(`dms-gateway/`, `dms-main/`,
  `dms-notification/`)에 있고, compose는 ECR 이미지를 **pull**만 한다(빌드 안 함).
  둘은 빌드/실행 라이프사이클이 달라 위치가 분리돼 있는 게 정상.
  **빌드 컨텍스트는 반드시 레포 루트** (Dockerfile이 buildSrc/contracts 등 멀티모듈
  전체를 COPY 하므로):
  ```bash
  # 레포 루트에서
  docker build -f dms-gateway/Dockerfile      -t <ECR>/dms-gateway:latest .
  docker build -f dms-main/Dockerfile         -t <ECR>/dms-main:latest .
  docker build -f dms-notification/Dockerfile -t <ECR>/dms-notification:latest .
  ```
  (CI/CD에서 자동화. compose 파일 위치와는 무관.)
