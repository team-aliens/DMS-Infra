locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  ami_id      = data.aws_ami.ubuntu.id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
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
  backup_prefix         = "backups"
  backup_retention_days = var.backup_retention_days
  tags                  = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = [
    "dms-gateway",
    "dms-main",
    "dms-notification",
  ]
  tags = local.common_tags
}

module "iam_app" {
  source = "../../modules/iam"

  name            = "${local.name_prefix}-app"
  enable_s3       = true
  s3_bucket_arn   = module.s3.bucket_arn
  enable_ecr_read = true
  tags            = local.common_tags
}

module "iam_base" {
  source = "../../modules/iam"

  name            = "${local.name_prefix}-base"
  enable_ecr_read = true 
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

module "gateway" {
  source = "../../modules/compute"

  name                = "${local.name_prefix}-gateway"
  ami_id              = local.ami_id
  instance_type       = var.instance_type_gateway
  subnet_id           = module.network.public_subnet_id
  security_group_ids  = [module.security.gateway_sg_id]
  key_name            = var.key_name
  associate_public_ip = true
  source_dest_check   = false
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_gateway
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "gateway", gateway_ip = "" })
  tags                 = local.common_tags
}

resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = module.gateway.id
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-gateway-eip" })
}

resource "aws_route" "private_via_gateway" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.gateway.primary_network_interface_id
}

module "main" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-main"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_main
  subnet_id            = module.network.private_subnet_id
  security_group_ids   = [module.security.main_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_app.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "main", gateway_ip = module.gateway.private_ip })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}

module "notification" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-notification"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_notification
  subnet_id            = module.network.private_subnet_id
  security_group_ids   = [module.security.notification_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "notification", gateway_ip = module.gateway.private_ip })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}

module "infra" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-infra"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_infra
  subnet_id            = module.network.private_subnet_id
  security_group_ids   = [module.security.infra_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_infra.instance_profile_name
  root_volume_size     = var.root_volume_size_infra
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "infra", gateway_ip = module.gateway.private_ip })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}

module "monitoring" {
  source = "../../modules/compute"

  name                 = "${local.name_prefix}-monitoring"
  ami_id               = local.ami_id
  instance_type        = var.instance_type_monitoring
  subnet_id            = module.network.private_subnet_id
  security_group_ids   = [module.security.monitoring_sg_id]
  key_name             = var.key_name
  iam_instance_profile = module.iam_base.instance_profile_name
  root_volume_size     = var.root_volume_size_app
  user_data            = templatefile("${path.module}/templates/bootstrap.sh.tftpl", { role = "monitoring", gateway_ip = module.gateway.private_ip })
  tags                 = local.common_tags

  depends_on = [aws_route.private_via_gateway]
}
