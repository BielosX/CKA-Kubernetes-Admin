module "vpc" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
  name   = "eks-cluster-vpc"
  private-subnets = 2
  public-subnets = 2
  single-nat-gateway = true
  subnet-size = 256
  private-subnets-tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "shared",
    "kubernetes.io/role/internal-elb": 1
  }
  public-subnets-tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "shared",
    "kubernetes.io/role/elb": 1
  }
}

module "ebs" {
  source = "./modules/ebs"
  availability-zone = module.vpc.private-subnets-azs[0]
  name = "eks-persistent-volume"
}

module "eks" {
  source = "./modules/eks"
  cluster-name = var.cluster-name
  max-size = 4
  min-size = 2
  subnet-ids = module.vpc.private-subnet-ids
}

module "iam" {
  source = "./modules/iam"
  cluster-name = var.cluster-name
  oidc-arn = module.eks.oidc-arn
  oidc-id = module.eks.oidc-id
}

module "nginx" {
  source = "./modules/nginx"
  subnet-id = module.vpc.private-subnet-ids[0]
  vpc-id = module.vpc.vpc-id
}