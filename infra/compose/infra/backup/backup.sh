#!/usr/bin/env bash
# 주기적으로 MySQL 논리 덤프를 떠서 gzip 후 S3 에 업로드한다.
#
# 인증: AWS 자격증명은 EC2 인스턴스 프로파일(IMDS)에서 awscli 가 자동 획득한다.
#       (인스턴스에 iam_infra 프로파일, http_put_response_hop_limit=2 필요)
# 객체 키: s3://$S3_BUCKET/$S3_PREFIX/$DB_NAME/$DB_NAME-YYYYmmdd-HHMMSS.sql.gz
set -euo pipefail

: "${DB_HOST:=mysql}"
: "${DB_PORT:=3306}"
: "${DB_USER:=root}"
: "${S3_PREFIX:=backups/mysql}"
: "${AWS_REGION:=ap-northeast-2}"
: "${BACKUP_INTERVAL:=86400}" # 초 단위 (기본 24h)

require() { [ -n "${!1:-}" ] || { echo "[backup] 필수 env '$1' 누락" >&2; exit 1; }; }
require DB_PASSWORD
require DB_NAME
require S3_BUCKET

# 비밀번호를 argv(프로세스 목록)에 노출하지 않도록 MYSQL_PWD 사용
export MYSQL_PWD="$DB_PASSWORD"

dump_once() {
  local ts key
  ts="$(date +%Y%m%d-%H%M%S)"
  key="s3://${S3_BUCKET}/${S3_PREFIX%/}/${DB_NAME}/${DB_NAME}-${ts}.sql.gz"

  echo "[backup] $(date -Is) dump '${DB_NAME}' -> ${key}"
  # --single-transaction: InnoDB 를 락 없이 일관성 있게 덤프
  # 파이프 중간 실패도 감지하도록 pipefail(set -o) 에 의존
  mysqldump \
      --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
      --single-transaction --quick --routines --triggers --events \
      --no-tablespaces \
      "$DB_NAME" \
    | gzip -c \
    | aws s3 cp - "$key" --region "$AWS_REGION" --only-show-errors

  echo "[backup] $(date -Is) done ${key}"
}

echo "[backup] start: interval=${BACKUP_INTERVAL}s target=s3://${S3_BUCKET}/${S3_PREFIX}"
while true; do
  if ! dump_once; then
    echo "[backup] $(date -Is) FAILED — 다음 주기에 재시도" >&2
  fi
  sleep "$BACKUP_INTERVAL"
done
