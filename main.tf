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

# 2.5 SNS Module
module "sns" {
  source       = "./modules/sns"
  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
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
  github_repo  = var.github_repo

  # Scope DynamoDB permissions to all FanVault table ARNs (least privilege)
  dynamodb_table_arns = [
    module.dynamodb.table_users_arn,
    module.dynamodb.table_profiles_arn,
    module.dynamodb.table_products_arn,
    module.dynamodb.table_orders_arn,
    module.dynamodb.table_audit_logs_arn,
    module.dynamodb.table_metadata_arn,
  ]

  # SNS topic ARNs for publishing permissions
  sns_topic_arns = [
    module.sns.sns_topic_low_inventory_arn,
    module.sns.sns_topic_order_failure_arn,
    module.sns.sns_topic_product_upload_failure_arn,
    module.sns.sns_topic_admin_operational_alert_arn,
  ]

  # SNS KMS key ARN for decryption/encryption permissions
  sns_kms_key_arn = module.sns.sns_key_arn

  # SSM path prefix — IAM policy grants GetParameter on /fanvault/* only
  ssm_parameter_prefix = "/fanvault"

  # S3 name prefix — avoids circular dep with s3_lambda (which needs lambda_role from IAM)
  # Policy becomes: arn:aws:s3:::fanvault-*/* — covers any bucket created by this project
  s3_bucket_name_prefix = var.project_name

  depends_on = [module.dynamodb, module.sns]
}

# 4. DynamoDB Module (Users, Profiles, Products, Orders — replaces MongoDB)
module "dynamodb" {
  source            = "./modules/dynamodb"
  project_name      = var.project_name
  environment       = var.environment
  billing_mode      = "PAY_PER_REQUEST" # On-demand — no capacity planning required
  enable_pitr       = true              # Point-in-Time Recovery for all tables
  enable_encryption = true              # AWS-owned KMS encryption at rest
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
  dynamodb_table_users      = module.dynamodb.table_users_name
  dynamodb_table_profiles   = module.dynamodb.table_profiles_name
  dynamodb_table_products   = module.dynamodb.table_products_name
  dynamodb_table_orders     = module.dynamodb.table_orders_name
  dynamodb_table_audit_logs = module.dynamodb.table_audit_logs_name
  dynamodb_table_metadata   = module.dynamodb.table_metadata_name

  # S3 bucket name (sourced from s3_lambda module output)
  s3_bucket_name    = module.s3_lambda.s3_bucket_name
  s3_cloudfront_url = module.s3_lambda.cloudfront_domain_name

  # EventBridge bus name
  eventbridge_bus_name = module.event_driven.event_bus_name

  # SNS Topic ARNs
  sns_topic_low_inventory           = module.sns.sns_topic_low_inventory_arn
  sns_topic_order_failure           = module.sns.sns_topic_order_failure_arn
  sns_topic_product_upload_failure   = module.sns.sns_topic_product_upload_failure_arn
  sns_topic_admin_operational_alert = module.sns.sns_topic_admin_operational_alert_arn

  depends_on = [module.dynamodb, module.s3_lambda, module.event_driven, module.sns]
}

# 6. S3 & Lambda Module
module "s3_lambda" {
  source          = "./modules/s3_lambda"
  lambda_role_arn = module.iam.lambda_role_arn
  project_name    = var.project_name
  environment     = var.environment
  cors_origin     = var.cors_origin
}

# 7. Event-Driven Workflows Module (EventBridge + Lambda Consumers)
module "event_driven" {
  source                         = "./modules/event_driven"
  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  dynamodb_table_audit_logs_arn  = module.dynamodb.table_audit_logs_arn
  dynamodb_table_audit_logs_name = module.dynamodb.table_audit_logs_name
  dynamodb_table_products_arn    = module.dynamodb.table_products_arn
  dynamodb_table_products_name   = module.dynamodb.table_products_name
  s3_bucket_product_images_arn   = module.s3_lambda.s3_product_images_bucket_arn
  s3_bucket_product_images_name  = module.s3_lambda.s3_bucket_name

  # SNS integration
  sns_topic_low_inventory_arn          = module.sns.sns_topic_low_inventory_arn
  sns_topic_product_upload_failure_arn = module.sns.sns_topic_product_upload_failure_arn
  sns_key_arn                          = module.sns.sns_key_arn
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
