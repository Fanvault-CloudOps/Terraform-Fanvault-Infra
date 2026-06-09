# =============================================================================
# IAM Module — Main
#
# Resources created:
#   1. Lambda execution role (existing) — S3 read for arch page Lambda
#   2. EC2 backend instance role + profile — DynamoDB + SSM + S3 + CloudWatch
#   3. EC2 frontend instance role + profile — SSM (for Git repo URL) + CloudWatch
# =============================================================================

# ── Data: current AWS account ID ─────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# PART 1: Lambda Execution Role (existing — unchanged)
# =============================================================================

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_s3_read" {
  name               = "${var.project_name}-lambda-s3-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.lambda_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# PART 2: EC2 Backend Instance Role
# Permissions:
#   - DynamoDB: full access on the 4 FanVault tables
#   - SSM:      GetParameter + GetParameters on /fanvault/* path
#   - S3:       GetObject on the private bucket (product image proxy)
#   - CloudWatch: PutMetricData + CreateLogGroup/Stream + PutLogEvents
# =============================================================================

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ── Inline policy: DynamoDB access (scoped to the 4 FanVault tables) ──────────
data "aws_iam_policy_document" "backend_dynamodb" {
  statement {
    sid    = "DynamoDBTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DescribeTable",
    ]
    # Scope to the specific table ARNs AND their GSI sub-resources
    resources = concat(
      var.dynamodb_table_arns,
      [for arn in var.dynamodb_table_arns : "${arn}/index/*"]
    )
  }
}

# ── Inline policy: SSM Parameter Store — read /fanvault/* secrets ─────────────
data "aws_iam_policy_document" "backend_ssm" {
  statement {
    sid    = "SSMParameterRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/*"
    ]
  }

  # Allow KMS Decrypt for SecureString parameters
  statement {
    sid    = "KMSDecryptSSM"
    effect = "Allow"
    actions = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

# ── Inline policy: S3 + KMS access on the product images bucket ──────────────────
data "aws_iam_policy_document" "backend_s3" {
  statement {
    sid       = "S3ProductImageAccess"
    effect    = "Allow"
    actions   = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    # Scoped to any bucket whose name starts with the project prefix (e.g. "fanvault-*")
    # This avoids a circular dependency: s3_lambda needs lambda_role from iam,
    # so iam cannot also depend on s3_lambda for the bucket ARN.
    resources = ["arn:aws:s3:::${var.s3_bucket_name_prefix}-*/*"]
  }

  statement {
    sid       = "KMSProductImageAccess"
    effect    = "Allow"
    actions   = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

# ── Inline policy: CloudWatch Logs + Metrics ──────────────────────────────────
data "aws_iam_policy_document" "ec2_cloudwatch" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

# ── Backend IAM Role ──────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_backend" {
  name               = "${var.project_name}-ec2-backend-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Instance role for FanVault backend EC2 (DynamoDB + SSM + S3 + CloudWatch)"

  tags = {
    Name        = "${var.project_name}-ec2-backend-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "backend_dynamodb" {
  name   = "${var.project_name}-backend-dynamodb-policy"
  role   = aws_iam_role.ec2_backend.id
  policy = data.aws_iam_policy_document.backend_dynamodb.json
}

resource "aws_iam_role_policy" "backend_ssm" {
  name   = "${var.project_name}-backend-ssm-policy"
  role   = aws_iam_role.ec2_backend.id
  policy = data.aws_iam_policy_document.backend_ssm.json
}

resource "aws_iam_role_policy" "backend_s3" {
  name   = "${var.project_name}-backend-s3-policy"
  role   = aws_iam_role.ec2_backend.id
  policy = data.aws_iam_policy_document.backend_s3.json
}

resource "aws_iam_role_policy" "backend_cloudwatch" {
  name   = "${var.project_name}-backend-cloudwatch-policy"
  role   = aws_iam_role.ec2_backend.id
  policy = data.aws_iam_policy_document.ec2_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "backend_ssm_core" {
  role       = aws_iam_role.ec2_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Backend EC2 Instance Profile ─────────────────────────────────────────────
# This is what you attach to the Launch Template (iam_instance_profile)
resource "aws_iam_instance_profile" "ec2_backend" {
  name = "${var.project_name}-ec2-backend-profile"
  role = aws_iam_role.ec2_backend.name

  tags = {
    Name        = "${var.project_name}-ec2-backend-profile"
    Environment = var.environment
  }
}

# =============================================================================
# PART 3: EC2 Frontend Instance Role
# Permissions (minimal):
#   - SSM: GetParameter on /fanvault/git/* (to read repo URL + branch at boot)
#   - CloudWatch: Logs + Metrics
# =============================================================================

resource "aws_iam_role" "ec2_frontend" {
  name               = "${var.project_name}-ec2-frontend-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Instance role for FanVault frontend EC2 (SSM + CloudWatch only)"

  tags = {
    Name        = "${var.project_name}-ec2-frontend-role"
    Environment = var.environment
  }
}

# Frontend only needs to read Git repo config from SSM (minimal permissions)
data "aws_iam_policy_document" "frontend_ssm" {
  statement {
    sid    = "SSMGitConfig"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/git/*",
    ]
  }
}

resource "aws_iam_role_policy" "frontend_ssm" {
  name   = "${var.project_name}-frontend-ssm-policy"
  role   = aws_iam_role.ec2_frontend.id
  policy = data.aws_iam_policy_document.frontend_ssm.json
}

resource "aws_iam_role_policy" "frontend_cloudwatch" {
  name   = "${var.project_name}-frontend-cloudwatch-policy"
  role   = aws_iam_role.ec2_frontend.id
  policy = data.aws_iam_policy_document.ec2_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "frontend_ssm_core" {
  role       = aws_iam_role.ec2_frontend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Frontend EC2 Instance Profile ─────────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2_frontend" {
  name = "${var.project_name}-ec2-frontend-profile"
  role = aws_iam_role.ec2_frontend.name

  tags = {
    Name        = "${var.project_name}-ec2-frontend-profile"
    Environment = var.environment
  }
}
