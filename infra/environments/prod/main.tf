locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # ami_id 가 지정되면 그 값을, 아니면 아래 데이터소스 조회 결과를 사용
  # (LocalStack 등에서는 더미 AMI를 변수로 주입)
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
}

# 최신 Ubuntu 22.04 LTS (amd64) AMI
data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# 네트워크 / 보안 / 스토리지
# ============================================================
module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  tags                 = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  vpc_cidr    = module.network.vpc_cidr
  admin_cidrs = var.admin_cidrs
  tags        = local.common_tags
}

module "s3" {
  source = "../../modules/storage"

  bucket_name = var.s3_bucket_name
  # DB 백업은 backups/ prefix 하위에 저장하고 일정 기간 뒤 자동 만료
  backup_prefix         = "backups"
  backup_retention_days = var.backup_retention_days
  tags                  = local.common_tags
}

# ============================================================
# ECR (CD 가 빌드한 서비스 이미지를 push/pull)
# ============================================================
module "ecr" {
  source = "../../modules/ecr"

  repositories = [
    "dms-gateway",
    "dms-main",
    "dms-notification",
  ]
  tags = local.common_tags
}

# ============================================================
# IAM 인스턴스 프로파일
#  - app : SSM + S3 (Main 전용)
#  - base: SSM 만 (게이트웨이/노티/인프라/모니터링)
# ============================================================
module "iam_app" {
  source = "../../modules/iam"

  name            = "${local.name_prefix}-app"
  enable_s3       = true
  s3_bucket_arn   = module.s3.bucket_arn
  enable_ecr_read = true # main: ECR 이미지 pull
  tags            = local.common_tags
}

module "iam_base" {
  source = "../../modules/iam"

  name            = "${local.name_prefix}-base"
  enable_ecr_read = true # gateway/notification/monitoring: ECR pull
  tags            = local.common_tags
}

# infra : SSM + S3(backups/ prefix 한정) — DB 덤프 업로드용
module "iam_infra" {
  source = "../../modules/iam"

  name          = "${local.name_prefix}-infra"
  enable_s3     = true
  s3_bucket_arn = module.s3.bucket_arn
  s3_prefix     = "backups"
  tags          = local.common_tags
}

# ============================================================
# Gateway (public subnet, EIP, NAT 인스턴스 겸용)
# ============================================================
module "gateway" {
  source = "../../modules/compute"

  name                = "${local.name_prefix}-gateway"
  ami_id              = local.ami_id
  instance_type       = var.instance_type_gateway
  subnet_id           = module.network.public_subnet_ids[0]
  security_group_ids  = [module.security.gateway_sg_id]
  key_name            = var.key_name
  associate_public_ip = true
  # NAT 인스턴스로 동작하려면 Source/Dest 체크를 꺼야 한다
  source_dest_check    = var.enable_nat_gateway ? true : false
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_gateway
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "gateway" })
  tags                 = local.common_tags
}

resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = module.gateway.id
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-gateway-eip" })
}

# 관리형 NAT를 안 쓰는 경우, 프라이빗 서브넷의 기본 라우트를 게이트웨이 ENI로
resource "aws_route" "private_via_gateway" {
  count = var.enable_nat_gateway ? 0 : 1

  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.gateway.primary_network_interface_id
}

# ============================================================
# Main (private) - S3 접근 필요 -> iam_app
# ============================================================
module "main" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-main"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_main
  subnet_id            = module.network.private_subnet_ids
  security_group_ids   = [module.security.main_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_app.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "main" })
  tags                 = local.common_tags

  # NAT 경로(게이트웨이 라우트)가 준비된 뒤 부팅되도록
  depends_on = [aws_route.private_via_gateway]
}

# ============================================================
# Notification (private)
# ============================================================
module "notification" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-notification"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_notification
  subnet_id            = module.network.private_subnet_ids[0]
  security_group_ids   = [module.security.notification_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "notification" })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}

# ============================================================
# Infra (private) - MySQL / Redis / RabbitMQ + S3 주기 백업
#   데이터는 루트 볼륨에 두고, DB 덤프를 주기적으로 S3(backups/)에 업로드.
#   -> S3 업로드 권한이 필요하므로 iam_infra 프로파일 사용.
# ============================================================
module "infra" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-infra"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_infra
  subnet_id            = module.network.private_subnet_ids[0]
  security_group_ids   = [module.security.infra_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_infra.instance_profile_name
  root_volume_size     = var.root_volume_size_infra
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "infra" })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}

# ============================================================
# Monitoring (private) - Prometheus / Grafana
# ============================================================
module "monitoring" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-monitoring"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_monitoring
  subnet_id            = module.network.private_subnet_ids[0]
  security_group_ids   = [module.security.monitoring_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "monitoring" })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}
