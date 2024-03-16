  ## This post, will help you understand on how to set up an ECS cluster of EC2 instances using Terraform.
## How to deploy a service on ECS clusters
## ECS deployment with Terraform
## Steps that we follow and setup.

1. Setting up the VPC
2. Configuring the EC2 instances
3. Configuring the ECS cluster
4. Testing the ECS deployment
   
## How to deploy a service on ECS clusters
1. There are mainly two ways of deploying a service on ECS clusters – Fargate and EC2 instances.This depends on the underlying infrastructure used to run the container workloads of any ECS service.
2. AWS Fargate is a more cloud-native approach where the compute instances are automatically managed by AWS.
3. Running the ECS service on EC2 instances provides more control over the infrastructure. This also requires taking additional steps to set up the EC2 instances and auto-scaling group, networking, etc.
4. ecs task definition terraform.
5. When an ECS Cluster is created, before any service is deployed, we must provide the cluster with capacity providers.
6. Here the capacity providers are the EC2 instances where the scaling is managed by ASG.  The service can then be deployed once the capacity providers or the capacity-providing EC2 instances are registered with the ECS cluster.
7. An ECS service consists of multiple tasks. Each task is created based on the task definition provided by the service.
8. A task definition is a template that describes the source of the application image, resources required in terms of CPU and memory units, container and host port mapping, and other critical information.
9. Apart from the task definition, ECS service also provides the number of container instances to be created. This automatically creates the tasks, which are then assigned a target EC2 instance infrastructure where the containers are run. The running containers serve the incoming requests from the application load balancer (ALB) which is deployed in front of the EC2 instances in a VPC.

## Why use ECS over EC2?
1. ECS and EC2 are services provided by AWS for running applications in the cloud. Although at a high level, they seem to host workloads, they serve different purposes and are suited for different types of workloads.

2. Some of the reasons for choosing ECS over EC2 are described below:

a) Containerization: ECS is designed for running containers either on Fargate or EC2 instances, which provide a scalable way to package and deploy applications. Containers 
   offer better resource utilization, faster startup times, and improved isolation compared to traditional virtual machines used in EC2. If you’re using containerized 
   applications, ECS provides a managed environment optimized for running and orchestrating containers.

b) Scalability and Elasticity: ECS allows you to scale your applications based on demand easily. It integrates with AWS Auto Scaling, which can automatically adjust the 
   number of containers based on predefined scaling policies and placement constraints.

c) Orchestration: ECS provides built-in orchestration capabilities through integration with AWS Fargate or EC2 launch types. With Fargate, we don’t have to provision or 
   manage any EC2 instances, as AWS takes care of the infrastructure for you. This is also a great option and allows us to focus solely on our applications. EC2 launch type 
   offers more control and flexibility if we prefer managing the underlying EC2 instances ourselves.

d) Monitoring: ECS provides a centralized management console and CLI tools for deploying and managing containers. It also integrates with AWS CloudWatch, allowing us to 
   collect and analyze metrics, monitor logs, and set up alarms for our containerized applications. EC2 instances require separate management and monitoring configurations.

e) Cost Optimization: ECS can help optimize costs by allowing us to run containers on-demand without the need for permanent EC2 instances. With AWS Fargate, we pay only for 
   the resources allocated to our containers while they are running, which is more cost-effective compared to maintaining a fleet of EC2 instances. Read more about AWS cost 
   optimization.

f) It’s important to note that the choice between ECS and EC2 depends on our specific requirements, workload characteristics, and familiarity with containerization. While 
   ECS offers benefits for container-based applications, EC2 still provides more flexibility for running traditional workloads that don’t require containerization.

## ECS deployment with Terraform - Overview
1) The diagram below shows the outcome of ECS deployment using Terraform.

2) It shows how an ECS cluster is set up on EC2 instances spread across multiple availability zones within a VPC. It also includes several details like Application Load 
   Balancers (ALB), auto-scaling group (ASG), ECS Capacity provider, ECS service, etc.

** Note that there are other aspects not represented in the diagram, like ECR, Route tables, task definition, etc., which we will also cover.
   terraform aws ecs

3) We will break this infrastructure down into three parts. The list below provides an overview at a high level of all the steps we will be taking to achieve our goal of 
   hosting ECS clusters on EC2 instances. As we proceed, we will also write the corresponding Terraform configuration.

a) VPC setup – In this part, we will explain and implement the basic VPC and networking setup required. We will implement subnets, security groups, and route tables, to 
   access the hosted service from the internet as well as to SSH into our EC2 instances. 

b) EC2 setup – In this part, we will explain and implement auto-scaling groups, application load balancer, and EC2 instances, across the two availability zones. We will also 
   cover the setup in details required to host ECS container instances on our EC2 machines.

c) ECS setup – Finally, we do a step-by-step creation of the ECS cluster by creating ECS clusters, services, tasks, and capacity providers. We will also take a look at the 
   application image which will be used to run on this ECS cluster. Additionally, we will also show how to create task definitions along with various Terraform resource 
   attributes which enable the end-to-end deployment of the service.

** Note: The final Terraform configuration is saved in this Github repository.

## Before moving ahead, it is highly recommended to follow these steps hands-on.

![alt text](timemanagement-Architecture.jpeg)

## 1) Setting up the VPC:

a) To begin, let's establish our isolated network by defining the VPC and related components. This is crucial as we need to create multiple container instances of our 
   application for the load balancer to distribute requests evenly.

b) Create a file named `vpc.tf` in the project repository and add the following code. You can optionally include all the Terraform code in the same file (e.g., `main.tf`). 
   However, it's preferable to keep separate files to manage the IaC easily.

Step 1: Define our VPC.
The code below creates a VPC with a given CIDR range. You are free to choose the CIDR range. For this example, we'll use `10.0.0.0/16` and name our VPC as "main".

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

Step 2: Add 2 subnets:

Create two subnets in different availability zones to place our EC2 instances. We'll use the `Cid subnet` Terraform function to dynamically calculate the CIDR range based on the VPC’s CIDR. Note that we're using different availability zones in the Frankfurt region for both subnets.

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b"
}
Step 3: Create internet gateway (IGW):
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "internet_gateway"
  }
}

Step 4: Create a Route table and associate the same with subnets:

This route table enables internet communication for both subnets, making them public.

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "subnet_route" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "subnet2_route" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.route_table.id
}

Step 5: Create a security group along with ingress and egress rules:

Both ingress and egress rules of the security group allow inbound and outbound access for any protocol, via any port. This isn't the best practice and should only be done for working through this example. Tighter rules should be implemented in production.

resource "aws_security_group" "security_group" {
  name        = "ecs-security-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = false
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
This completes the VPC setup. You can now proceed with provisioning these resources or move on to the next section.

## 2. Configuring the EC2 instances:

a) In this section, we'll focus on provisioning the auto-scaling group, defining the EC2 instance template used to host the ECS containers, and provisioning the application load balancer in the VPC created in the previous section.

b) Create another file named ec2.tf, and follow the steps below:

Step 1: Create an EC2 launch template.
       i.A launch template, as the name suggests, defines the template used by the auto-scaling group to provision and maintain a desired/required number of EC2 instances in 
         a cluster.

       ii. Launch templates define various characteristics of the EC2 instance:

       iii.Image: We use the Amazon Linux image with CPU architecture as AMD.

       iv.Type: Size of the instance. We use “t3.medium”.
                The size of the instance is decided by the system resources consumed by the container. In our case, we are hosting a “Docker Getting Started” image, which 
                does not consume a lot of resources. More about the image will be covered later in the post.

       v.Key name: Specify the name of the key to be able to SSH into these instances from our local        machines. You can either create a key using a separate Terraform resource block. In this case, I am  just using a key that I have already generated.

       vi.Security group: The security group to be associated with the EC2 instance. Associate the same security group we created in the previous section.

       vii.IAM instance profile: This is very important. Without this, the EC2 instances will not be able to access the ECS service in AWS. “ecsInstanceRole” is a predefined 
                                 role available in all AWS accounts. However, if you want to use a custom role, make sure it can access the ECS service.

       viii.User data: This is also very important. The “ecs.sh” file contains a command to create an environment variable in “/etc/ecs/ecs.config” file on each EC2 instance 
                       that will be created. Without setting this, the ECS service will not be able to deploy and run containers on our EC2 instance.

                       resource "aws_launch_template" "ecs_lt" {
                         name_prefix   = "ecs-template"
                         image_id      = "ami-062c116e449466e7f"
                         instance_type = "t3.medium"

                         key_name               = "ec2ecsglog"
                         vpc_security_group_ids = [aws_security_group.security_group.id]
                         iam_instance_profile {
                         name                   = "ecsInstanceRole"
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
                        Name = "ecs-instance"
                          }
                          }

                        user_data = filebase64("${path.module}/ecs.sh")
                        }

    
## The contents of the ecs.sh file is:
bash
#!/bin/bash
echo ECS_CLUSTER=my-ecs-cluster >> /etc/ecs/ecs.config
## Step 2: Create an auto-scaling group (ASG)
a) Create an ASG and associate it with the launch template created in the last step.

b) ASG automatically manages the horizontal scaling of EC2 instances as per what is required by the ECS service but within the limits defined in this resource block.

resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
  desired_capacity    = 2
  max_size            = 3
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
** Note that apart from the desired capacity, max, and min count, we have also specified the “vpc_zone_identifier” attribute. This limits the ASG to provision instances in the same availability zones where the subnets are created.

** A region may have more than two availability zones. Since we are leveraging only two subnets, the vpc_zone_identifier should follow the appropriate AZs dynamically.

## Step 3: Configure Application Load Balancer (ALB)
a) An ALB is required to test our implementation in the end. In a way, it is optional as far as the discussion of this blog post is concerned, but there is no fun in doing 
  the hard work and not being able to witness it in the real world.

b) See How to Manage Application Load Balancer (ALB) with Terraform.

c) Create the ALB, its listener, and the target group as defined in the code samples below.

resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = [aws_subnet.subnet.id, aws_subnet.subnet2.id]

  tags = {
    Name = "ecs-alb"
  }
}

resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}
## This set of configurations creates the necessary components for setting up EC2 instances in an ECS cluster using Terraform.
resource "aws_lb_target_group" "ecs_tg" {
 name        = "ecs-target-group"
 port        = 80
 protocol    = "HTTP"
 target_type = "ip"
 vpc_id      = aws_vpc.main.id

 health_check {
   path = "/"
 }
}

** Note that we are still using the same VPC, subnets, and security group we created in the previous section. The rest of the ALB configuration is straightforward and basic.

d) Again, at this point, you can choose to create these resources using the terraform plan and apply commands. Or, move forward for the final section, we would create the 
   ECS cluster.

e) The Elastic Container Service (ECS) from Amazon Web Services (AWS) is a fully managed cloud Container Orchestration Service. It runs multiple Docker containers on the 
   cluster using AWS EC2 instances. Optionally it is also possible to run these containers on Fargate.

f) The more AWS ECS Clusters we deploy, the more complex the infrastructure management becomes. Especially when deploying and scaling a large cluster, the process becomes 
   time-consuming as it involves a lot of repetitive tasks that lead to human errors, creating configuration drifts and increasing the risk of security breaches.

g) Using Terraform is the perfect solution to simplify the deployment of the AWS ECS Cluster. Terraform offers an automated way to manage AWS ECS Clusters, making the 
  deployment process consistent and repeatable.

## 3. Configuring the ECS cluster:
a) With the networking and EC2 infrastructure defined or provisioned, we finally have arrived at provisioning an ECS cluster and hosting a web application on the same.

b) In this section, we will achieve the target architecture represented in the target deployment section as well as below.

   terraform aws ecs
## Step 1: Create and push the application image.
a) We would deploy the application “docker/getting-started”, which is usually shipped with every Docker desktop installation. Pull this image locally, and then push it to 
   any accessible image repository of your choice.

b) To keep this simple, I have created a public Elastic Container Repository (ECR), tagged the image appropriately, and pushed the same to this public ECR.

** Note that if you are using a Mac M1 processor (or any ARM-based processor) to build the image locally, then the CPU architecture differs from the Amazon Linux AMI (X86), 
   which we have used in the EC2 setup section. This impacts the way images are built and are not compatible. As a workaround, do a manual build and push by logging in to an 
   Amazon Linux AMI-based EC2 instance.

## Step 2: Provision ECS cluster:
** Optionally, create a new configuration file and add the code below. In my example, I have created a main.tf file to add the ECS-related configuration. We begin by 
   provisioning an ECS cluster using the “aws_ecs_cluster” resource.

resource "aws_ecs_cluster" "ecs_cluster" {
 name = "my-ecs-cluster"
}
** This is a simple resource block with just a name attribute. This does not do much, but this is where provisioning an ECS cluster begins.
## Step 3: Create capacity providers.
a) Next, we create a couple of resources to provision capacity providers for the ECS cluster created in the previous step.

b) The “aws_ecs_capacity_provider” resource associates the auto-scaling group with the cluster’s capacity provider. Whereas “aws_ecs_cluster_capacity_providers” binds the 
   ASG capacity provider with the ECS cluster created in Step 1.

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "test1"
 
 auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

   managed_scaling {
     maximum_scaling_step_size = 2
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 2
   }
 }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
 cluster_name = aws_ecs_cluster.ecs_cluster.name

 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

 default_capacity_provider_strategy {
   base              = 1
   weight            = 100
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
 }
}
## Step 4: Create ECS task definition with Terraform.
a) As described in the ECS overview section before, we now define the task definition/template of the container tasks to be run on the ECS cluster using the image we pushed in Step 1.

** Some of the important points to note here are:

1) We have defined the network mode to be “awsvpc”. This tells the ECS cluster to use the VPC networking we have defined in the “VPC setup” section.

2) We have provided the task definition with ecsTaskExecutionRole.

3) Defined CPU resource requirement as 256.

4) The runtime platform is an important attribute. Since we are using Amazon Linux AMI for our EC2 instances, the operating_system_family is specified as “LINUX,” and the 
   CPU architecture is set as “X86_64”. If this information is incorrect, the ECS tasks enter in the constant restart loop.

   Container definitions: This is where we define the resource requirements of the container to be run in the task. We have provided below attributes:
•	Name of the container instance
•	Image URL of the application image
•	CPU capacity units
•	Memory capacity units
•	Container and host port mappings

resource "aws_ecs_task_definition" "ecs_task_definition" {
 family             = "my-ecs-task"
 network_mode       = "awsvpc"
 execution_role_arn = "arn:aws:iam::532199187081:role/ecsTaskExecutionRole"
 cpu                = 256
 runtime_platform {
   operating_system_family = "LINUX"
   cpu_architecture        = "X86_64"
 }
 container_definitions = jsonencode([
   {
     name      = "dockergs"
     image     = "public.ecr.aws/f9n5f1l7/dgs:latest"
     cpu       = 256
     memory    = 512
     essential = true
     portMappings = [
{
         containerPort = 3000
         hostPort      = 3000
         protocol      = "tcp"
       }
     ]
   }
 ])
}

## Step 5: Create the ECS service:
** This is the last step, where we provision the service to be run on the ECS cluster. This is where all the resources created culminate to run the application service 
   successfully.

--> The attributes defined here are:
1) Name: name of the ECS service
2) Cluster: Reference to the ECS cluster record we created in Step 2.
3) Task definition: Reference to the task definition template created in Step 4.
4) Desired count: We have specified that we want to run two instances of this container image on our ECS cluster.
5) Network configuration: We have specified the subnets and security groups we created in the VPC setup section.
6) Placement constraints: We have specified that the container instances should run on distinct instances instead of using the residual capacity in each instance. This is 
   not a best practice, but just to prove the concept.
7) Capacity provider strategy: We have provided the reference to the capacity provider created in Step 3.
8) Load balancer: Reference to the load balancer we created in the EC2 setup section.

resource "aws_ecs_service" "ecs_service" {
 name            = "my-ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.ecs_task_definition.arn
 desired_count   = 2

 network_configuration {
   subnets         = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
   security_groups = [aws_security_group.security_group.id]
 }

 force_new_deployment = true
 placement_constraints {
   type = "distinctInstance"
 }

 triggers = {
   redeployment = timestamp()
 }

 capacity_provider_strategy {
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
   weight            = 100
 }

 load_balancer {
   target_group_arn = aws_lb_target_group.ecs_tg.arn
   container_name   = "dockergs"
   container_port   = 80
 }

 depends_on = [aws_autoscaling_group.ecs_asg]
}
## Run the terraform plan and apply commands to provision all the infrastructure defined so far.
