

output "instance_public_ip" {
  description = "Public IP of the deployed EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS hostname of the EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "instance_id" {
  description = "AWS Instance ID"
  value       = aws_instance.app_server.id
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app_sg.id
}

output "ssh_command" {
  description = "Ready-to-use SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.app_server.public_ip}"
}
