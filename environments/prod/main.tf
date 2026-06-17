data "aws_caller_identity" "current" {}

module "vpc" {
  source                = "../../modules/vpc"
  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = "10.1.0.0/16"
  public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
  database_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]
  availability_zones    = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source             = "../../modules/eks"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_capacity   = 3
  max_capacity       = 5
  min_capacity       = 2
  instance_types     = ["t3.medium"]
}

module "dynamodb" {
  source            = "../../modules/dynamodb"
  project_name      = var.project_name
  environment       = var.environment
  billing_mode      = "PAY_PER_REQUEST"
  enable_pitr       = true
  enable_encryption = true
}

module "s3" {
  source       = "../../modules/s3"
  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
}

module "secrets_manager" {
  source       = "../../modules/secrets_manager"
  project_name = var.project_name
  environment  = var.environment
}

module "cloudwatch" {
  source             = "../../modules/cloudwatch"
  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = 30
}

module "cognito" {
  source        = "../../modules/cognito"
  project_name  = var.project_name
  environment   = var.environment
  callback_urls = ["https://fanvault.example.com"]
  logout_urls   = ["https://fanvault.example.com"]
}

module "iam" {
  source                = "../../modules/iam"
  project_name          = var.project_name
  environment           = var.environment
  github_repo           = var.github_repo
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
  enable_irsa           = true


  dynamodb_table_arns = [
    module.dynamodb.profiles_table_arn,
    module.dynamodb.products_table_arn,
    module.dynamodb.orders_table_arn,
    module.dynamodb.audit_logs_table_arn,
    module.dynamodb.metadata_table_arn,
  ]

  dynamodb_table_products_arn          = module.dynamodb.products_table_arn
  dynamodb_table_audit_logs_arn        = module.dynamodb.audit_logs_table_arn
  s3_bucket_product_images_arn         = module.s3.bucket_arn
  sns_topic_low_inventory_arn          = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts"
  sns_topic_product_upload_failure_arn = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures"
}

module "ecr" {
  source           = "../../modules/ecr"
  project_name     = var.project_name
  environment      = var.environment
  repository_names = ["frontend", "user-service", "commerce-service"]
}

module "argocd" {
  source              = "../../modules/argocd"
  argocd_helm_version = "7.1.3"
  depends_on          = [module.eks]
}
