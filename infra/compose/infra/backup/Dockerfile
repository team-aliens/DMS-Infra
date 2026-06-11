# MySQL 논리 덤프를 주기적으로 S3에 업로드하는 백업 사이드카.
#
# - mysql:8.0 베이스: 서버와 "동일 버전의 mysqldump" 를 보장한다.
#   (caching_sha2_password 등 MySQL 8 인증 플러그인 호환 문제 회피)
# - awscli v2 를 공식 zip 으로 설치한다.
# - AWS 자격증명은 EC2 인스턴스 프로파일(IMDS)에서 awscli 가 자동 획득한다.
FROM mysql:8.0

USER root

RUN microdnf install -y unzip gzip \
 && microdnf clean all \
 && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
 && unzip -q /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
