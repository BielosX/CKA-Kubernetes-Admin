variable "cidr" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "public-subnets-tags" {
  type = map(string)
  default = {}
}

variable "private-subnets-tags" {
  type = map(string)
  default = {}
}

variable "name" {
  type = string
}

variable "public-subnets" {
  type = number
}

variable "private-subnets" {
  type = number
}

variable "subnet-size" {
  type = number
}

variable "availability-zones" {
  type = list(string)
  default = []
}

variable "single-nat-gateway" {
  type = bool
}