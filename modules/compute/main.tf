# -----------------------------------------------------------------------------
# Dynamic AMI Lookup (Ubuntu 22.04 LTS)
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Bastion & MongoDB Instances
# -----------------------------------------------------------------------------

# Public Bastion Host
resource "aws_instance" "bastion" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t3.micro"
  key_name                = var.key_name
  subnet_id               = var.public_subnets[0] # Place in public-1a
  vpc_security_group_ids  = [var.bastion_sg_id]

  tags = {
    Name        = "${var.project_name}-bastion"
    Environment = var.environment
  }
}

# Private MongoDB Server (Inside secure Database Subnet)
resource "aws_instance" "mongodb" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t3.medium"
  key_name                = var.key_name
  subnet_id               = var.database_private_subnets[0] # Place in db-1a
  vpc_security_group_ids  = [var.db_sg_id]
  private_ip              = "10.0.31.100" # Static IP within database subnet

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
  }

  tags = {
    Name        = "${var.project_name}-mongodb"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# ALB & Target Groups
# -----------------------------------------------------------------------------

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets # Span public 1a and 1b

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group 1: Nginx Frontend
resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/index.html"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-frontend-tg"
    Environment = var.environment
  }
}

# Target Group 2: Identity Service Node
resource "aws_lb_target_group" "identity" {
  name     = "${var.project_name}-identity-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "3001"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-identity-tg"
    Environment = var.environment
  }
}

# Target Group 3: Commerce Service Node
resource "aws_lb_target_group" "commerce" {
  name     = "${var.project_name}-commerce-tg"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "3002"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-commerce-tg"
    Environment = var.environment
  }
}

# Target Group 4: Lambda Target Group (No port/protocol since it targets Lambda)
resource "aws_lb_target_group" "lambda" {
  name        = "${var.project_name}-lambda-tg"
  target_type = "lambda"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-lambda-tg"
    Environment = var.environment
  }
}

# Grant permission to ALB to invoke Lambda
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = var.lambda_function_arn
  depends_on       = [aws_lambda_permission.alb]
}

# -----------------------------------------------------------------------------
# ALB Listeners & Rules
# -----------------------------------------------------------------------------

# HTTP Listener (Port 80) -> Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (Port 443) -> Forward to Frontend target group by default
# Note: Self-signed certificate for demo purposes in code. Replace with real ACM ARN.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/placeholder-arn" # Replace in production

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Rule 1 (P5): Host arch.fanvault.com -> Lambda Target Group
resource "aws_lb_listener_rule" "arch_host" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  condition {
    host_header {
      values = ["arch.fanvault.com"]
    }
  }
}

# Rule 2 (P10): Path /api/auth/* -> Identity TG
resource "aws_lb_listener_rule" "auth_path" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.identity.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/*"]
    }
  }
}

# Rule 3 (P20): Path /api/users/* -> Identity TG
resource "aws_lb_listener_rule" "users_path" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.identity.arn
  }

  condition {
    path_pattern {
      values = ["/api/users/*"]
    }
  }
}

# Rule 4 (P30): Path /api/products/* -> Commerce TG
resource "aws_lb_listener_rule" "products_path" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce.arn
  }

  condition {
    path_pattern {
      values = ["/api/products/*"]
    }
  }
}

# Rule 5 (P40): Path /api/orders/* -> Commerce TG
resource "aws_lb_listener_rule" "orders_path" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders/*"]
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Groups & Launch Templates
# -----------------------------------------------------------------------------

# Helper Template for Application Nodes
# Note: In real setup, Golden AMI is created and specified here.
# For bootstrap, we enable systemd services on instance creation.
resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.project_name}-frontend-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.frontend_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-frontend-node"
      Environment = var.environment
    }
  }
}

resource "aws_launch_template" "identity" {
  name_prefix   = "${var.project_name}-identity-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-identity-node"
      Environment = var.environment
    }
  }
}

resource "aws_launch_template" "commerce" {
  name_prefix   = "${var.project_name}-commerce-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-commerce-node"
      Environment = var.environment
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Groups
# -----------------------------------------------------------------------------

# Frontend ASG
resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.project_name}-frontend-asg-"
  vpc_zone_identifier = var.frontend_private_subnets # Private Subnets 1a/1b
  target_group_arns   = [aws_lb_target_group.frontend.arn]
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# Identity ASG
resource "aws_autoscaling_group" "identity" {
  name_prefix         = "${var.project_name}-identity-asg-"
  vpc_zone_identifier = var.backend_private_subnets # Private Subnets 1a/1b
  target_group_arns   = [aws_lb_target_group.identity.arn]
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4

  launch_template {
    id      = aws_launch_template.identity.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# Commerce ASG
resource "aws_autoscaling_group" "commerce" {
  name_prefix         = "${var.project_name}-commerce-asg-"
  vpc_zone_identifier = var.backend_private_subnets # Private Subnets 1a/1b
  target_group_arns   = [aws_lb_target_group.commerce.arn]
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4

  launch_template {
    id      = aws_launch_template.commerce.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Target Tracking Policies (CPU Utilization > 70%)
# -----------------------------------------------------------------------------

resource "aws_autoscaling_policy" "frontend_cpu" {
  name                   = "${var.project_name}-frontend-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "identity_cpu" {
  name                   = "${var.project_name}-identity-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.identity.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "commerce_cpu" {
  name                   = "${var.project_name}-commerce-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.commerce.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
