locals {
  name = "iac-demo-${var.environment}"
  tags = {
    Environment = var.environment
    Project     = "terraform-iac-aws"
    ManagedBy   = "terraform"
    Owner       = "nagasrinath"
  }
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source               = "../../modules/vpc"
  name                 = local.name
  cidr_block           = var.vpc_cidr
  public_subnet_cidrs  = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1)]
  private_subnet_cidrs = [cidrsubnet(var.vpc_cidr, 8, 10), cidrsubnet(var.vpc_cidr, 8, 11)]
  tags                 = local.tags
}

module "s3" {
  source      = "../../modules/s3"
  bucket_name = "${local.name}-${data.aws_caller_identity.current.account_id}"
  tags        = local.tags
}

module "ecs" {
  source     = "../../modules/ecs-fargate"
  name       = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  tags       = local.tags
}

module "rds" {
  source                     = "../../modules/rds"
  identifier                 = local.name
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.ecs.security_group_id]
  tags                       = local.tags
}
