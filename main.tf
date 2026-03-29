terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

provider "aws" {
  alias = "secondary"
  region = "eu-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "az104-vpc-region1" }
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "az104-subnet-region1" }
}

resource "aws_security_group" "vm" {
  vpc_id = aws_vpc.main.id
  name = "az104-vm-sg"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "vm0" {
  ami = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.vm.id]

  tags = { Name = "az104-10-vm0" }
}

resource "aws_backup_vault" "region1" {
  name = "az104-rsv-region1"
  tags = { Region = "eu-north-1" }
}

resource "aws_backup_plan" "daily_with_copy" {
  name = "az104-backup-with-replication"

  rule {
    rule_name = "daily-midnight-with-copy"
    target_vault_name = aws_backup_vault.region1.name
    schedule = "cron(0 0 * * ? *)"

    lifecycle {
      delete_after = 35
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.region2.arn

      lifecycle {
        delete_after = 35
      }
    }
  }
}

resource "aws_iam_role" "backup" {
  name = "az104-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action  = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "vm0" {
  name = "az104-10-vm0-selection"
  plan_id = aws_backup_plan.daily_with_copy.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [aws_instance.vm0.arn]
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "backup_logs" {
  bucket = "az104-backup-logs-${random_id.suffix.hex}"
  tags = { Name = "az104-backup-logs" }
}

resource "aws_cloudwatch_log_group" "backup" {
  name = "/aws/backup/az104"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "backup_jobs" {
  name = "az104-backup-job-events"
  description = "Capture AWS Backup job state changes"

  event_pattern = jsonencode({
    source = ["aws.backup"]
    detail-type = ["Backup Job State Change"]
  })
}

resource "aws_cloudwatch_event_target" "backup_logs" {
  rule = aws_cloudwatch_event_rule.backup_jobs.name
  target_id = "BackupLogsTarget"
  arn = aws_cloudwatch_log_group.backup.arn
}

resource "aws_backup_vault" "region2" {
  provider = aws.secondary
  name = "az104-rsv-region2"
  tags = { Region = "eu-west-1" }
}
