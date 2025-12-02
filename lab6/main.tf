provider "aws" {
  region = "eu-central-1"
}

########################
# Security Group для ALB
########################
resource "aws_security_group" "alb_sg" {
  name        = "lab6-alb-sg"
  description = "Security group for lab6 ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# Launch Template
########################
resource "aws_launch_template" "web" {
  name_prefix   = "lab6-launch-template-"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  # SG для самих web-инстансов — уже создан вручную
  vpc_security_group_ids = [var.instance_sg_id]

  monitoring {
    enabled = true
  }
}

########################
# Target Group
########################
resource "aws_lb_target_group" "tg" {
  name     = "lab6-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

########################
# Application Load Balancer
########################
resource "aws_lb" "alb" {
  name               = "lab6-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

########################
# Auto Scaling Group
########################
resource "aws_autoscaling_group" "asg" {
  name                = "lab6-asg"
  max_size            = 4
  min_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids  # приватные подсети

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 60

  metrics_granularity = "1Minute"
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
    "GroupMaxSize",
    "GroupMinSize",
  ]
}

########################
# Target Tracking по CPU
########################
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "lab6-cpu-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 50

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}