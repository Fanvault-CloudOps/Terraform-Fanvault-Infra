# -----------------------------------------------------------------------------
# ROOT MAIN.TF — FanVault v2 Infrastructure Provisioning
# -----------------------------------------------------------------------------

# 1. VPC Module
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
}

# 2. Security Module
module "security" {
  source       = "./modules/security"
  vpc_id       = module.vpc.vpc_id
  admin_ssh_ip = var.admin_ssh_ip
  project_name = var.project_name
  environment  = var.environment
}

# 3. IAM Module
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

# 4. S3 & Lambda Module
module "s3_lambda" {
  source          = "./modules/s3_lambda"
  lambda_role_arn = module.iam.lambda_role_arn
  project_name    = var.project_name
  environment     = var.environment
}

# 5. DNS Module (Route53 Private Zone mapping db.fanvault.internal)
module "dns" {
  source             = "./modules/dns"
  vpc_id             = module.vpc.vpc_id
  mongodb_private_ip = module.compute.mongodb_private_ip
  project_name       = var.project_name
  environment        = var.environment
}

# 6. Compute Module (Bastion, MongoDB, ALB, Target Groups, Launch Templates, ASGs)
module "compute" {
  source                   = "./modules/compute"
  vpc_id                   = module.vpc.vpc_id
  public_subnets           = module.vpc.public_subnets
  frontend_private_subnets = module.vpc.frontend_private_subnets
  backend_private_subnets  = module.vpc.backend_private_subnets
  database_private_subnets = module.vpc.database_private_subnets
  alb_sg_id                = module.security.alb_sg_id
  frontend_sg_id           = module.security.frontend_sg_id
  backend_sg_id            = module.security.backend_sg_id
  db_sg_id                 = module.security.db_sg_id
  bastion_sg_id            = module.security.bastion_sg_id
  lambda_function_arn      = module.s3_lambda.lambda_function_arn
  lambda_function_name     = module.s3_lambda.lambda_function_name
  key_name                 = var.key_name
  project_name             = var.project_name
  environment              = var.environment
}
