terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------
# VPC + subnets + routing
# -----------------------------

resource "aws_vpc" "project_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public subnets

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public1-${var.aws_region}a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public2-${var.aws_region}b"
  }
}

# Private subnets

resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-subnet-private1-${var.aws_region}a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-subnet-private2-${var.aws_region}b"
  }
}

# Route tables

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-rtb-public"
  }
}

resource "aws_route_table_association" "public_1a_assoc" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_1b_assoc" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT gateway для приватных подсетей

resource "aws_eip" "nat_eip" {
  vpc = true

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-rtb-private"
  }
}

resource "aws_route_table_association" "private_1a_assoc" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_1b_assoc" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_rt.id
}

# -----------------------------
# Security Groups
# -----------------------------

# Web SG (EC2)
resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Allow HTTP/SSH from world"
  vpc_id      = aws_vpc.project_vpc.id

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH from anywhere (для учебных целей)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Общий исходящий трафик (обновления пакетов и т.д.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

# DB SG (RDS)
resource "aws_security_group" "db_sg" {
  name        = "db-mysql-security-group"
  description = "Allow MySQL from web-security-group"
  vpc_id      = aws_vpc.project_vpc.id

  # Входящий MySQL только от web_sg
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # Исходящий трафик куда угодно (по умолчанию)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-mysql-security-group"
  }
}

# Отдельное правило egress MySQL из web_sg к db_sg,
# чтобы не создавать цикл зависимостей
resource "aws_vpc_security_group_egress_rule" "web_to_db_mysql" {
  security_group_id           = aws_security_group.web_sg.id
  from_port                   = 3306
  to_port                     = 3306
  ip_protocol                 = "tcp"
  referenced_security_group_id = aws_security_group.db_sg.id
}

# -----------------------------
# EC2 instance (web)
# -----------------------------

# Amazon Linux 2023 ECS-optimized (как у тебя сейчас)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-x86_64"]
  }
}

resource "aws_instance" "web_ec2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public_1a.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              dnf -y update
              dnf install -y httpd php php-mysqlnd mariadb105
              systemctl enable --now httpd
              EOF

  tags = {
    Name = "${var.project_name}-web-ec2"
  }
}