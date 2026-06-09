output "lambda_function_name" {
  value       = aws_lambda_function.arch_page.function_name
  description = "The name of the Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.arch_page.arn
  description = "The ARN of the Lambda function"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.architecture.arn
  description = "ARN of the private S3 architecture/images bucket (used to scope IAM policy)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.product_images.id
  description = "Name of the private S3 product images bucket (stored in SSM /fanvault/s3/bucket)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.product_images_distribution.domain_name
  description = "The domain name of the CloudFront distribution for product images"
}
