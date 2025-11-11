variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hardening-exercise"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "ap-northeast-1a"
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.medium"
}

variable "internal_instance_type" {
  description = "Instance type for internal instances"
  type        = string
  default     = "t3.small"
}

variable "internal_instance_count" {
  description = "Number of internal instances"
  type        = number
  default     = 9

  validation {
    condition     = var.internal_instance_count >= 1 && var.internal_instance_count <= 10
    error_message = "internal_instance_count must be between 1 and 10"
  }
}

variable "default_password" {
  description = "Default password for ubuntu user (change after deployment)"
  type        = string
  sensitive   = true
}

variable "init_script_url" {
  description = "URL to the initialization script in public Git repository"
  type        = string
}
