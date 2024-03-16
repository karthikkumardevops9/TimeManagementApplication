# Allocate Elastic IPs for NAT Gateways outside of the VPC module
resource "aws_eip" "nat" {
  count = var.nat_gateway_deployment_scenario == "one_per_az" ? length(var.azs) : 1
  domain   = "vpc"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.5.3" # Make sure to use an appropriate version

  name = "timemanagement-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.nat_gateway_deployment_scenario == "single"
  one_nat_gateway_per_az = var.nat_gateway_deployment_scenario == "one_per_az"
  reuse_nat_ips       = true # Use existing EIPs
  external_nat_ip_ids = aws_eip.nat.*.id

  enable_vpn_gateway = true

  tags = {
    Terraform    = "true"
    Environment  = "dev"
  }
}

# Define variable for NAT Gateway deployment scenario
variable "nat_gateway_deployment_scenario" {
  description = "NAT Gateway deployment scenario: 'single', 'one_per_az', or any other value for default behavior (one per subnet)"
  default     = "one_per_az" # Change as needed: "single", "one_per_az"
}

variable "azs" {
  description = "List of availability zones in the region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}



















# # provider "aws" {
# #   region = "us-east-1" # Specify your AWS region
# # }

# # Allocate Elastic IPs for NAT Gateways outside of the VPC module
# resource "aws_eip" "nat" {
#   count = var.nat_gateway_deployment_scenario == "one_per_az" ? length(var.azs) : 1
#   domain = "vpc"
# }

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = ">= 5.5.3" # Make sure to use an appropriate version

#   name = "timemanagement-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = ["us-east-1a", "us-east-1b"]
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

#   enable_nat_gateway = true
#   single_nat_gateway = var.nat_gateway_deployment_scenario == "single"
#   one_nat_gateway_per_az = var.nat_gateway_deployment_scenario == "one_per_az"
#   reuse_nat_ips       = true # Use existing EIPs
#   external_nat_ip_ids = aws_eip.nat.*.id

#   enable_vpn_gateway = true

#   tags = {
#     Terraform    = "true"
#     Environment  = "dev"
#   }
# }

# # Define variable for NAT Gateway deployment scenario
# variable "nat_gateway_deployment_scenario" {
#   description = "NAT Gateway deployment scenario: 'single', 'one_per_az', or any other value for default behavior (one per subnet)"
#   default     = "one_per_az" # Change as needed: "single", "one_per_az"
# }

# variable "azs" {
#   description = "List of availability zones in the region"
#   type        = list(string)
#   default     = ["us-east-1a", "us-east-1b"]
# }

# # resource "aws_lb" "app_lb" {
# #   name               = "timemanagement-app-lb"
# #   internal           = false
# #   load_balancer_type = "application"
# #   security_groups    = [aws_security_group.alb_sg.id]
# #   subnets            = module.vpc.public_subnets

# #   enable_deletion_protection = false

# #   tags = {
# #     Name = "timemanagement-app-lb"
# #   }
# # }

# # resource "aws_security_group" "alb_sg" {
# #   name        = "timemanagement-alb-sg"
# #   description = "Security group for ALB"
# #   vpc_id      = module.vpc.vpc_id

# #   ingress {
# #     from_port   = 80
# #     to_port     = 80
# #     protocol    = "tcp"
# #     cidr_blocks = ["0.0.0.0/0"]
# #   }

# #   egress {
# #     from_port   = 0
# #     to_port     = 0
# #     protocol    = "-1"
# #     cidr_blocks = ["0.0.0.0/0"]
# #   }
# # }

# # resource "aws_lb_listener" "front_end" {
# #   load_balancer_arn = aws_lb.app_lb.arn
# #   port              = "80"
# #   protocol          = "HTTP"

# #   default_action {
# #     type             = "forward"
# #     target_group_arn = aws_lb_target_group.app_tg.arn
# #   }
# # }

# # resource "aws_lb_target_group" "app_tg" {
# #   name     = "timemanagement-app-tg"
# #   port     = 80
# #   protocol = "HTTP"
# #   vpc_id   = module.vpc.vpc_id

# #   health_check {
# #     path                = "/"
# #     protocol            = "HTTP"
# #     healthy_threshold   = 2
# #     unhealthy_threshold = 2
# #     timeout             = 5
# #     interval            = 30
# #     matcher             = "200"
# #   }
# # }

resource "aws_security_group" "security_group" {
  name   = "ecs-security-group"
  vpc_id = module.vpc.vpc_id


 ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "any"
  }


 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_ecr_repository" "timeoff_management_app" {
#   name                 = "timeoff-management-app"
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = true
#   }

#   tags = {
#     Environment = "development"
#   }
# }



