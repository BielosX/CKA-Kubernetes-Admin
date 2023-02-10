variable "max-size" {
  type = number
}

variable "min-size" {
  type = number
}

variable "instance-type" {
  default = "t3.medium"
}

variable "kubernetes-version" {
  type = string
}

variable "cluster-name" {
  type = string
}

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "subnet-ids" {
  type = list(string)
}

variable "vpc-id" {
  type = string
}

variable "cluster-security-group-id" {
  type = string
}

variable "labels" {
  type = map(string)
  default = {}
}

variable "taints" {
  type = list(object({key=string, value=string, effect=string}))
  default = []
}