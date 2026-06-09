# =============================================================================
# Root State Imports for existing Lambda Log Groups
# =============================================================================

import {
  to = module.monitoring.aws_cloudwatch_log_group.lambda_logs["fanvault-audit-logging-consumer"]
  id = "/aws/lambda/fanvault-audit-logging-consumer"
}

import {
  to = module.monitoring.aws_cloudwatch_log_group.lambda_logs["fanvault-thumbnail-generator-consumer"]
  id = "/aws/lambda/fanvault-thumbnail-generator-consumer"
}

import {
  to = module.monitoring.aws_cloudwatch_log_group.lambda_logs["fanvault-inventory-monitor-consumer"]
  id = "/aws/lambda/fanvault-inventory-monitor-consumer"
}

import {
  to = module.monitoring.aws_cloudwatch_log_group.lambda_logs["fanvault-arch-page-lambda"]
  id = "/aws/lambda/fanvault-arch-page-lambda"
}
