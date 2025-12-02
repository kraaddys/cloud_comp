variable "vpc_id" {
  description = "ID of project-lab6-vpc"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for ASG"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID created from lab6-webserver"
  type        = string
}

variable "instance_sg_id" {
  description = "Security group ID for web instances (lab6-security-group)"
  type        = string
}