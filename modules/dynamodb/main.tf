# =============================================================================
# DynamoDB Module — Main
#
# Tables:
#   fanvault-users    : Auth credentials (email, hashed password, role)
#   fanvault-profiles : User profile data (name, phone, addresses)
#   fanvault-products : Product catalog (sku, category, franchise, stock)
#   fanvault-orders   : Customer orders (userId, status, items)
#
# Design: Multi-table (separate tables per entity type)
# Encryption: AWS-owned KMS (SSEEnabled = true)
# PITR: Enabled on all tables for disaster recovery
# Billing: PAY_PER_REQUEST (on-demand) — no capacity planning needed
# =============================================================================

# ── Table 1: fanvault-users ───────────────────────────────────────────────────
# PK  : userId (UUID generated at creation)
# GSI : email-index → enables getUserByEmail lookup for login
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-users"
  billing_mode = var.billing_mode
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  # GSI-1: email-index — fast lookup by email for login/registration checks
  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-users"
    Environment = var.environment
    Service     = "fanvault-user-auth-service"
  }
}

# ── Table 2: fanvault-profiles ────────────────────────────────────────────────
# PK  : userId (matches fanvault-users PK — 1:1 relationship)
# No GSI needed — all lookups are by userId (from JWT payload)
resource "aws_dynamodb_table" "profiles" {
  name         = "${var.project_name}-profiles"
  billing_mode = var.billing_mode
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-profiles"
    Environment = var.environment
    Service     = "fanvault-user-auth-service"
  }
}

# ── Table 3: fanvault-products ────────────────────────────────────────────────
# PK  : productId (UUID)
# GSI : sku-index               → unique SKU lookup
# GSI : category-franchise-index → filtered product listing by category + franchise
resource "aws_dynamodb_table" "products" {
  name         = "${var.project_name}-products"
  billing_mode = var.billing_mode
  hash_key     = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  attribute {
    name = "sku"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "franchise"
    type = "S"
  }

  # GSI-1: sku-index — enforces unique SKU + allows lookup by SKU
  global_secondary_index {
    name            = "sku-index"
    hash_key        = "sku"
    projection_type = "ALL"
  }

  # GSI-2: category-franchise-index — efficient product listing with filters
  # Example: GET /api/products?category=clothing&franchise=Marvel
  global_secondary_index {
    name            = "category-franchise-index"
    hash_key        = "category"
    range_key       = "franchise"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-products"
    Environment = var.environment
    Service     = "fanvault-commerce-service"
  }
}

# ── Table 4: fanvault-orders ──────────────────────────────────────────────────
# PK  : orderId (UUID)
# GSI : userId-createdAt-index    → paginated user order history, sorted by date
# GSI : orderNumber-index         → lookup by human-readable order number (FAN-XXXX)
# GSI : status-createdAt-index    → admin orders filtered by status
resource "aws_dynamodb_table" "orders" {
  name         = "${var.project_name}-orders"
  billing_mode = var.billing_mode
  hash_key     = "orderId"

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "orderNumber"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S" # ISO 8601 string — lexicographic sort works correctly for dates
  }

  # GSI-1: userId-createdAt-index
  # Query: userId = :uid, ScanIndexForward = false → most recent orders first
  global_secondary_index {
    name            = "userId-createdAt-index"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # GSI-2: orderNumber-index — customer support lookup by order number
  global_secondary_index {
    name            = "orderNumber-index"
    hash_key        = "orderNumber"
    projection_type = "ALL"
  }

  # GSI-3: status-createdAt-index — admin dashboard: orders by status, sorted by date
  global_secondary_index {
    name            = "status-createdAt-index"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  server_side_encryption {
    enabled = var.enable_encryption
  }

  tags = {
    Name        = "${var.project_name}-orders"
    Environment = var.environment
    Service     = "fanvault-commerce-service"
  }
}
