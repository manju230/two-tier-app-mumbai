variable "vpc_name" {
  type    = string
  default = "two-tier-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "public_subnet" {
  type    = string
  default = "public_subnet"
}

variable "private_subnet" {
  type    = string
  default = "private_subnet"
}