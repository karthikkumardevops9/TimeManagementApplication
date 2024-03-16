provider "aws" {
  region = var.aws_region # Specify your AWS region
}

# Allocate Elastic IPs for NAT Gateways outside of the VPC module
resource "aws_eip" "nat" {
  count = var.nat_gateway_deployment_scenario == "one_per_az" ? length(var.azs) : 1
  vpc   = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = var.vpc_module_version # Make sure to use an appropriate version

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway      = var.vpc_enable_nat_gateway
  single_nat_gateway      = var.vpc_single_nat_gateway
  one_nat_gateway_per_az = var.vpc_one_nat_gateway_per_az
  reuse_nat_ips           = var.vpc_reuse_nat_ips
  external_nat_ip_ids     = aws_eip.nat.*.id

  enable_vpn_gateway = var.vpc_enable_vpn_gateway

  tags = var.vpc_tags
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

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_module_version" {
  description = "Version of the VPC module to use"
  default     = ">= 5.5.3"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "timemanagement-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "List of availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_private_subnets" {
  description = "List of private subnets for the VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_public_subnets" {
  description = "List of public subnets for the VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "vpc_enable_nat_gateway" {
  description = "Whether to enable NAT Gateway"
  default     = true
}

variable "vpc_single_nat_gateway" {
  description = "Whether to use a single NAT Gateway"
  default     = false
}

variable "vpc_one_nat_gateway_per_az" {
  description = "Whether to use one NAT Gateway per availability zone"
  default     = true
}

variable "vpc_reuse_nat_ips" {
  description = "Whether to reuse existing EIPs for NAT Gateway"
  default     = true
}

variable "vpc_enable_vpn_gateway" {
  description = "Whether to enable VPN Gateway"
  default     = true
}

variable "vpc_tags" {
  description = "Tags for the VPC"
  type        = map(string)
  default     = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_lb" "app_lb" {
  name               = var.lb_name
  internal           = var.lb_internal
  load_balancer_type = var.lb_type
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = var.lb_tags
}

variable "lb_name" {
  description = "Name of the Application Load Balancer"
  default     = "timemanagement-app-lb"
}

variable "lb_internal" {
  description = "Whether the Application Load Balancer is internal"
  default     = false
}

variable "lb_type" {
  description = "Type of the Load Balancer (e.g., application, network)"
  default     = "application"
}

variable "lb_tags" {
  description = "Tags for the Load Balancer"
  type        = map(string)
  default     = {
    Name = "timemanagement-app-lb"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = var.sg_name
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

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

variable "sg_name" {
  description = "Name of the security group"
  default     = "timemanagement-alb-sg"
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

variable "listener_port" {
  description = "Port for the listener"
  default     = "80"
}

variable "listener_protocol" {
  description = "Protocol for the listener"
  default     = "HTTP"
}

resource "aws_lb_target_group" "app_tg" {
  name     = var.target_group_name
  port     = var.target_group_port
  protocol = var.target_group_protocol
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = var.target_group_health_check_protocol
    healthy_threshold   = var.target_group_healthy_threshold
    unhealthy_threshold = var.target_group_unhealthy_threshold
    timeout             = var.target_group_timeout
    interval            = var.target_group_interval
    matcher             = var.target_group_matcher
  }
}

variable "target_group_name" {
  description = "Name of the target group


variable





variable "aws_region" {
  type    = string
  default = "us-east-1"
}


variable "vpc_cidr" {
  description = "CIDR block for main"
  type        = string
  default     = "10.0.0.0/16"
}


variable "availability_zones" {
  type    = string
  default = "us-east-1a"
}
