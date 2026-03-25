provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "core_services" {
  cidr_block = "10.20.0.0/16"
  tags = { Name = "CoreServicesVnet" }
}

resource "aws_subnet" "shared_services" {
  vpc_id            = aws_vpc.core_services.id
  cidr_block        = "10.20.10.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "SharedServicesSubnet" }
}

resource "aws_subnet" "database" {
  vpc_id            = aws_vpc.core_services.id
  cidr_block        = "10.20.20.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "DatabaseSubnet" }
}

resource "aws_vpc" "manufacturing" {
  cidr_block = "10.30.0.0/16"
  tags = { Name = "ManufacturingVnet" }
}

resource "aws_subnet" "sensor1" {
  vpc_id            = aws_vpc.manufacturing.id
  cidr_block        = "10.30.20.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "SensorSubnet1" }
}

resource "aws_subnet" "sensor2" {
  vpc_id            = aws_vpc.manufacturing.id
  cidr_block        = "10.30.21.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "SensorSubnet2" }
}

resource "aws_security_group" "nsg_secure" {
  name   = "myNSGSecure"
  vpc_id = aws_vpc.core_services.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "AllowASG HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "AllowASG HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
    description = "DenyInternetOutbound"
  }

  tags = { Name = "myNSGSecure" }
}

resource "aws_route53_zone" "public" {
  name = "contoso.com"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "www.contoso.com"
  type    = "A"
  ttl     = 1
  records = ["10.1.1.4"]
}

resource "aws_route53_zone" "private" {
  name = "private.contoso.com"

  vpc {
    vpc_id = aws_vpc.manufacturing.id
  }
}

resource "aws_route53_record" "sensorvm" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "sensorvm.private.contoso.com"
  type    = "A"
  ttl     = 1
  records = ["10.1.1.4"]
}
