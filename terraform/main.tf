
# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "timemanagement-ecs-cluster"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "timemanagement"


 auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
    # managed_termination_protection = "ENABLED"


   managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}


resource "aws_ecs_cluster_capacity_providers" "timemanagementecs" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name


 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]


 default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  }
}

########################################################################################################################
## Create service-linked role used by the ECS Service to manage the ECS Cluster
########################################################################################################################


resource "aws_iam_role" "ecs_service_role" {
  name               = "timemanagement_ECS_ServiceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_policy.json


 tags = {
    name = "timemanagement"
  }
}


data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"


   principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com",]
    }
  }
}


resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "timemanagement_ECS_ServiceRolePolicy"
  policy = data.aws_iam_policy_document.ecs_service_role_policy.json
  role   = aws_iam_role.ecs_service_role.id
}


data "aws_iam_policy_document" "ecs_service_role_policy" {
  statement {
    effect  = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
      "ec2:DescribeTags",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutSubscriptionFilter",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}


########################################################################################################################
## IAM Role for ECS Task execution
########################################################################################################################


resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "timemanagement_ECS_TaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json


 tags = {
    name = "timemanagement"
  }
}


data "aws_iam_policy_document" "task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]


   principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


########################################################################################################################
## IAM Role for ECS Task
########################################################################################################################


resource "aws_iam_role" "ecs_task_iam_role" {
  name               = "timemanagement_ECS_TaskIAMRole"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json


 tags = {
    name = "timemanagement"
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = "timemanagement-ecs-task"
  network_mode       = "awsvpc"  # Update network mode  
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_iam_role.arn  
  container_definitions = jsonencode([
    {
      name      = "timemanagement-app"
      image     = "891377163697.dkr.ecr.us-east-1.amazonaws.com/time-management-app:latest"
      cpu       = 500
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/timemanagement-ecs-task"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "timemanagement-ecs-service"  
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2

  network_configuration {
    subnets         = tolist(module.vpc.private_subnets)
    security_groups = [aws_security_group.security_group.id]
  }
 
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    base              = 1
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }


 lifecycle {
    ignore_changes = [desired_count]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "timemanagement-app"
    container_port   = 3000
  }
  
}


