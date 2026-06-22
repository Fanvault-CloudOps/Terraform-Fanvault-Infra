resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/${var.project_name}-${var.environment}-eks/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudwatch"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
  }
}
