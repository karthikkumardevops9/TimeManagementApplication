data "aws_iam_policy_document" "ec2_instance_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"


   principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name               = "timemanagementec2InstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_role_policy.json


 tags = {
    Name = "timemanagement-ec2-instanceRole"
  }
}

# Attach policies for EC2 to communicate with ECS
resource "aws_iam_policy_attachment" "ec2_ecs_policy" {
  name       = "ec2_ecs_policy_attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"                   
 
}

resource "aws_iam_policy_attachment" "ssm_policy" {
  name       = "ssm_policy_attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# # Attach policies for EC2 to communicate with ECR
resource "aws_iam_policy_attachment" "ec2_ecr_policy" {
  name       = "ec2_ecr_policy_attachment"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecs_role" {
  name_prefix = "ec2_instance_profile"
  path        = "/ec2/instance/"
  role        = aws_iam_role.ec2_role.name
}

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# EC2 Launch Template
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "timemanagement-ecs-template"
  image_id      = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type = "t3.medium"

  # key_name               = "teammanagementkeypair"
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  iam_instance_profile {
     arn = aws_iam_instance_profile.ecs_role.arn 
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "timemanagement-ecs-instance"
    }
  }

  user_data = filebase64("${path.module}/ecs.sh")
}

# Autoscaling Group for ECS Instances
resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = tolist(module.vpc.private_subnets)
  health_check_type   = "EC2"
  name_prefix         =  "timemanagement_ecs_asg"
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "ecs_alb" {
  name               = "timemanagement-ecs-alb"
  # internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = tolist(module.vpc.public_subnets)

  tags = {
    Name = "ecs-alb"
  }
}


########################################################################################################################
## Default HTTP listener that blocks all traffic without valid custom origin header
########################################################################################################################
resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

########################################################################################################################
## Default HTTPS listener that blocks all traffic without valid custom origin header
########################################################################################################################

resource "aws_alb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.alb_certificate.arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }

  tags = {
    Name = "timemanagement"
  }

  depends_on = [aws_acm_certificate.alb_certificate]
}

# Target Group for ECS Instances
resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-target-group"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 60
    matcher             = "200"
  }
}

resource "aws_acm_certificate" "alb_certificate" {
  domain_name               = "alb.${var.domain_name}"
  validation_method         = "DNS"

 tags = {
    Name = "timemanagement"
  }
}


resource "aws_acm_certificate_validation" "alb_certificate" {
  certificate_arn         = aws_acm_certificate.alb_certificate.arn
  validation_record_fqdns = [aws_route53_record.generic_certificate_validation.fqdn]
}

resource "aws_route53_record" "generic_certificate_validation" {
  name    = tolist(aws_acm_certificate.alb_certificate.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.alb_certificate.domain_validation_options)[0].resource_record_type
  zone_id = var.zone_id
  records = [tolist(aws_acm_certificate.alb_certificate.domain_validation_options)[0].resource_record_value]
  ttl     = 300
}


########################################################################################################################
## Point A record to CloudFront distribution
########################################################################################################################


resource "aws_route53_record" "alb_record" {
  name    = "alb.${var.domain_name}"
  type    = "A"
  zone_id = var.zone_id

 alias {
    name                   = aws_lb.ecs_alb.dns_name
    zone_id                = aws_lb.ecs_alb.zone_id
    evaluate_target_health = true
  }
}