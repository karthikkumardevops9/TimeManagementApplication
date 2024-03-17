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

resource "aws_security_group" "ec2_security_group" {
  name   = "ec2_security_group"
  vpc_id = module.vpc.vpc_id


 ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
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

resource "aws_security_group" "security_group" {
  name   = "ecs-security-group"
  vpc_id = module.vpc.vpc_id


 ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "any"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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




