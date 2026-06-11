variable "name" {
  description = "인스턴스 이름 (예: dms-prod-main)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID"
  type        = string
}

variable "instance_type" {
  description = "인스턴스 타입 (예: t3.medium)"
  type        = string
}

variable "subnet_id" {
  description = "배치할 서브넷 ID"
  type        = string
}

variable "security_group_ids" {
  description = "연결할 보안그룹 ID 목록"
  type        = list(string)
}

variable "key_name" {
  description = "SSH 키페어 이름"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "퍼블릭 IP 자동 할당 여부"
  type        = bool
  default     = false
}

variable "source_dest_check" {
  description = "Source/Destination 체크. NAT 인스턴스로 쓸 게이트웨이는 false"
  type        = bool
  default     = true
}

variable "iam_instance_profile" {
  description = "연결할 IAM 인스턴스 프로파일 이름"
  type        = string
  default     = null
}

variable "user_data" {
  description = "부트스트랩 스크립트"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "루트 EBS 크기(GB)"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "루트 EBS 타입"
  type        = string
  default     = "gp3"
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
