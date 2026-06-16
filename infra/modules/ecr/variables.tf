variable "repositories" {
  description = "생성할 ECR 레포 이름 목록 (서비스별)"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "이미지 태그 변경 허용 여부. CD가 :latest 를 덮어쓰므로 MUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "푸시 시 취약점 스캔 수행"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "이미지가 남아 있어도 레포 삭제 허용 (운영은 false 권장)"
  type        = bool
  default     = false
}

variable "keep_last_images" {
  description = "태그된 이미지 보관 개수. 초과분은 오래된 순으로 자동 삭제"
  type        = number
  default     = 10
}

variable "untagged_expire_days" {
  description = "태그 없는(dangling) 이미지 만료 일수"
  type        = number
  default     = 7
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
