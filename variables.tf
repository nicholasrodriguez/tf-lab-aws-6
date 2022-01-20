variable "aws_region" {
  description = "The AWS region your resources will be deployed"
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type."
  type        = string
}

variable "admin_public_ip" {
  description = "CIDR block for the subnet"
  type        = string
}
