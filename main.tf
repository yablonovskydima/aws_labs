provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "main" {
  bucket = "az104-rg7-storage-${random_id.suffix.hex}"
  tags = { Name = "az104-rg7-storage" }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id = "Movetocool"
    status = "Enabled"

    transition {
      days= 30
      storage_class = "STANDARD_IA" # аналог Cool storage
    }

    filter {}
  }
}

resource "aws_s3_object" "sample" {
  bucket = aws_s3_bucket.main.id
  key = "securitytest/sample.txt"
  content = "Hello from az104 lab"
}

resource "aws_efs_file_system" "share1" {
  tags = { Name = "share1" }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vnet1" }
}

resource "aws_subnet" "default" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "default" }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.eu-north-1.s3"

  route_table_ids = [aws_vpc.main.default_route_table_id]

  tags = { Name = "s3-endpoint" }
}