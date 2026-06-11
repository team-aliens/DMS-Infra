output "gateway_sg_id" {
  value = aws_security_group.gateway.id
}

output "main_sg_id" {
  value = aws_security_group.main.id
}

output "notification_sg_id" {
  value = aws_security_group.notification.id
}

output "infra_sg_id" {
  value = aws_security_group.infra.id
}

output "monitoring_sg_id" {
  value = aws_security_group.monitoring.id
}
