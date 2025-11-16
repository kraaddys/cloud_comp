output "web_ec2_public_ip" {
  description = "Public IP of web EC2 instance"
  value       = aws_instance.web_ec2.public_ip
}