provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "vpc_core" {
  cidr_block = "10.50.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "az104-05-vpc-core" }
}

resource "aws_subnet" "core" {
  vpc_id = aws_vpc.vpc_core.id
  cidr_block = "10.50.0.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "Core" }
}

resource "aws_subnet" "perimeter" {
  vpc_id = aws_vpc.vpc_core.id
  cidr_block = "10.50.1.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "perimeter" }
}

resource "aws_vpc" "vpc_manufacturing" {
  cidr_block = "10.60.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "az104-05-vpc-manufacturing" }
}

resource "aws_subnet" "manufacturing" {
  vpc_id = aws_vpc.vpc_manufacturing.id
  cidr_block = "10.60.0.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "Manufacturing" }
}

resource "aws_vpc_peering_connection" "core_to_mfg" {
  vpc_id = aws_vpc.vpc_core.id
  peer_vpc_id = aws_vpc.vpc_manufacturing.id
  auto_accept = true
  tags = { Name = "az104-05-peering" }
}

resource "aws_route_table" "core_services" {
  vpc_id = aws_vpc.vpc_core.id

  route {
    cidr_block = aws_vpc.vpc_manufacturing.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.core_to_mfg.id
  }

  tags = { Name = "rt-CoreServices" }
}

resource "aws_route_table_association" "core" {
  subnet_id = aws_subnet.core.id
  route_table_id = aws_route_table.core_services.id
}
