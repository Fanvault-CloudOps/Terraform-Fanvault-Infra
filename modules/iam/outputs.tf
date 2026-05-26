output "lambda_role_arn" {
  value       = aws_iam_role.lambda_s3_read.arn
  description = "ARN of the S3-read execution role for Lambda"
}
