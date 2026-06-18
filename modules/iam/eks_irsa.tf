# =============================================================================
# IAM Module — EKS IRSA Roles (IAM Roles for Service Accounts)
# =============================================================================

# Trust policy template for EKS OIDC
data "aws_iam_policy_document" "eks_irsa_trust_user" {
  count = var.enable_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:sub"
      # Trust both dev and prod namespaces for the user-service service account
      values = [
        "system:serviceaccount:dev:user-service",
        "system:serviceaccount:prod:user-service"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_irsa_trust_commerce" {
  count = var.enable_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:sub"
      # Trust both dev and prod namespaces for the commerce-service service account
      values = [
        "system:serviceaccount:dev:commerce-service",
        "system:serviceaccount:prod:commerce-service"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── 1. User Service IRSA Role ────────────────────────────────────────────────
#PK  : userId (matches fanvault-users PK — 1:1 relationship)
#No GSI needed — all lookups are by userId (from JWT payload)
resource "aws_iam_role" "user_irsa" {
  count              = var.enable_irsa ? 1 : 0
  name               = "${var.project_name}-user-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.eks_irsa_trust_user[0].json
  description        = "IAM role assumed by user-service pods in EKS via OIDC"

  tags = {
    Name        = "${var.project_name}-user-irsa-role"
    Environment = var.environment
  }
}

# Least privilege policy for User Service (profiles table access)
resource "aws_iam_policy" "user_dynamodb_policy" {
  count       = var.enable_irsa ? 1 : 0
  name        = "${var.project_name}-user-dynamodb-policy"
  description = "Allows profile CRUD operations in DynamoDB for User Service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBProfilesAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-profiles",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-profiles/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "user_dynamodb_attach" {
  count      = var.enable_irsa ? 1 : 0
  role       = aws_iam_role.user_irsa[0].name
  policy_arn = aws_iam_policy.user_dynamodb_policy[0].arn
}


# ── 2. Commerce Service IRSA Role ─────────────────────────────────────────────
resource "aws_iam_role" "commerce_irsa" {
  count              = var.enable_irsa ? 1 : 0
  name               = "${var.project_name}-commerce-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.eks_irsa_trust_commerce[0].json
  description        = "IAM role assumed by commerce-service pods in EKS via OIDC"

  tags = {
    Name        = "${var.project_name}-commerce-irsa-role"
    Environment = var.environment
  }
}

# Least privilege policy for Commerce Service (products, orders, metadata, audit-logs tables access)
resource "aws_iam_policy" "commerce_dynamodb_policy" {
  count       = var.enable_irsa ? 1 : 0
  name        = "${var.project_name}-commerce-dynamodb-policy"
  description = "Allows commerce CRUD operations in DynamoDB for Commerce Service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBCommerceAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-products/index/*",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-orders",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-orders/index/*",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-audit-logs/index/*",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-metadata",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-metadata/index/*"
        ]
      },
      {
        Sid    = "EventBridgePublishEvents"
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = [
          "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/${var.project_name}-event-bus"
        ]
      },
      {
        Sid    = "SNSPublishAlerts"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.project_name}-low-inventory-alerts",
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.project_name}-order-failure-alerts",
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.project_name}-product-upload-failures",
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.project_name}-admin-operational-alerts"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "commerce_dynamodb_attach" {
  count      = var.enable_irsa ? 1 : 0
  role       = aws_iam_role.commerce_irsa[0].name
  policy_arn = aws_iam_policy.commerce_dynamodb_policy[0].arn
}


# ── 3. AI Service IRSA Role ────────────────────────────────────────────────────
data "aws_iam_policy_document" "eks_irsa_trust_ai" {
  count = var.enable_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:dev:ai-service",
        "system:serviceaccount:prod:ai-service"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ai_irsa" {
  count              = var.enable_irsa ? 1 : 0
  name               = "${var.project_name}-ai-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.eks_irsa_trust_ai[0].json
  description        = "IAM role assumed by ai-service pods in EKS via OIDC"

  tags = {
    Name        = "${var.project_name}-ai-irsa-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "ai_service_policy" {
  count       = var.enable_irsa ? 1 : 0
  name        = "${var.project_name}-ai-service-policy"
  description = "Allows ai-service to invoke Bedrock, emit CloudWatch metrics, read S3 product images, and read Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvokeModel"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
        ]
      },
      {
        Sid      = "CloudWatchPutAIMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
      },
      {
        Sid    = "S3ProductImagesRead"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-product-images-*/*"
        ]
      },
      {
        Sid    = "SecretsManagerReadAppSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*-app-secrets*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ai_service_policy_attach" {
  count      = var.enable_irsa ? 1 : 0
  role       = aws_iam_role.ai_irsa[0].name
  policy_arn = aws_iam_policy.ai_service_policy[0].arn
}
