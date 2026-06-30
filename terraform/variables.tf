variable "container_image" {
  type    = string
  default = "eladpress/cloudride-assignment:main-1"
}

variable "environment" {
  description = "Environment tag applied to all resources."
  type        = string
  default     = "Lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}