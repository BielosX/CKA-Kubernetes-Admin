variable "cluster-name" {
  type = string
}

variable "lb-subnets" {
  type = list(string)
}

variable "vpc-id" {
  type = string
}

variable "cluster-sg" {
  type = string
}