provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_ebs_volume" "disk1" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk1"
  }
}

resource "aws_ebs_volume" "disk2" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk2"
  }
}
