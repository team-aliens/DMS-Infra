variable "name_prefix" {
  description = "리소스 이름 접두사 (예: dms-prod)"
  type        = string
}

variable "vpc_id" {
  description = "보안그룹을 생성할 VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (NAT 반환 트래픽/내부 통신 허용용)"
  type        = string
}

variable "admin_cidrs" {
  description = "SSH/모니터링 UI 접근을 허용할 관리자 IP CIDR 목록"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
