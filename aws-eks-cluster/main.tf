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

module "nginx" {
  source = "./modules/nginx"
  subnet-id = module.vpc.private-subnet-ids[0]
  vpc-id = module.vpc.vpc-id
  private-ip = cidrhost(module.vpc.private-subnets-cidrs[0], 53)
}

module "bind-dns" {
  depends_on = [module.nginx]
  source = "./modules/bind-dns"
  subnet-id = module.vpc.private-subnet-ids[0]
  vpc-id = module.vpc.vpc-id
  private-ip = cidrhost(module.vpc.private-subnets-cidrs[0], 54)
}

module "ebs" {
  source = "./modules/ebs"
  availability-zone = module.vpc.private-subnets-azs[0]
  name = "eks-persistent-volume"
}

module "eks" {
  depends_on = [module.nginx, module.bind-dns]
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

module "self-managed-nodes" {
  source = "./modules/self-managed-nodes"
  cluster-name = module.eks.cluster-name
  kubernetes-version = "1.24"
  max-size = 4
  min-size = 2
  name = "self-managed-nodes"
  subnet-ids = module.vpc.private-subnet-ids
  instance-type = "t3.medium"
  vpc-id = module.vpc.vpc-id
  cluster-security-group-id = module.eks.cluster-security-group-id
}

module "control-plane-sg-rules" {
  source = "./modules/control-plane-sg-rules"
  cluster-security-group-id = module.eks.cluster-security-group-id
  self-managed-nodes-security-group-id = module.self-managed-nodes.security-group-id
}
