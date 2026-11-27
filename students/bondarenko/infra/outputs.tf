output "instance_id" {
  description = "EC2 instance ID used to check the host key through AWS."
  value       = aws_instance.web.id
}

output "instance_ip" {
  description = "Public IPv4 address used for SSH and HTTP."
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  description = "Security group ID used to verify cleanup."
  value       = aws_security_group.web.id
}
