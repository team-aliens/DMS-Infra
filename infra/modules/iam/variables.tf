variable "name" {
  description = "역할/프로파일 이름 (예: dms-prod-app)"
  type        = string
}

variable "enable_s3" {
  description = "S3 접근 정책을 추가할지 여부 (count 조건은 정적이어야 하므로 ARN과 분리)"
  type        = bool
  default     = false
}

variable "enable_ecr_read" {
  description = "ECR pull 권한(AmazonEC2ContainerRegistryReadOnly) 추가 여부. CD 이미지를 받는 인스턴스에 필요"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "접근을 허용할 S3 버킷 ARN. enable_s3 = true 일 때 사용"
  type        = string
  default     = null
}

variable "s3_prefix" {
  description = "S3 접근을 특정 prefix로 제한 (예: \"backups\"). null이면 버킷 전체 허용"
  type        = string
  default     = null
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
