provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ECS Cluster
resource "aws_ecs_cluster" "php_app_cluster" {
  name = "php-app-cluster"
}

# Capacity Provider
resource "aws_ecs_cluster_capacity_providers" "php_app_cluster_provider" {
  cluster_name      = aws_ecs_cluster.php_app_cluster.name
  capacity_providers = ["FARGATE"]
}

# ECS Task Definition (Production)
resource "aws_ecs_task_definition" "php_app_task_prod" {
  family                   = "php-app-prod-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name      = "php-app-prod-container"
    image     = "nginx:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# ECS Task Definition (Staging)
resource "aws_ecs_task_definition" "php_app_task_staging" {
  family                   = "php-app-staging-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name      = "php-app-staging-container"
    image     = "nginx:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}