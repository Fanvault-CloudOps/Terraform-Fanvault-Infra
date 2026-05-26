# Trust policy for AWS Lambda
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

# IAM Role creation
resource "aws_iam_role" "lambda_s3_read" {
  name               = "${var.project_name}-lambda-s3-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
  }
}

# Attach AWS managed policy for S3 Read Only access
resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.lambda_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Attach basic execution policy to allow VPC and CloudWatch Logging
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
