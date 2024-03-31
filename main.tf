provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"
  
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
}

module "security_group_frontend" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"
  
  name        = "security-group-frontend"
  description = "Security group for frontend services"
  vpc_id      = module.vpc.vpc_id
  
  ingress = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "security_group_backend" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"
  
  name        = "security-group-backend"
  description = "Security group for backend services"
  vpc_id      = module.vpc.vpc_id
  
  ingress = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"] // Allow access from frontend subnet
    }
  ]
  
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_ecr_repository" "my_repository" {
  name = "my-repository"
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

resource "aws_codepipeline" "my_pipeline" {
  name     = "my-pipeline"
  role_arn = aws_iam_role.my_role.arn

  artifact_store {
    location = aws_s3_bucket.my_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.github_repo_owner
        Repo       = var.github_repo_name
        Branch     = var.github_branch
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = "my-codebuild-project"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      version          = "1"
      input_artifacts  = ["build_output"]
      output_artifacts = []

      configuration = {
        ClusterName        = aws_ecs_cluster.my_cluster.name
        ServiceName        = "my-service"
        FileName           = "imagedefinitions.json"
        TaskDefinition     = aws_ecs_task_definition.my_task_definition.arn
        LaunchType         = "FARGATE"
        NetworkConfiguration = {
          Subnets          = module.vpc.public_subnets
          SecurityGroups   = [module.security_group_frontend.id, module.security_group_backend.id]
          AssignPublicIp   = true
        }
      }
    }
  }
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task-family"
  container_definitions    = jsonencode([
    {
      name      = "my-container"
      image     = aws_ecr_repository.my_repository.repository_url
      cpu       = 256
      memory    = 512
      essential = true
    }
  ])

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_alarm" {
  alarm_name          = "ecs-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 60
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_alarm" {
  alarm_name          = "ecs-memory-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 60
}
