resource "aws_secretsmanager_secret" "secret" {
  name                    = "${var.project_name}-${var.environment}-app-secrets"
  recovery_window_in_days = 0 # Forces immediate deletion if destroyed

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode(var.secret_values)
}
