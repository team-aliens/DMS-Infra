variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "프로젝트 이름 (태그/이름 접두사)"
  type        = string
  default     = "dms"
}

variable "environment" {
  description = "환경 이름"
  type        = string
  default     = "prod"
}

variable "ami_id" {
  description = "EC2 AMI ID. null이면 최신 Ubuntu 22.04를 자동 조회. LocalStack 등에서는 더미 값 주입"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24"]
}

variable "key_name" {
  description = "EC2 SSH 키페어 이름 (사전에 AWS에 생성/임포트)"
  type        = string
}

variable "admin_cidrs" {
  description = "SSH / 모니터링 UI 접근을 허용할 관리자 IP CIDR 목록 (예: [\"1.2.3.4/32\"])"
  type        = list(string)
  default     = []
}

variable "s3_bucket_name" {
  description = "파일 업로드용 S3 버킷 이름 (전역 유일해야 함). DB 백업도 이 버킷의 backups/ prefix에 저장"
  type        = string
}

variable "backup_retention_days" {
  description = "S3 backups/ prefix의 백업 객체 보관 일수 (이후 자동 삭제). 0이면 만료 안 함"
  type        = number
  default     = 30
}

variable "instance_type_gateway" {
  type    = string
  default = "t3.small"
}

variable "instance_type_main" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_notification" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_infra" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_monitoring" {
  type    = string
  default = "t3.medium"
}

variable "root_volume_size_gateway" {
  type    = number
  default = 10
}

variable "root_volume_size_app" {
  type    = number
  default = 10
}

variable "root_volume_size_infra" {
  description = "Infra 인스턴스 루트 EBS 크기(GB). OS+도커이미지+DB데이터를 함께 담음"
  type        = number
  default     = 30
}
