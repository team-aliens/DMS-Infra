resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile

  associate_public_ip_address = var.associate_public_ip
  source_dest_check           = var.source_dest_check
  user_data                   = var.user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  # IMDSv2 강제
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # 도커 컨테이너에서 인스턴스 프로파일 크레덴셜을 받으려면 hop이 1 더 필요하다(기본 1이면 막힘)
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # user_data 변경만으로 운영 인스턴스가 교체되지 않도록.
    # 앱 배포는 CD 파이프라인이 담당.
    ignore_changes = [user_data]
  }
}
