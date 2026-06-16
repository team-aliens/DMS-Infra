output "vpc_id" {
  value = module.network.vpc_id
}

output "gateway_public_ip" {
  description = "게이트웨이 고정 공인 IP (EIP). DNS A 레코드를 여기로"
  value       = aws_eip.gateway.public_ip
}

output "gateway_private_ip" {
  value = module.gateway.private_ip
}

output "main_private_ip" {
  value = module.main.private_ip
}

output "notification_private_ip" {
  value = module.notification.private_ip
}

output "infra_private_ip" {
  description = "MySQL/Redis/RabbitMQ 호스트. 앱의 *_HOST 환경변수로 사용"
  value       = module.infra.private_ip
}

output "monitoring_private_ip" {
  value = module.monitoring.private_ip
}

output "s3_bucket" {
  value = module.s3.bucket_id
}

output "ecr_repository_urls" {
  description = "서비스별 ECR 레포 URL (CD push 대상)"
  value       = module.ecr.repository_urls
}

output "ssm_access_hint" {
  description = "프라이빗 인스턴스 접속 방법"
  value       = "aws ssm start-session --target <instance-id>  (SSH 없이 접속 가능)"
}
