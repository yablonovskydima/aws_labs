terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ==========================================================================
# TASK 1 — VPC + EC2 + CloudWatch Agent (аналог VM Insights)
# ==========================================================================

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "az104-vpc-rg11" }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
}

resource "aws_security_group" "vm" {
  vpc_id = aws_vpc.main.id
  name   = "az104-vm-sg"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# IAM роль для EC2 — дозволяє CloudWatch Agent надсилати метрики і логи
resource "aws_iam_role" "ec2" {
  name = "az104-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "az104-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "vm0" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.vm.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # Встановлює CloudWatch Agent при запуску (аналог VM Insights агента)
  user_data = <<-EOT
    #!/bin/bash
    yum install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s -c default
  EOT

  tags = { Name = "az104-11-vm0" }
}

# ==========================================================================
# TASK 2 + 3 — SNS Topic (action group) + CloudWatch Alarm на видалення VM
# ==========================================================================

# SNS Topic — аналог Action Group
resource "aws_sns_topic" "alerts" {
  name = "az104-alert-ops-team"
}

# Email підписка — аналог Email notification в Action Group
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudTrail потрібен щоб EventBridge отримував API події (зокрема TerminateInstances)
resource "aws_cloudtrail" "main" {
  name                          = "az104-trail"
  s3_bucket_name                = aws_s3_bucket.trail.bucket
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = false
}

resource "aws_s3_bucket" "trail" {
  bucket        = "az104-cloudtrail-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# EventBridge rule — спрацьовує коли EC2 інстанс видаляється
resource "aws_cloudwatch_event_rule" "vm_deleted" {
  name        = "az104-vm-deleted"
  description = "VM was deleted"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated"]
    }
  })
}

resource "aws_cloudwatch_event_target" "vm_deleted_sns" {
  rule      = aws_cloudwatch_event_rule.vm_deleted.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

# Дозвіл EventBridge публікувати в SNS
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alerts.arn
    }]
  })
}

# ==========================================================================
# TASK 5 — EventBridge rule для придушення нотифікацій під час обслуговування
# Вимикає основний rule на нічний період (аналог Alert Processing Rule)
# ==========================================================================

resource "aws_scheduler_schedule" "suppress_start" {
  name = "az104-maintenance-suppress-start"

  flexible_time_window { mode = "OFF" }

  # Щодня о 22:00 — вимикає алерт rule
  schedule_expression          = "cron(0 22 * * ? *)"
  schedule_expression_timezone = "Europe/Kiev"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eventbridge:disableRule"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      Name = aws_cloudwatch_event_rule.vm_deleted.name
    })
  }
}

resource "aws_scheduler_schedule" "suppress_end" {
  name = "az104-maintenance-suppress-end"

  flexible_time_window { mode = "OFF" }

  # Щодня о 07:00 — вмикає алерт rule назад
  schedule_expression          = "cron(0 7 * * ? *)"
  schedule_expression_timezone = "Europe/Kiev"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eventbridge:enableRule"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      Name = aws_cloudwatch_event_rule.vm_deleted.name
    })
  }
}

resource "aws_iam_role" "scheduler" {
  name = "az104-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler" {
  role = aws_iam_role.scheduler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["events:DisableRule", "events:EnableRule"]
      Resource = aws_cloudwatch_event_rule.vm_deleted.arn
    }]
  })
}

# ==========================================================================
# TASK 6 — CloudWatch Log Group для VM логів (запити робляться вручну в консолі)
# ==========================================================================

resource "aws_cloudwatch_log_group" "vm" {
  name              = "/aws/ec2/az104-11-vm0"
  retention_in_days = 30
}
