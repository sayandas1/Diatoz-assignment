# Provider configuration
provider "aws" {
  region = "us-west-2"
}

# Variables
variable "github_owner" {}
variable "github_repo" {}
variable "github_branch" {}
variable "github_token" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
}

# Security Group for frontend
resource "aws_security_group" "frontend" {
  vpc_id = aws_vpc.main.id

  // Inbound rule for web traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Outbound rule for all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for backend
resource "aws_security_group" "backend" {
  vpc_id = aws_vpc.main.id

  // Inbound rule for database traffic (e.g., MongoDB)
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  // Outbound rule for all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CodePipeline
resource "aws_codepipeline" "main" {
  name     = "my-codepipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        Owner          = var.github_owner
        Repo           = var.github_repo
        Branch         = var.github_branch
        OAuthToken     = var.github_token
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ClusterName       = aws_ecs_cluster.main.name
        ServiceName       = aws_ecs_service.main.name
        FileName          = "imagedefinitions.json"
        TaskDefinition    = aws_ecs_task_definition.main.arn
        ContainerName     = "my-container"
        Image1            = "${aws_ecr_repository.main.repository_url}:latest"
        PollInterval      = "10"
      }
    }
  }
}

# ECS
resource "aws_ecs_cluster" "main" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "my-task-family"
  container_definitions    = jsonencode([{
    name      = "my-container"
    image     = "${aws_ecr_repository.main.repository_url}:latest"
    cpu       = 256
    memory    = 512
    portMappings {
      containerPort = 80
    }
  }])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
}

resource "aws_ecs_service" "main" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = true
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "ecs-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "60"
  alarm_actions       = [aws_sns_topic.notification.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "ecs-memory-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "60"
  alarm_actions       = [aws_sns_topic.notification.arn]
}

# CodeBuild Project
resource "aws_codebuild_project" "build" {
  name       = "my-codebuild-project"
  description = "My CodeBuild Project"
  build_timeout = "60"
  service_role = aws_iam_role.codebuild_role.arn
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "REPOSITORY_URI"
      value = "YOUR_AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/spring-demo-ecr"
    }
  }
  artifacts {
    type = "NO_ARTIFACTS"
  }
  source {
    type            = "GITHUB"
    location        = "https://github.com/your/repo"
    git_clone_depth = 1
    buildspec       = "buildspec.yaml"
  }
}
