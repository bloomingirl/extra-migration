data "aws_caller_identity" "current" {}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  assign_generated_ipv6_cidr_block = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "extra-migration-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "extra-migration-${var.environment}-igw"
  }
}

resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "extra-migration-${var.environment}-eigw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  ipv6_cidr_block = cidrsubnet(
    aws_vpc.this.ipv6_cidr_block,
    8,
    count.index
  )

  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true

  tags = {
    Name = "extra-migration-${var.environment}-public-${count.index + 1}"

    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  ipv6_cidr_block = cidrsubnet(
    aws_vpc.this.ipv6_cidr_block,
    8,
    count.index + 3
  )

  assign_ipv6_address_on_creation = true

  tags = {
    Name = "extra-migration-${var.environment}-private-${count.index + 1}"

    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "extra-migration-${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"

  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route" "public_ipv6" {
  route_table_id = aws_route_table.public.id

  destination_ipv6_cidr_block = "::/0"

  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "extra-migration-${var.environment}-private-rt"
  }
}

resource "aws_route" "private_ipv6" {
  route_table_id = aws_route_table.private.id

  destination_ipv6_cidr_block = "::/0"

  egress_only_gateway_id = aws_egress_only_internet_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "extra-migration-${var.environment}-vpc-endpoints"
  description = "VPC interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
    ipv6_cidr_blocks = [aws_vpc.this.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "extra-migration-${var.environment}-vpc-endpoints"
  }
}

# Interface endpoints — dualstack only
# ec2 endpoint intentionally excluded: us-east-1 ec2 endpoint supports ipv4 only,
# and IPv6-only pods reach EC2 API via the Egress-Only IGW instead.
locals {
  dualstack_endpoints = toset([
    "ecr.api",
    "ecr.dkr",
    "sts",
    "eks",
    "ssm",
    "sqs",
  ])
}

resource "aws_vpc_endpoint" "interface_dualstack" {
  for_each = local.dualstack_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.us-east-1.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  ip_address_type     = "dualstack"

  tags = {
    Name = "extra-migration-${var.environment}-${each.key}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "extra-migration-${var.environment}-s3"
  }
}

