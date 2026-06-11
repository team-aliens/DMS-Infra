output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_route_table_id" {
  description = "게이트웨이 인스턴스를 NAT로 쓸 때 루트 모듈이 라우트를 추가할 대상"
  value       = length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}
