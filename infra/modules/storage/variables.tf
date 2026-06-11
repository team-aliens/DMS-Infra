variable "bucket_name" {
  description = "S3 버킷 이름 (전역 유일)"
  type        = string
}

variable "versioning" {
  description = "버전 관리 활성화 여부"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "버킷에 객체가 있어도 destroy 허용할지 (운영은 false 권장)"
  type        = bool
  default     = false
}

variable "backup_prefix" {
  description = "백업 객체 prefix. 이 prefix 하위에 수명주기(만료) 규칙을 적용. 빈 문자열이면 규칙 비활성"
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "백업 객체 보관 일수. 이후 자동 삭제. 0이면 만료 안 함"
  type        = number
  default     = 30
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
