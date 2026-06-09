# -----------------------------------------------------------------------------
# ROOT MAIN.TF — FanVault v2 Infrastructure Provisioning
# Reorganized into capability-based modules layout.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# 1. Networking Module (formerly vpc)
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
}

# 2. Security Groups Module (formerly security)
module "security_groups" {
  source       = "./modules/security_groups"
  vpc_id       = module.networking.vpc_id
  admin_ssh_ip = var.admin_ssh_ip
  project_name = var.project_name
  environment  = var.environment
}

# 3. Notifications Module (formerly sns)
module "notifications" {
  source                = "./modules/notifications"
  project_name          = var.project_name
  environment           = var.environment
  alert_email           = var.alert_email
  sns_feedback_role_arn = module.iam.sns_feedback_role_arn
}

# 4. IAM Module
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  github_repo  = var.github_repo

  # Scope DynamoDB permissions to all FanVault table ARNs (statically defined to avoid dependency cycle)
  dynamodb_table_arns = [
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-users",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-profiles",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-orders",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs",
    "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-metadata",
  ]

  # SNS topic ARNs for publishing permissions (statically defined to avoid dependency cycle)
  sns_topic_arns = [
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-order-failure-alerts",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-admin-operational-alerts",
  ]

  # SNS KMS key ARN for decryption/encryption permissions (statically defined to avoid dependency cycle)
  sns_kms_key_arn = "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"

  # SSM path prefix — IAM policy grants GetParameter on /fanvault/* only
  ssm_parameter_prefix = "/fanvault"

  # S3 name prefix — avoids circular dep with storage module
  s3_bucket_name_prefix = var.project_name

  # Event-driven Lambda execution role dependencies (interpolated to avoid cycle with storage/sns modules)
  dynamodb_table_audit_logs_arn        = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs"
  dynamodb_table_products_arn          = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products"
  s3_bucket_product_images_arn         = "arn:aws:s3:::${var.project_name}-product-images-*"
  sns_topic_low_inventory_arn          = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts"
  sns_topic_product_upload_failure_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures"
}

# 5. Storage Module (combines dynamodb and s3_lambda)
module "storage" {
  source            = "./modules/storage"
  project_name      = var.project_name
  environment       = var.environment
  billing_mode      = "PAY_PER_REQUEST"
  enable_pitr       = true
  enable_encryption = true
  lambda_role_arn   = module.iam.lambda_role_arn
  cors_origin       = var.cors_origin
}

# 6. Configuration Module (formerly ssm)
module "configuration" {
  source       = "./modules/configuration"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Git config
  git_repo_url = "https://github.com/Savitxr/Fanvault-v2.git"
  git_branch   = "main"

  # App config
  cors_origin        = var.cors_origin
  jwt_secret         = var.jwt_secret
  jwt_refresh_secret = var.jwt_refresh_secret

  # DynamoDB table names
  dynamodb_table_users      = module.storage.table_users_name
  dynamodb_table_profiles   = module.storage.table_profiles_name
  dynamodb_table_products   = module.storage.table_products_name
  dynamodb_table_orders     = module.storage.table_orders_name
  dynamodb_table_audit_logs = module.storage.table_audit_logs_name
  dynamodb_table_metadata   = module.storage.table_metadata_name

  # S3 bucket name & CloudFront URL
  s3_bucket_name    = module.storage.s3_bucket_name
  s3_cloudfront_url = module.storage.cloudfront_domain_name

  # EventBridge bus name
  eventbridge_bus_name = module.event_processing.event_bus_name

  # SNS Topic ARNs
  sns_topic_low_inventory           = module.notifications.sns_topic_low_inventory_arn
  sns_topic_order_failure           = module.notifications.sns_topic_order_failure_arn
  sns_topic_product_upload_failure  = module.notifications.sns_topic_product_upload_failure_arn
  sns_topic_admin_operational_alert = module.notifications.sns_topic_admin_operational_alert_arn

  depends_on = [module.storage, module.event_processing, module.notifications]
}

# 7. Event Processing Module (formerly event_driven)
module "event_processing" {
  source                         = "./modules/event_processing"
  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  dynamodb_table_audit_logs_arn  = module.storage.table_audit_logs_arn
  dynamodb_table_audit_logs_name = module.storage.table_audit_logs_name
  dynamodb_table_products_arn    = module.storage.table_products_arn
  dynamodb_table_products_name   = module.storage.table_products_name
  s3_bucket_product_images_arn   = module.storage.s3_product_images_bucket_arn
  s3_bucket_product_images_name  = module.storage.s3_bucket_name

  # Lambda consumers execution role (passed from IAM)
  lambda_role_arn = module.iam.lambda_consumers_role_arn

  # SNS integration
  sns_topic_low_inventory_arn          = module.notifications.sns_topic_low_inventory_arn
  sns_topic_product_upload_failure_arn = module.notifications.sns_topic_product_upload_failure_arn
  sns_key_arn                          = module.notifications.sns_key_arn
}

# 8. Backend Module (formerly compute)
module "backend" {
  source                   = "./modules/backend"
  vpc_id                   = module.networking.vpc_id
  public_subnets           = module.networking.public_subnets
  frontend_private_subnets = module.networking.frontend_private_subnets
  backend_private_subnets  = module.networking.backend_private_subnets
  database_private_subnets = module.networking.database_private_subnets
  alb_sg_id                = module.security_groups.alb_sg_id
  frontend_sg_id           = module.security_groups.frontend_sg_id
  backend_sg_id            = module.security_groups.backend_sg_id
  bastion_sg_id            = module.security_groups.bastion_sg_id
  lambda_function_arn      = module.storage.lambda_function_arn
  lambda_function_name     = module.storage.lambda_function_name
  key_name                 = var.key_name
  project_name             = var.project_name
  environment              = var.environment

  # IAM Instance Profiles
  ec2_backend_instance_profile_name  = module.iam.ec2_backend_instance_profile_name
  ec2_frontend_instance_profile_name = module.iam.ec2_frontend_instance_profile_name

  depends_on = [module.iam, module.configuration]
}

# 9. Monitoring Module (Placeholder)
module "monitoring" {
  source = "./modules/monitoring"
}

# 10. Governance Module (Placeholder)
module "governance" {
  source = "./modules/governance"
}
