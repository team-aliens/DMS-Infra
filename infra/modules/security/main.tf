locals {
  port_http      = 80
  port_https     = 443
  port_ssh       = 22
  port_main      = 8081
  port_noti      = 8082
  port_mysql      = 3306
  port_mysql_noti = 3307
  port_redis     = 6379
  port_rabbitmq  = 5672
  port_rabbit_ui = 15672
  port_grafana   = 3000
  port_prom      = 9090
  port_node_exp  = 9100 # node_exporter
}

resource "aws_security_group" "gateway" {
  name        = "${var.name_prefix}-gateway-sg"
  description = "Gateway/Nginx - public facing"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-gateway-sg" })
}

resource "aws_security_group" "main" {
  name        = "${var.name_prefix}-main-sg"
  description = "dms-main application"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-main-sg" })
}

resource "aws_security_group" "notification" {
  name        = "${var.name_prefix}-notification-sg"
  description = "dms-notification application"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-notification-sg" })
}

resource "aws_security_group" "infra" {
  name        = "${var.name_prefix}-infra-sg"
  description = "MySQL / Redis / RabbitMQ host"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-infra-sg" })
}

resource "aws_security_group" "monitoring" {
  name        = "${var.name_prefix}-monitoring-sg"
  description = "Prometheus / Grafana"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-monitoring-sg" })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = {
    gateway      = aws_security_group.gateway.id
    main         = aws_security_group.main.id
    notification = aws_security_group.notification.id
    infra        = aws_security_group.infra.id
    monitoring   = aws_security_group.monitoring.id
  }

  security_group_id = each.value
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "allow all egress"
}

resource "aws_vpc_security_group_ingress_rule" "gw_http" {
  security_group_id = aws_security_group.gateway.id
  ip_protocol       = "tcp"
  from_port         = local.port_http
  to_port           = local.port_http
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTP from internet"
}

resource "aws_vpc_security_group_ingress_rule" "gw_https" {
  security_group_id = aws_security_group.gateway.id
  ip_protocol       = "tcp"
  from_port         = local.port_https
  to_port           = local.port_https
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS from internet"
}

resource "aws_vpc_security_group_ingress_rule" "gw_ssh" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.gateway.id
  ip_protocol       = "tcp"
  from_port         = local.port_ssh
  to_port           = local.port_ssh
  cidr_ipv4         = each.value
  description       = "SSH from admin"
}

resource "aws_vpc_security_group_ingress_rule" "gw_from_vpc" {
  security_group_id = aws_security_group.gateway.id
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
  description       = "internal/NAT traffic from VPC"
}

resource "aws_vpc_security_group_ingress_rule" "main_app" {
  security_group_id            = aws_security_group.main.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_main
  to_port                      = local.port_main
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "app port from gateway"
}

resource "aws_vpc_security_group_ingress_rule" "main_node_exp" {
  security_group_id            = aws_security_group.main.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_node_exp
  to_port                      = local.port_node_exp
  referenced_security_group_id = aws_security_group.monitoring.id
  description                  = "node_exporter scrape"
}

resource "aws_vpc_security_group_ingress_rule" "main_ssh" {
  security_group_id            = aws_security_group.main.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_ssh
  to_port                      = local.port_ssh
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "SSH via gateway (bastion)"
}

resource "aws_vpc_security_group_ingress_rule" "noti_app" {
  security_group_id            = aws_security_group.notification.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_noti
  to_port                      = local.port_noti
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "app port from gateway"
}

resource "aws_vpc_security_group_ingress_rule" "noti_node_exp" {
  security_group_id            = aws_security_group.notification.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_node_exp
  to_port                      = local.port_node_exp
  referenced_security_group_id = aws_security_group.monitoring.id
  description                  = "node_exporter scrape"
}

resource "aws_vpc_security_group_ingress_rule" "noti_ssh" {
  security_group_id            = aws_security_group.notification.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_ssh
  to_port                      = local.port_ssh
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "SSH via gateway (bastion)"
}

locals {
  infra_clients = {
    main = aws_security_group.main.id
    noti = aws_security_group.notification.id
  }
  infra_ports = {
    mysql      = local.port_mysql
    mysql_noti = local.port_mysql_noti
    redis      = local.port_redis
    rabbitmq   = local.port_rabbitmq
  }
  # (client, port) 조합 펼치기
  infra_rules = {
    for pair in setproduct(keys(local.infra_clients), keys(local.infra_ports)) :
    "${pair[0]}-${pair[1]}" => {
      sg_id = local.infra_clients[pair[0]]
      port  = local.infra_ports[pair[1]]
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "infra_data" {
  for_each = local.infra_rules

  security_group_id            = aws_security_group.infra.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = each.value.sg_id
  description                  = "data store access"
}

# RabbitMQ 관리 UI(15672)는 관리자 CIDR에서만
resource "aws_vpc_security_group_ingress_rule" "infra_rabbit_ui" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.infra.id
  ip_protocol       = "tcp"
  from_port         = local.port_rabbit_ui
  to_port           = local.port_rabbit_ui
  cidr_ipv4         = each.value
  description       = "RabbitMQ management UI from admin"
}

resource "aws_vpc_security_group_ingress_rule" "infra_node_exp" {
  security_group_id            = aws_security_group.infra.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_node_exp
  to_port                      = local.port_node_exp
  referenced_security_group_id = aws_security_group.monitoring.id
  description                  = "node_exporter scrape"
}

resource "aws_vpc_security_group_ingress_rule" "infra_ssh" {
  security_group_id            = aws_security_group.infra.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_ssh
  to_port                      = local.port_ssh
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "SSH via gateway (bastion)"
}

resource "aws_vpc_security_group_ingress_rule" "mon_grafana_gw" {
  security_group_id            = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_grafana
  to_port                      = local.port_grafana
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "Grafana via gateway reverse proxy"
}

resource "aws_vpc_security_group_ingress_rule" "mon_grafana_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.monitoring.id
  ip_protocol       = "tcp"
  from_port         = local.port_grafana
  to_port           = local.port_grafana
  cidr_ipv4         = each.value
  description       = "Grafana from admin"
}

resource "aws_vpc_security_group_ingress_rule" "mon_prom_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.monitoring.id
  ip_protocol       = "tcp"
  from_port         = local.port_prom
  to_port           = local.port_prom
  cidr_ipv4         = each.value
  description       = "Prometheus from admin"
}

resource "aws_vpc_security_group_ingress_rule" "mon_ssh" {
  security_group_id            = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = local.port_ssh
  to_port                      = local.port_ssh
  referenced_security_group_id = aws_security_group.gateway.id
  description                  = "SSH via gateway (bastion)"
}
