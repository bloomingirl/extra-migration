module "vpc" {
  source = "../../../modules/vpc"

  environment = "dev"

  vpc_cidr = "10.0.0.0/16"

  availability_zones = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]

  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]

  private_subnet_cidrs = [
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24"
  ]
}

module "eks" {
  source = "../../../modules/eks"

  environment = "dev"

  cluster_name = "extra-migration-dev"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  public_subnet_ids = module.vpc.public_subnet_ids

  kubernetes_version = "1.33"
}

module "karpenter" {
  source = "../../../modules/karpenter"
  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url
  subnet_ids             = module.vpc.public_subnet_ids
  node_security_group_id = module.eks.node_security_group_id
  tags = {
    Environment = "dev"
    Project     = "extra-migration"
  }
}
