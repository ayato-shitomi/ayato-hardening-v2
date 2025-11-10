output "bastion_public_ip" {
  description = "Public IP address of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of bastion host"
  value       = aws_instance.bastion.private_ip
}

output "internal_instance_ips" {
  description = "Private IP addresses of internal instances"
  value = {
    for idx, instance in aws_instance.internal :
    "${var.project_name}-internal-${idx + 1}" => instance.private_ip
  }
}

output "scoreboard_instance_ip" {
  description = "Private IP address of scoreboard/attack server"
  value       = aws_instance.scoreboard.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.hardening_vpc.id
}

output "ssh_connection_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh ubuntu@${aws_instance.bastion.public_ip}"
}

output "internal_instance_ids" {
  description = "Instance IDs of internal instances (for snapshot creation)"
  value       = aws_instance.internal[*].id
}

output "all_instance_info" {
  description = "All instance information"
  value = {
    bastion = {
      id         = aws_instance.bastion.id
      public_ip  = aws_instance.bastion.public_ip
      private_ip = aws_instance.bastion.private_ip
    }
    internal_instances = {
      for idx, instance in aws_instance.internal :
      "internal-${idx + 1}" => {
        id         = instance.id
        private_ip = instance.private_ip
      }
    }
    scoreboard = {
      id         = aws_instance.scoreboard.id
      private_ip = aws_instance.scoreboard.private_ip
    }
  }
}
