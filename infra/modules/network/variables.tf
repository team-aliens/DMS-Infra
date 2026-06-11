variable "name_prefix" {
  description = "리소스 이름 접두사 (예: dms-prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "azs" {
  description = "사용할 가용영역 목록 (서브넷 인덱스 순서대로 매핑)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "관리형 NAT Gateway 생성 여부. false면 프라이빗 서브넷 기본 라우트는 호출 측(루트 모듈)에서 게이트웨이 인스턴스로 연결"
  type        = bool
  default     = false
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
