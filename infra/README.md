# DMS AWS Infrastructure (Terraform)

DMS 서비스를 AWS로 마이그레이션하기 위한 IaC. EC2 기반 멀티 인스턴스 구성.

## 구조

```
infra/
├── modules/
│   ├── network/     # VPC, 서브넷, IGW, (선택)NAT, S3 엔드포인트
│   ├── security/    # 역할별 보안그룹
│   ├── compute/     # EC2 인스턴스 + EBS
│   ├── iam/         # 인스턴스 프로파일 (SSM, 선택적 S3)
│   └── storage/     # S3 버킷
└── environments/
    └── prod/        # 5개 인스턴스 멀티티어
```

## 아키텍처 (prod)

```
                 Internet
                    │
              [EIP] │ :80/:443
        ┌───────────▼───────────┐  public subnet
        │  Gateway (t3.small)   │  Nginx + Spring Cloud Gateway(8080)
        │  + NAT 인스턴스 겸용   │
        └───────────┬───────────┘
        ───────────────────────────── private subnet
   ┌────────────┬───┴────┬──────────────┐
   ▼            ▼        ▼              ▼
 Main(8081) Notification Infra        Monitoring
 t3.medium   (8082)      MySQL/Redis   Prometheus
 + S3 IAM    t3.medium   /RabbitMQ     /Grafana
                         t3.medium     t3.medium
                         +50GB EBS
```

| 인스턴스 | 서브넷 | 타입 | 역할 | 포트 |
|---|---|---|---|---|
| Gateway | public | t3.small | Nginx + Gateway + NAT | 80/443 → 8080 |
| Main | private | t3.medium | dms-main + S3 접근 | 8081 |
| Notification | private | t3.medium | dms-notification | 8082 |
| Infra | private | t3.medium | MySQL/Redis/RabbitMQ | 3306/6379/5672 |
| Monitoring | private | t3.medium | Prometheus/Grafana | 9090/3000 |

- 메일은 AWS SES가 아닌 **기존 이메일(SMTP)** 사용 → IAM에 SES 권한 없음
- 파일 업로드용 **S3 버킷 1개** + Main 인스턴스에만 S3 접근 권한
- 모든 인스턴스 **SSM Session Manager** 접속 가능 (SSH 없이도 관리)

## 사용법

```bash
# 0) 사전 준비: AWS CLI 자격증명, EC2 키페어 생성
aws ec2 create-key-pair --key-name dms-prod-key --query 'KeyMaterial' \
  --output text > ~/.ssh/dms-prod-key.pem && chmod 400 ~/.ssh/dms-prod-key.pem

cd environments/prod
cp terraform.tfvars.example terraform.tfvars   # 값 채우기 (key_name, admin_cidrs, s3_bucket_name)

terraform init
terraform plan
terraform apply
```


### 원격 상태 (팀 작업 시 권장)
`backend.tf.example`를 `backend.tf`로 복사하고 상태용 S3 버킷을 먼저 만든 뒤
`terraform init -migrate-state`. DynamoDB 없이 S3 네이티브 락 사용.

## LocalStack에서 테스트

실제 AWS 비용 없이 Terraform 배선을 검증할 수 있다. **단, EC2는 mock이라 실제
부팅·user_data(Docker/NAT/부트스트랩)·SSM은 동작하지 않는다.** `apply`가 끝까지
도는지(참조·의존성·count) 확인하는 용도.

```bash
# LocalStack 기동 (Pro면 EC2/VPC 지원이 더 넓음)
localstack start -d

# 권장: tflocal (엔드포인트 자동 주입, 파일 수정 불필요)
pip install terraform-local
cd environments/prod

# LocalStack가 가진 더미 AMI id 하나 조회
AMI=$(aws --endpoint-url=http://localhost:4566 ec2 describe-images \
  --query 'Images[0].ImageId' --output text)

tflocal init
tflocal apply -auto-approve \
  -var "ami_id=$AMI" \
  -var 'key_name=dummy' \
  -var 'admin_cidrs=["1.2.3.4/32"]' \
  -var 's3_bucket_name=dms-localstack-test'
```

`data.aws_ami`(Canonical 조회)는 LocalStack에 없으므로 반드시 `ami_id` 변수로
더미 AMI를 주입한다. tflocal 대신 `*_override.tf`로 provider 엔드포인트를 덮을 수도
있지만, 그 파일이 있는 동안 **해당 디렉토리의 모든 terraform 명령이 LocalStack로
향하므로** 실제 적용 전 반드시 삭제할 것 (그래서 tflocal 권장).

> 검증 결과: prod 스택 72개 리소스(EC2 5대 포함) LocalStack Pro에서 apply 성공 확인.

## 비용 메모 / 주의할 점

- **NAT**: 관리형 NAT Gateway는 월 ~45,000원+ 추가라 견적에 없음. 기본값은
  **게이트웨이 인스턴스를 NAT로 사용**(`enable_nat_gateway = false`)해 EIP 1개로 해결.
  단점: 게이트웨이가 아웃바운드 단일 장애점이 됨. 관리형이 필요하면 `true`로.
- **DB가 EC2(Infra) 위에 있음**: RDS 미사용 → 백업/HA를 직접 관리해야 함.
  데이터는 루트 볼륨(`/data`)에 두고, 내구성은 **주기적 mysqldump → S3** 로 확보.
  백업 잡은 `compose/infra` 의 `db-backup` 사이드카가 담당하고, 객체는
  `backups/` prefix 에 저장되며 `backup_retention_days`(기본 30일) 뒤 자동 만료.
  Infra 인스턴스는 이 업로드를 위해 S3(`backups/*`) 권한이 붙은 `iam_infra` 사용.
- **단일 인스턴스/단일 AZ**: HA 없음. 비용 최소화 우선. cross-AZ 전송요금 회피를
  위해 prod 인스턴스는 모두 같은 AZ(private subnet[0])에 배치.
- **t3 버스터블**: Gateway(t3.small)가 Nginx + NAT를 겸하므로 트래픽 급증 시 CPU
  크레딧 소진 가능. 필요하면 unlimited 모드 또는 상위 타입 고려.
- **시크릿**: DB 비밀번호·FCM 키 등은 tfvars/state에 평문으로 두지 말 것.
  SSM Parameter Store / Secrets Manager 사용 권장 (`.gitignore`에 tfvars 포함됨).
- **앱 배포**: 부트스트랩은 Docker/Nginx 런타임만 준비. 컨테이너 구동은 기존 CD
  (`.github/workflows`)에서 담당.

## 견적 대비

제시한 prod ≈ 166,000원 구성과 일치 (EC2 5대 + EBS/S3 + EIP 1개).
NAT Gateway를 켜면 견적을 초과하니 주의. (마이그레이션은 prod만 진행)
