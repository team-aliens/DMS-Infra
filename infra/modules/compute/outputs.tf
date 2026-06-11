output "id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "primary_network_interface_id" {
  description = "게이트웨이를 NAT 인스턴스로 쓸 때 프라이빗 라우트 타깃"
  value       = aws_instance.this.primary_network_interface_id
}

output "availability_zone" {
  value = aws_instance.this.availability_zone
}
