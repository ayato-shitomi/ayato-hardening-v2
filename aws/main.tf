terraform {
  required_version = ">= 1.0"
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

# VPC
resource "aws_vpc" "hardening_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hardening_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet (for bastion)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.hardening_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Private Subnet (for internal instances)
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.hardening_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway (for outbound traffic from private subnet)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.hardening_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.hardening_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Route Table Association - Public
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table Association - Private
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.hardening_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# Security Group for Internal Instances
resource "aws_security_group" "internal_sg" {
  name        = "${var.project_name}-internal-sg"
  description = "Security group for internal instances"
  vpc_id      = aws_vpc.hardening_vpc.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "HTTP from bastion"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "HTTPS from bastion"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "Flask from bastion"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "MySQL from bastion"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "All traffic from internal network"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-internal-sg"
  }
}

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# User data script for password authentication
locals {
  enable_password_auth = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== User data script started at $(date) ==="

# Set password for ubuntu user
echo "ubuntu:${var.default_password}" | chpasswd
echo "Password set for ubuntu user"

# Enable password authentication using simple method
echo -e "PasswordAuthentication yes\nKbdInteractiveAuthentication yes" | tee /etc/ssh/sshd_config.d/99-local.conf
chmod 644 /etc/ssh/sshd_config.d/99-local.conf
echo "SSH config created"

# Restart SSH service
systemctl restart ssh
systemctl restart sshd
echo "SSH service restarted"

echo "=== User data script completed at $(date) ==="
echo "Password authentication enabled at $(date)" > /var/log/userdata-completion.log
  EOF

  init_script_with_password = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== User data script started at $(date) ==="

# Set password for ubuntu user
echo "ubuntu:${var.default_password}" | chpasswd
echo "Password set for ubuntu user"

# Enable password authentication using simple method
echo -e "PasswordAuthentication yes\nKbdInteractiveAuthentication yes" | tee /etc/ssh/sshd_config.d/99-local.conf
chmod 644 /etc/ssh/sshd_config.d/99-local.conf
echo "SSH config created"

# Restart SSH service
systemctl restart ssh
systemctl restart sshd
echo "SSH service restarted"

# Download and execute init script
echo "Downloading init script from ${var.init_script_url}"
curl -fsSL ${var.init_script_url} -o /tmp/init.sh
bash /tmp/init.sh
echo "Init script executed"

echo "=== User data script completed at $(date) ==="
echo "Init script completed at $(date)" > /var/log/userdata-completion.log
  EOF

  attacker_setup_script = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Attacker setup script started at $(date) ==="

# Set password for ubuntu user
echo "ubuntu:${var.default_password}" | chpasswd
echo "Password set for ubuntu user"

# Enable password authentication using simple method
echo -e "PasswordAuthentication yes\nKbdInteractiveAuthentication yes" | tee /etc/ssh/sshd_config.d/99-local.conf
chmod 644 /etc/ssh/sshd_config.d/99-local.conf
echo "SSH config created"

# Restart SSH service
systemctl restart ssh
systemctl restart sshd
echo "SSH service restarted"

# Install dependencies
echo "Installing dependencies..."
apt update
apt install unzip python3-pip python3.12-venv -y
echo "Dependencies installed"

# Download repository
echo "Downloading repository from GitHub..."
cd /home/ubuntu
curl -OL https://github.com/ayato-shitomi/ayato-hardening-v2/archive/refs/heads/master.zip
unzip -q master.zip
echo "Repository downloaded and extracted"

# Setup Python virtual environment
echo "Setting up Python virtual environment..."
cd ayato-hardening-v2-master
python3 -m venv venv
chown -R ubuntu:ubuntu /home/ubuntu/ayato-hardening-v2-master
echo "Virtual environment created"

echo "=== Attacker setup script completed at $(date) ==="
echo "Attacker setup completed at $(date)" > /var/log/userdata-completion.log
  EOF
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  user_data = local.enable_password_auth

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# Internal Instances
resource "aws_instance" "internal" {
  count = var.internal_instance_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.internal_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.internal_sg.id]

  user_data = local.init_script_with_password

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-internal-${count.index + 1}"
  }
}

# Scoreboard/Attack Server
resource "aws_instance" "scoreboard" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.internal_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.internal_sg.id]

  user_data = local.attacker_setup_script

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-scoreboard-attack"
  }
}
