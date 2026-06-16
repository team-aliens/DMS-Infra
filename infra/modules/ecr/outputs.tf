output "repository_urls" {
  description = "레포 이름 -> 레포 URL 맵 (CD 가 push 하는 대상)"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "레포 이름 -> ARN 맵"
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}
