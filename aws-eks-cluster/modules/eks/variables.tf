variable "cluster-name" {
  type = string
}

variable "subnet-ids" {
  type = list(string)
}

variable "min-size" {
  type = number
}

variable "max-size" {
  type = number
}

variable "instance-types" {
  type = list(string)
  default = ["t3.medium"]
}