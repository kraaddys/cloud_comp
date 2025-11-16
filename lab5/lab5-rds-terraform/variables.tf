variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Common project name prefix"
  type        = string
  default     = "project"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name"
  type        = string
  default     = "lab5-key" # тут имя твоего key pair
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}