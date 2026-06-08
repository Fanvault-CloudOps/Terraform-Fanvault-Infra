# -----------------------------------------------------------------------------
# ROOT MAIN.TF — FanVault v2 Infrastructure Provisioning
# Deployment order:
#   VPC → Security → IAM → DynamoDB → SSM → S3/Lambda → DNS → Compute
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
# Creates:
#   - Lambda execution role (S3 read for architecture page)
#   - EC2 backend instance role + profile (DynamoDB + SSM + S3 + CloudWatch)
#   - EC2 frontend instance role + profile (SSM git/* + CloudWatch)
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment

  # Scope DynamoDB permissions to the exact 4 table ARNs (least privilege)
  dynamodb_table_arns = [
    module.dynamodb.table_users_arn,
    module.dynamodb.table_profiles_arn,
    module.dynamodb.table_products_arn,
    module.dynamodb.table_orders_arn,
  ]

  # SSM path prefix — IAM policy grants GetParameter on /fanvault/* only
  ssm_parameter_prefix = "/fanvault"

  # S3 name prefix — avoids circular dep with s3_lambda (which needs lambda_role from IAM)
  # Policy becomes: arn:aws:s3:::fanvault-*/* — covers any bucket created by this project
  s3_bucket_name_prefix = var.project_name

  depends_on = [module.dynamodb]
}

# 4. DynamoDB Module (Users, Profiles, Products, Orders — replaces MongoDB)
module "dynamodb" {
  source            = "./modules/dynamodb"
  project_name      = var.project_name
  environment       = var.environment
  billing_mode      = "PAY_PER_REQUEST" # On-demand — no capacity planning required
  enable_pitr       = true              # Point-in-Time Recovery for all tables
  enable_encryption = true             # AWS-owned KMS encryption at rest
}

# 5. SSM Module — Parameter Store
# Provisions all 11 parameters consumed by the user_data bootstrap scripts.
# JWT secrets are stored as SecureString (KMS-encrypted).
module "ssm" {
  source       = "./modules/ssm"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Git config
  git_repo_url = "https://github.com/Savitxr/Fanvault-v2.git"
  git_branch   = "main"

  # App config
  cors_origin        = var.cors_origin
  jwt_secret         = var.jwt_secret         # Supply via terraform.tfvars (sensitive)
  jwt_refresh_secret = var.jwt_refresh_secret # Supply via terraform.tfvars (sensitive)

  # DynamoDB table names (sourced from module outputs — always consistent)
  dynamodb_table_users    = module.dynamodb.table_users_name
  dynamodb_table_profiles = module.dynamodb.table_profiles_name
  dynamodb_table_products = module.dynamodb.table_products_name
  dynamodb_table_orders   = module.dynamodb.table_orders_name

  # S3 bucket name (sourced from s3_lambda module output)
  s3_bucket_name = module.s3_lambda.s3_bucket_name

  depends_on = [module.dynamodb, module.s3_lambda]
}

# 6. S3 & Lambda Module
module "s3_lambda" {
  source          = "./modules/s3_lambda"
  lambda_role_arn = module.iam.lambda_role_arn
  project_name    = var.project_name
  environment     = var.environment
}

# 7. DNS Module (Route53 Private Zone mapping db.fanvault.internal)
module "dns" {
  source             = "./modules/dns"
  vpc_id             = module.vpc.vpc_id
  mongodb_private_ip = module.compute.mongodb_private_ip
  project_name       = var.project_name
  environment        = var.environment
}

# 8. Compute Module (Bastion, MongoDB, ALB, Target Groups, Launch Templates, ASGs)
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

  # IAM Instance Profiles — attached to each Launch Template
  ec2_backend_instance_profile_name  = module.iam.ec2_backend_instance_profile_name
  ec2_frontend_instance_profile_name = module.iam.ec2_frontend_instance_profile_name

  depends_on = [module.iam, module.ssm]
}
